// res://App.cs
using Godot;
using System;
using System.Collections.Generic;
using ControllerApp.Model;

public partial class App : Node2D
{
	// ----------------------------
	// Mode
	// ----------------------------
	public enum AppMode
	{
		Json = 0,
		Synth = 1,
	}

	[ExportGroup("Config (JSON mode)")]
	[Export] public string ParametersPath { get; set; } = "res://data/parameters.json";
	[Export] public string GroupsPath { get; set; } = "res://data/groups_micron.json";

	[ExportGroup("Mode")]
	[Export] public AppMode Mode { get; private set; } = AppMode.Json;

	[ExportGroup("Synth mode")]
	// Set this in the inspector to the SynthGraphEditor node inside your modular_synth_setup.tscn instance.
	// Use "Copy Node Path" in the editor to avoid mistakes.
	[Export] public NodePath SynthGraphEditorPath { get; set; } = default;

	// How many "nudge steps" per detent. (The addon uses the JSON spec's step size internally.)
	// Unpressed = coarse, pressed = fine
	[Export] public int SynthCoarseStepMul { get; set; } = 5;
	[Export] public int SynthFineStepMul { get; set; } = 1;

	// ----------------------------
	// UI + JSON data
	// ----------------------------
	private ItemList _groupList = default!;
	private readonly List<Node> _paramViews = new(); // 16 ParameterView instances
	private readonly ConfigDatabase _db = new();

	// controller -> param_id (JSON mode; sparse)
	private readonly Dictionary<int, string> _controllerToParamId = new();

	// Serial node (GDScript) emitting controller_event/nav_event and providing send_controller_colors_enum
	private Node _serialNode = default!;

	// ----------------------------
	// Synth mode state
	// ----------------------------
	private Node? _synthGraph;                 // SynthGraphEditor (GDScript GraphEdit controller)
	private readonly List<int> _synthBlockIds = new();   // group list index -> block_id
	private int _selectedSynthBlockId = -1;

	// controller index 0..15 -> synth param_id
	private readonly int[] _ctrlToSynthParamId = new int[16];
	private readonly string[] _ctrlToSynthParamLabel = new string[16];

	private static readonly ControllerColor[] SynthControllerColors =
	{
		ControllerColor.BrightRed,
		ControllerColor.BrightGreen,
		ControllerColor.Yellow,
		ControllerColor.BrightBlue,
		ControllerColor.Orange,
		ControllerColor.Cyan,
		ControllerColor.Pink,
		ControllerColor.Lavender,
		ControllerColor.DarkRed,
		ControllerColor.DarkGreen,
		ControllerColor.DarkYellow,
		ControllerColor.NavyBlue,
		ControllerColor.DarkCyan,
		ControllerColor.Rose,
		ControllerColor.Violet,
		ControllerColor.White,
	};

	private readonly string[] _ctrlSynthKind = new string[16]; // "float","int","bool","enum"
	private readonly Godot.Collections.Array[] _ctrlSynthEnumLabels = new Godot.Collections.Array[16];
	private readonly double[] _ctrlSynthMin = new double[16];
	private readonly double[] _ctrlSynthMax = new double[16];
	private readonly double[] _ctrlSynthStep = new double[16];

	// ----------------------------
	// Godot lifecycle
	// ----------------------------
	public override void _Ready()
	{
		// --- UI nodes live under the Control child ---
		_groupList = GetNode<ItemList>("Control/VSplitContainer/HSplitContainer/VSplitContainer2/ItemList");

		var grid = GetNode<GridContainer>("Control/VSplitContainer/ParameterGrid8x2");
		_paramViews.Clear();
		for (int i = 1; i <= 16; i++)
			_paramViews.Add(grid.GetNode<Node>($"ParameterView{i}"));

		// --- Load configs (so JSON mode is always available) ---
		_db.LoadAll(ParametersPath, GroupsPath);

		// --- Hook group list selection ---
		_groupList.ItemSelected += OnGroupSelected;

		// --- Serial hookup ---
		_serialNode = GetNode<Node>("%Serial");
		GD.Print(_serialNode);
		_serialNode.Connect("controller_event", new Callable(this, nameof(OnControllerEvent)));
		_serialNode.Connect("nav_event", new Callable(this, nameof(OnNavEvent)));

		// Init arrays
		for (int i = 0; i < 16; i++)
		{
			_ctrlToSynthParamId[i] = -1;
			_ctrlToSynthParamLabel[i] = "";
		}

		for (int i = 0; i < 16; i++)
		{
			_ctrlSynthKind[i] = "";
			_ctrlSynthEnumLabels[i] = null;
			_ctrlSynthMin[i] = 0;
			_ctrlSynthMax[i] = 0;
			_ctrlSynthStep[i] = 0;
		}

		// Enter initial mode
		if (Mode == AppMode.Synth)
			EnterSynthMode();
		else
			EnterJsonMode();

		GD.Print($"Loaded params={_db.ParametersById.Count}, json groups={_db.Groups.Count}, mode={Mode}");
	}

	// ----------------------------
	// Public API: hook your UI button(s) to these
	// ----------------------------
	public void SetMode(int mode)
	{
		SetMode((AppMode)mode);
	}

	public void SetMode(AppMode newMode)
	{
		if (Mode == newMode) return;
		Mode = newMode;

		if (Mode == AppMode.Synth)
			EnterSynthMode();
		else
			EnterJsonMode();
	}

	// ----------------------------
	// JSON MODE
	// ----------------------------
	private void EnterJsonMode()
	{
		_selectedSynthBlockId = -1;
		_synthBlockIds.Clear();

		_groupList.Clear();
		for (int i = 0; i < _db.Groups.Count; i++)
			_groupList.AddItem(_db.Groups[i].Name);

		if (_db.Groups.Count == 0)
		{
			ClearTiles();
			return;
		}

		var active = Mathf.Clamp(_db.ActiveGroupIndex, 0, Math.Max(0, _db.Groups.Count - 1));
		_db.ActiveGroupIndex = active;

		_groupList.Select(active);
		_groupList.EnsureCurrentIsVisible();
		ApplyJsonGroupToTiles(active);
		SendActiveGroupColors(); // JSON mode uses group controller colors
	}

	private void ApplyJsonGroupToTiles(int groupIndex)
	{
		if (groupIndex < 0 || groupIndex >= _db.Groups.Count)
			return;

		var grp = _db.Groups[groupIndex];

		// controller -> paramId map (sparse)
		_controllerToParamId.Clear();
		foreach (var kv in grp.ControllerForParam)
		{
			int c = kv.Value;
			if (c >= 0 && c < 16)
				_controllerToParamId[c] = kv.Key;
		}

		for (int c = 0; c < 16; c++)
		{
			ParameterBase? p = null;

			if (_controllerToParamId.TryGetValue(c, out var pid))
				_db.ParametersById.TryGetValue(pid, out p);

			var color = grp.ControllerColors[c];
			SetParameterTileJson(c, p, color);
		}
	}

	private void SetParameterTileJson(int controllerIndex, ParameterBase? p, ControllerColor color)
	{
		var pv = _paramViews[controllerIndex];

		var valueLabel = pv.GetNode<Label>("Panel/VSplitContainer/Value");
		var nameLabel = pv.GetNode<Label>("Panel/VSplitContainer/Name");
		var panel = pv.GetNode<Panel>("Panel");

		valueLabel.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
		nameLabel.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
		valueLabel.HorizontalAlignment = HorizontalAlignment.Center;
		nameLabel.HorizontalAlignment = HorizontalAlignment.Center;

		if (p == null)
		{
			valueLabel.Text = "";
			nameLabel.Text = "";
			ApplyPanelOutline(panel, Colors.Black);
			return;
		}

		valueLabel.Text = p.FormatValue();
		nameLabel.Text = p.DisplayName;

		var col = ToGodotColor(color);
		ApplyPanelOutline(panel, col);
	}

	private void SendActiveGroupColors()
	{
		// Only meaningful in JSON mode with controller_colors
		if (_db.Groups.Count == 0) return;
		if (_serialNode == null) return;
		if (!_serialNode.HasMethod("send_controller_colors_enum")) return;

		var grp = _db.Groups[_db.ActiveGroupIndex];

		var arr = new Godot.Collections.Array();
		for (int i = 0; i < 16; i++)
			arr.Add((int)grp.ControllerColors[i]); // enum -> int

		_serialNode.Call("send_controller_colors_enum", arr);
	}

	// ----------------------------
	// SYNTH MODE
	// ----------------------------
	private void EnterSynthMode()
	{
		_groupList.Clear();
		_synthBlockIds.Clear();
		_selectedSynthBlockId = -1;

		if (SynthGraphEditorPath.IsEmpty)
		{
			GD.PushError("SynthGraphEditorPath is empty. Set it to the SynthGraphEditor node in your modular_synth_setup instance.");
			ClearTiles();
			return;
		}

		_synthGraph = GetNodeOrNull<Node>(SynthGraphEditorPath);
		if (_synthGraph == null)
		{
			GD.PushError($"SynthGraphEditor node not found at: {SynthGraphEditorPath}");
			ClearTiles();
			return;
		}

		GD.Print("GraphEditor node: ", _synthGraph);
		GD.Print("Has list_blocks: ", _synthGraph.HasMethod("list_blocks"));
		GD.Print("Has list_params: ", _synthGraph.HasMethod("list_params"));
		GD.Print("Has nudge_param: ", _synthGraph.HasMethod("nudge_param"));
		GD.Print("Has blocks_changed signal: ", _synthGraph.HasSignal("blocks_changed"));

		// Connect blocks_changed signal once
		var cb = new Callable(this, nameof(OnSynthBlocksChanged));
		if (!_synthGraph.IsConnected("blocks_changed", cb))
			_synthGraph.Connect("blocks_changed", cb);

		RebuildSynthBlockList();

		if (_synthBlockIds.Count > 0)
			SelectSynthBlockByIndex(0);
		else
			ClearTiles();
	}

	// blocks_changed(action: String, block_id: int, block_type: int)
	private void OnSynthBlocksChanged(string action, int blockId, int blockType)
	{
		RebuildSynthBlockList();

		// If the selected block disappeared, select a new one or clear
		if (_selectedSynthBlockId != -1 && !_synthBlockIds.Contains(_selectedSynthBlockId))
		{
			_selectedSynthBlockId = -1;
			if (_synthBlockIds.Count > 0)
				SelectSynthBlockByIndex(0);
			else
				ClearTiles();
		}
	}

	private void RebuildSynthBlockList()
	{
		if (_synthGraph == null) return;

		_synthBlockIds.Clear();
		_groupList.Clear();

		// list_blocks() -> Array[Dictionary]
		var arr = (Godot.Collections.Array)_synthGraph.Call("list_blocks");
		foreach (var v in arr)
		{
			var d = (Godot.Collections.Dictionary)v;
			int id = (int)d["block_id"];
			string title = d.ContainsKey("title") ? d["title"].AsString() : $"Block {id}";

			_synthBlockIds.Add(id);
			_groupList.AddItem(title);
		}

		// Keep selection if possible
		if (_selectedSynthBlockId != -1)
		{
			int idx = _synthBlockIds.IndexOf(_selectedSynthBlockId);
			if (idx >= 0)
			{
				_groupList.Select(idx);
				_groupList.EnsureCurrentIsVisible();
			}
		}
	}

	private void SelectSynthBlockByIndex(int index)
	{
		if (_synthGraph == null) return;
		if (index < 0 || index >= _synthBlockIds.Count) return;

		int blockId = _synthBlockIds[index];
		_selectedSynthBlockId = blockId;

		_groupList.Select(index);
		_groupList.EnsureCurrentIsVisible();

		// Tell the editor selection (optional, but nice)
		_synthGraph.Call("set_selected_block", blockId);

		BuildSynthControllerMapping(blockId);
		RefreshSynthTiles(blockId);
	}

	private void BuildSynthControllerMapping(int blockId)
	{
		for (int i = 0; i < 16; i++)
		{
			_ctrlToSynthParamId[i] = -1;
			_ctrlToSynthParamLabel[i] = "";
		}

		// list_params(block_id) -> Array[Dictionary]
		var parr = (Godot.Collections.Array)_synthGraph!.Call("list_params", blockId);

		int c = 0;
		foreach (var v in parr)
		{
			if (c >= 16) break;

			var d = (Godot.Collections.Dictionary)v;
			int paramId = (int)d["param_id"];
			string label = d.ContainsKey("label") ? d["label"].AsString() : d["key"].AsString();

			string kind = d.ContainsKey("kind") ? d["kind"].AsString() : "";
			_ctrlSynthKind[c] = kind;

			_ctrlSynthMin[c] = d.ContainsKey("min") ? (double)d["min"] : 0.0;
			_ctrlSynthMax[c] = d.ContainsKey("max") ? (double)d["max"] : 0.0;
			_ctrlSynthStep[c] = d.ContainsKey("step") ? (double)d["step"] : 0.0;

			// Enum labels
			_ctrlSynthEnumLabels[c] = null;
			if (kind == "enum")
			{
				// Your JSON uses "values": ["SIN","COS",...]
				if (d.ContainsKey("values") && d["values"].VariantType == Variant.Type.Array)
					_ctrlSynthEnumLabels[c] = (Godot.Collections.Array)d["values"];
				else if (d.ContainsKey("labels") && d["labels"].VariantType == Variant.Type.Array)
					_ctrlSynthEnumLabels[c] = (Godot.Collections.Array)d["labels"];
				else if (d.ContainsKey("options") && d["options"].VariantType == Variant.Type.Array)
					_ctrlSynthEnumLabels[c] = (Godot.Collections.Array)d["options"];
			}

			_ctrlToSynthParamId[c] = paramId;
			_ctrlToSynthParamLabel[c] = label;

			c++;
		}
	}

	private Node? FindSynthBlockNode(int blockId)
	{
		// blocks are added to group: "modular_synth_block_id_<id>"
		var nodes = GetTree().GetNodesInGroup($"modular_synth_block_id_{blockId}");
		return nodes.Count > 0 ? (Node)nodes[0] : null;
	}

	private void RefreshSynthTiles(int blockId)
	{
		var blockNode = FindSynthBlockNode(blockId);

		for (int c = 0; c < 16; c++)
		{
			var pv = _paramViews[c];
			var valueLabel = pv.GetNode<Label>("Panel/VSplitContainer/Value");
			var nameLabel = pv.GetNode<Label>("Panel/VSplitContainer/Name");
			var panel = pv.GetNode<Panel>("Panel");

			valueLabel.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
			nameLabel.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
			valueLabel.HorizontalAlignment = HorizontalAlignment.Center;
			nameLabel.HorizontalAlignment = HorizontalAlignment.Center;

			int paramId = _ctrlToSynthParamId[c];
			if (paramId < 0)
			{
				valueLabel.Text = "";
				nameLabel.Text = "";
				ApplyPanelOutline(panel, Colors.Black);
				continue;
			}

			string label = _ctrlToSynthParamLabel[c];
			string valText = "";

			if (blockNode != null)
			{
				// generic_block.gd: get_param_value(param_id)
				var v = blockNode.Call("get_param_value", paramId);

				// If enum, try to map int index -> label
				if (_ctrlSynthKind[c] == "enum" && _ctrlSynthEnumLabels[c] != null)
				{
					// get_param_value is coming back as 1.0 etc — convert safely to int index
					int idx = VariantToEnumIndex(v);

					var labels = _ctrlSynthEnumLabels[c];
					if (idx >= 0 && idx < labels.Count)
						valText = labels[idx].ToString();
					else
						valText = idx.ToString();
				}
				else
				{
					valText = v.ToString();
				}
			}

			nameLabel.Text = label;
			valueLabel.Text = valText;

			// In synth mode, we don't have controller_colors; just use a neutral outline
			var outline = ToGodotColor(SynthControllerColors[c]);
			ApplyPanelOutline(panel, outline);
		}
	}

	private static int VariantToEnumIndex(Variant v)
	{
		// Handles int, float, string "1", etc.
		switch (v.VariantType)
		{
			case Variant.Type.Int:
				return (int)v;

			case Variant.Type.Float:
				return (int)Math.Round((double)v);

			case Variant.Type.String:
				{
					var s = v.AsString();
					if (int.TryParse(s, out var i)) return i;
					if (double.TryParse(s, out var f)) return (int)Math.Round(f);
					return 0;
				}

			default:
				// fallback: try ToString
				{
					var s = v.ToString();
					if (int.TryParse(s, out var i)) return i;
					if (double.TryParse(s, out var f)) return (int)Math.Round(f);
					return 0;
				}
		}
	}

	// ----------------------------
	// Group selection (shared)
	// ----------------------------
	private void OnGroupSelected(long index)
	{
		int i = (int)index;

		if (Mode == AppMode.Synth)
		{
			SelectSynthBlockByIndex(i);
			return;
		}

		_db.ActiveGroupIndex = i;
		ApplyJsonGroupToTiles(i);
		SendActiveGroupColors();
	}

	// ----------------------------
	// Serial events (shared)
	// ----------------------------
	private void OnControllerEvent(int controller, int delta, bool pushed)
	{
		// Dial controller 17 navigates groups/blocks
		if (controller == 17)
		{
			if (delta != 0) SelectRelative(delta);
			return;
		}

		if (controller < 0 || controller >= 16) return;
		if (delta == 0) return;

		if (Mode == AppMode.Synth)
		{
			if (_synthGraph == null) return;
			if (_selectedSynthBlockId < 0) return;

			int paramId = _ctrlToSynthParamId[controller];
			if (paramId < 0) return;

			// Compute how many "nudge steps" to apply based on kind/min/max/step and pushed state.
			// Requirements:
			// 1) enum: display string (handled elsewhere) and delta always 1 step
			// 2) float: coarse 1% of range, fine 0.1% of range
			// 3) int: coarse 1% (or 1) of range, fine 1
			int steps = ComputeSynthNudgeSteps(controller, delta, pushed);
			if (steps == 0) return;

			// SynthGraphEditor: nudge_param(block_id, param_id, steps)
			_synthGraph.Call("nudge_param", _selectedSynthBlockId, paramId, steps);

			// update display
			RefreshSynthTiles(_selectedSynthBlockId);
			return;
		}

		// JSON mode: map controller -> parameter
		if (!_controllerToParamId.TryGetValue(controller, out var pid)) return;
		if (!_db.ParametersById.TryGetValue(pid, out var p)) return;

		ApplyDeltaToParameter(p, delta, pushed);

		var grp = _db.Groups[_db.ActiveGroupIndex];
		SetParameterTileJson(controller, p, grp.ControllerColors[controller]);
	}

	private int ComputeSynthNudgeSteps(int controllerIndex, int delta, bool pushed)
	{
		if (delta == 0) return 0;

		string kind = _ctrlSynthKind[controllerIndex];
		double min = _ctrlSynthMin[controllerIndex];
		double max = _ctrlSynthMax[controllerIndex];
		double step = _ctrlSynthStep[controllerIndex];

		// fallback if step missing
		if (step <= 0.0) step = 1.0;

		// enum: always 1 step per detent
		if (kind == "enum")
			return Math.Sign(delta);

		// bool: treat as toggle-ish; nudge by sign only
		if (kind == "bool")
			return Math.Sign(delta);

		double span = Math.Abs(max - min);
		if (span <= 0.0) span = 1.0;

		double frac;
		if (kind == "float")
			frac = pushed ? 0.001 : 0.01;    // 0.1% fine, 1% coarse
		else
			frac = pushed ? 0.0 : 0.01;      // ints handled below; keep placeholder

		if (kind == "float")
		{
			double targetDeltaValue = span * frac;
			int nudge = (int)Math.Round(targetDeltaValue / step);
			nudge = Math.Max(1, nudge);
			return nudge * delta;
		}

		// 3) Int parameters: coarse 1% (or 1), fine 1
		if (kind == "int")
		{
			int coarse = Math.Max(1, (int)Math.Round(span * 0.01));
			// Convert "value units" into nudge steps
			int coarseSteps = Math.Max(1, (int)Math.Round(coarse / step));
			int fineSteps = 1; // exactly 1 step
			return (pushed ? fineSteps : coarseSteps) * delta;
		}

		// fallback
		return Math.Sign(delta);
	}

	private void OnNavEvent(string action, bool pressed)
	{
		if (!pressed) return;

		action = action.Trim();
		if (action.Equals("Up", StringComparison.OrdinalIgnoreCase))
			SelectRelative(-1);
		else if (action.Equals("Down", StringComparison.OrdinalIgnoreCase))
			SelectRelative(+1);
	}

	private void SelectRelative(int delta)
	{
		if (Mode == AppMode.Synth)
		{
			if (_synthBlockIds.Count == 0) return;

			int curIndex = _selectedSynthBlockId == -1 ? 0 : _synthBlockIds.IndexOf(_selectedSynthBlockId);
			if (curIndex < 0) curIndex = 0;

			int next = curIndex + (delta > 0 ? 1 : -1);
			next = Mathf.Clamp(next, 0, _synthBlockIds.Count - 1);

			if (next == curIndex) return;

			SelectSynthBlockByIndex(next);
			return;
		}

		// JSON
		if (_db.Groups.Count == 0) return;

		int cur = _db.ActiveGroupIndex;
		int nextJson = cur + (delta > 0 ? 1 : -1);
		nextJson = Mathf.Clamp(nextJson, 0, _db.Groups.Count - 1);

		if (nextJson == cur) return;

		_db.ActiveGroupIndex = nextJson;
		_groupList.Select(nextJson);
		_groupList.EnsureCurrentIsVisible();
		ApplyJsonGroupToTiles(nextJson);
		SendActiveGroupColors();
	}

	// ----------------------------
	// Parameter stepping (JSON mode)
	// ----------------------------
	private static bool IsRawIndexConv(string conv)
	{
		if (string.IsNullOrWhiteSpace(conv)) return false;
		conv = conv.Trim().ToLowerInvariant();
		return conv is "filter_freq"
			or "lfo_freq"
			or "env_time"
			or "release_time"
			or "porta_time"
			or "integer"
			or "integer_8bit"
			or "integer_16bit"
			or "percent"
			or "tenths"
			or "tenths_of_percent"
			or "pitch_fine"
			or "balance"
			or "fx1_fx2_balance"
			or "filter_offset_freq";
	}

	private static void ApplyDeltaToParameter(ParameterBase p, int delta, bool pushed)
	{
		if (delta == 0) return;

		int span = Math.Max(0, p.RangeMax - p.RangeMin);
		int fineStep = 1;
		int coarseStep = Math.Max(1, (int)Math.Round(span * 0.01));
		int step = pushed ? fineStep : coarseStep;

		int rawStep = step * delta;

		if (p is IntParameter ip)
		{
			ip.Value = Mathf.Clamp(ip.Value + rawStep, ip.RangeMin, ip.RangeMax);
			return;
		}

		if (p is FloatParameter fp)
		{
			fp.Value = Math.Clamp(fp.Value + rawStep, p.RangeMin, p.RangeMax);
			return;
		}

		if (p is ListParameter lp)
		{
			int max = lp.Options.Count > 0 ? lp.Options.Count - 1 : lp.RangeMax;
			int min = 0;
			int listStep = pushed ? 1 : 1;
			lp.Index = Mathf.Clamp(lp.Index + (delta * listStep), min, max);
			return;
		}
	}

	// ----------------------------
	// Styling helpers
	// ----------------------------
	private void ClearTiles()
	{
		for (int i = 0; i < 16; i++)
		{
			var pv = _paramViews[i];
			var valueLabel = pv.GetNode<Label>("Panel/VSplitContainer/Value");
			var nameLabel = pv.GetNode<Label>("Panel/VSplitContainer/Name");
			var panel = pv.GetNode<Panel>("Panel");

			valueLabel.Text = "";
			nameLabel.Text = "";
			ApplyPanelOutline(panel, Colors.Black);
		}
	}

	private static void ApplyPanelOutline(Panel panel, Color outlineColor)
	{
		var sb = new StyleBoxFlat();
		sb.BorderWidthLeft = sb.BorderWidthTop = sb.BorderWidthRight = sb.BorderWidthBottom = 3;
		sb.BorderColor = outlineColor.Darkened(.5f);
		sb.BgColor = outlineColor;
		panel.AddThemeStyleboxOverride("panel", sb);
	}

	private static Color ToGodotColor(ControllerColor c)
	{
		return c switch
		{
			ControllerColor.BrightRed => Color.Color8(255, 0, 0),
			ControllerColor.DarkRed => Color.Color8(100, 0, 0),
			ControllerColor.BrightGreen => Color.Color8(0, 225, 0),
			ControllerColor.DarkGreen => Color.Color8(0, 95, 28),
			ControllerColor.BrightBlue => Color.Color8(66, 158, 255),
			ControllerColor.NavyBlue => Color.Color8(21, 41, 143),
			ControllerColor.Cyan => Color.Color8(0, 255, 255),
			ControllerColor.Lavender => Color.Color8(200, 192, 255),
			ControllerColor.Yellow => Color.Color8(200, 255, 0),
			ControllerColor.DarkYellow => Color.Color8(100, 128, 0),
			ControllerColor.DarkCyan => Color.Color8(0, 100, 100),
			ControllerColor.Rose => Color.Color8(200, 110, 175),
			ControllerColor.Orange => Color.Color8(232, 94, 0),
			ControllerColor.Pink => Color.Color8(230, 0, 100),
			ControllerColor.Violet => Color.Color8(128, 96, 132),
			ControllerColor.Amber => Color.Color8(225, 143, 0),
			ControllerColor.White => Color.Color8(200, 200, 200),
			ControllerColor.Black => Color.Color8(0, 0, 0),
			_ => Color.Color8(0, 0, 0),
		};
	}
}
