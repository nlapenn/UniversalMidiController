using Godot;
using System;
using System.Collections.Generic;
using ControllerApp.Model;

public partial class App : Node2D
{
	[Export] public string ParametersPath { get; set; } = "res://data/parameters.json";
	[Export] public string GroupsPath { get; set; } = "res://data/groups_micron.json";

	private ItemList _groupList = default!;
	private readonly List<Node> _paramViews = new(); // 16 ParameterView instances
	private ConfigDatabase _db = new();

	private readonly Dictionary<int, string> _controllerToParamId = new();

	private Node _serialNode = default!;

	public override void _Ready()
	{
		// --- UI nodes live under the Control child ---
		_groupList = GetNode<ItemList>("Control/VSplitContainer/HSplitContainer/VSplitContainer2/ItemList");

		var grid = GetNode<GridContainer>("Control/VSplitContainer/ParameterGrid8x2");
		_paramViews.Clear();
		for (int i = 1; i <= 16; i++)
		{
			_paramViews.Add(grid.GetNode<Node>($"ParameterView{i}"));
		}

		// --- Load configs ---
		_db.LoadAll(ParametersPath, GroupsPath);

		// --- Populate group list ---
		_groupList.Clear();
		for (int i = 0; i < _db.Groups.Count; i++)
			_groupList.AddItem(_db.Groups[i].Name);

		_groupList.ItemSelected += OnGroupSelected;

		// select active group
		var active = Mathf.Clamp(_db.ActiveGroupIndex, 0, Math.Max(0, _db.Groups.Count - 1));
		if (_db.Groups.Count > 0)
		{
			_groupList.Select(active);
			_groupList.EnsureCurrentIsVisible();
			ApplyGroupToTiles(active);
		}

		_serialNode = GetNode<Node>("%Serial");
		GD.Print(_serialNode);
		_serialNode.Connect("controller_event", new Callable(this, nameof(OnControllerEvent)));
		_serialNode.Connect("nav_event", new Callable(this, nameof(OnNavEvent)));

		GD.Print($"Loaded params={_db.ParametersById.Count}, groups={_db.Groups.Count}, active={active}");
	}

	private void OnGroupSelected(long index)
	{
		int i = (int)index;
		_db.ActiveGroupIndex = i; // make property settable in ConfigDatabase (see note below)
		ApplyGroupToTiles(i);

		//SendActiveGroupColors();
	}

	private void SendActiveGroupColors()
	{
		if (_db.Groups.Count == 0) return;

		var grp = _db.Groups[_db.ActiveGroupIndex];

		var arr = new Godot.Collections.Array();
		for (int i = 0; i < 16; i++)
			arr.Add((int)grp.ControllerColors[i]); // enum -> int

		_serialNode.Call("send_controller_colors_enum", arr);
	}

	private void ApplyGroupToTiles(int groupIndex)
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

			// If you want unassigned controllers to be grey regardless of group colors:
			// var color = p == null ? ControllerColor.Grey : grp.ControllerColors[c];

			var color = grp.ControllerColors[c];
			SetParameterTile(c, p, color);
		}

		if (_serialNode != null)
		{
			SendActiveGroupColors();
		}
	}

	private void SetParameterTile(int controllerIndex, ParameterBase? p, ControllerColor color)
	{
		var pv = _paramViews[controllerIndex];

		var valueLabel = pv.GetNode<Label>("Panel/VSplitContainer/Value");
		var nameLabel = pv.GetNode<Label>("Panel/VSplitContainer/Name");
		var panel = pv.GetNode<Panel>("Panel");

		if (p == null)
		{
			valueLabel.Text = "";
			nameLabel.Text = "";
			ApplyPanelOutline(panel, Colors.Black);
			return;
		}
		else
		{
			valueLabel.Text = p.FormatValue();
			nameLabel.Text = p.DisplayName;
		}

		var col = ToGodotColor(color);
		ApplyPanelOutline(panel, col);
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

	private void OnControllerEvent(int controller, int delta, bool pushed)
	{
		if (controller == 17)
		{
			if (delta != 0) SelectGroupRelative(delta);
			return;
		}

		if (controller < 0 || controller >= 16) return;
		if (delta == 0) return;

		if (!_controllerToParamId.TryGetValue(controller, out var pid)) return;
		if (!_db.ParametersById.TryGetValue(pid, out var p)) return;

		ApplyDeltaToParameter(p, delta, pushed);

		var grp = _db.Groups[_db.ActiveGroupIndex];
		SetParameterTile(controller, p, grp.ControllerColors[controller]);
	}

	private void OnNavEvent(string action, bool pressed)
	{
		if (!pressed) return; // only act on press

		action = action.Trim();
		if (action.Equals("Up", StringComparison.OrdinalIgnoreCase))
			SelectGroupRelative(-1);
		else if (action.Equals("Down", StringComparison.OrdinalIgnoreCase))
			SelectGroupRelative(+1);
	}

	private void SelectGroupRelative(int delta)
	{
		if (_db.Groups.Count == 0) return;

		int cur = _db.ActiveGroupIndex;
		int next = cur + (delta > 0 ? 1 : -1);
		next = Mathf.Clamp(next, 0, _db.Groups.Count - 1);

		if (next == cur) return;

		_db.ActiveGroupIndex = next;
		_groupList.Select(next);
		_groupList.EnsureCurrentIsVisible();
		ApplyGroupToTiles(next);
	}

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

		// Fine/coarse step in *raw units*
		int span = Math.Max(0, p.RangeMax - p.RangeMin);

		// Fine: 1 raw unit
		int fineStep = 1;

		// Coarse: 1% of span, at least 1
		int coarseStep = Math.Max(1, (int)Math.Round(span * 0.01));

		int step = pushed ? fineStep : coarseStep;

		// Apply signed delta (and support delta magnitude > 1)
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
			// Lists don't have a meaningful "1% of range" feel, so:
			// fine: +/-1 option, coarse: bigger jump (optional)
			int max = lp.Options.Count > 0 ? lp.Options.Count - 1 : lp.RangeMax;
			int min = 0;

			int listStep = pushed ? 1 : 1; // you can make coarse bigger later if you want
			lp.Index = Mathf.Clamp(lp.Index + (delta * listStep), min, max);
			return;
		}
	}
}
