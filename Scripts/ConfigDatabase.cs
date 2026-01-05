using Godot;
using System;
using System.Collections.Generic;
using GDict = Godot.Collections.Dictionary;
using GArray = Godot.Collections.Array;

namespace ControllerApp.Model
{
    public partial class ConfigDatabase : Node
    {
        public Dictionary<string, ParameterBase> ParametersById { get; private set; } = new();
        public List<ParameterGroup> Groups { get; private set; } = new();
        public int ActiveGroupIndex { get; set; } = 0;

        public void LoadAll(string paramsPath = "res://data/parameters.json", string groupsPath = "res://data/groups_micron.json")
        {
            ParametersById = LoadParameters(paramsPath);
            (Groups, ActiveGroupIndex) = LoadGroups(groupsPath, ParametersById);
        }

        private static Dictionary<string, ParameterBase> LoadParameters(string path)
        {
            var root = LoadJson(path);
            var dict = new Dictionary<string, ParameterBase>();

            if (!root.TryGetValue("parameters", out var pArrVar) || pArrVar.VariantType != Variant.Type.Array)
                return dict;

            var pArr = (GArray)pArrVar;
            foreach (var v in pArr)
            {
                if (v.VariantType != Variant.Type.Dictionary) continue;
                var p = (GDict)v;

                var id = p.GetValueOrDefault("id", "").AsString();
                if (string.IsNullOrWhiteSpace(id)) continue;

                var kindStr = p.GetValueOrDefault("type", "int").AsString().ToLowerInvariant();
                var name = p.GetValueOrDefault("name", "").AsString();
                var display = p.GetValueOrDefault("display_name", "").AsString();
                var units = p.GetValueOrDefault("units", "").AsString();

                // nrpn: { msb, lsb }
                var nrpnDict = p.GetValueOrDefault("nrpn", new GDict()).AsGodotDictionary();
                var msb = (int)nrpnDict.GetValueOrDefault("msb", 0);
                var lsb = (int)nrpnDict.GetValueOrDefault("lsb", 0);
                var nrpn = new NrpnAddress(msb, lsb);

                // range: [min,max]
                int rMin = 0, rMax = 0;
                var rangeVar = p.GetValueOrDefault("range", new GArray());
                if (rangeVar.VariantType == Variant.Type.Array)
                {
                    var ra = (GArray)rangeVar;
                    if (ra.Count >= 2)
                    {
                        rMin = (int)ra[0];
                        rMax = (int)ra[1];
                    }
                }

                var scalingStr = p.GetValueOrDefault("scaling", "linear").AsString().ToLowerInvariant();
                var scaling = scalingStr == "log" ? ScalingKind.Log : ScalingKind.Linear;

                var conv = p.GetValueOrDefault("conv", "").AsString();
                var signed14 = p.GetValueOrDefault("signed14bit", false).AsBool();

                // value
                var valueVar = p.GetValueOrDefault("value", 0);

                ParameterBase paramObj;
                if (kindStr == "list")
                {
                    var opts = new List<string>();
                    var optVar = p.GetValueOrDefault("options", new GArray());
                    if (optVar.VariantType == Variant.Type.Array)
                    {
                        foreach (var ov in (GArray)optVar)
                            opts.Add(ov.AsString());
                    }
                    var idx = (int)valueVar;
                    paramObj = new ListParameter(id, name, display, units, nrpn, rMin, rMax, scaling, idx, opts, conv, signed14);
                }
                else if (kindStr == "float")
                {
                    var fv = valueVar.VariantType == Variant.Type.Float ? (double)valueVar : (double)(int)valueVar;
                    paramObj = new FloatParameter(id, name, display, units, nrpn, rMin, rMax, scaling, fv, conv, signed14);
                }
                else
                {
                    // int
                    paramObj = new IntParameter(id, name, display, units, nrpn, rMin, rMax, scaling, (int)valueVar, conv, signed14);
                }

                dict[id] = paramObj;
            }

            return dict;
        }

        private static (List<ParameterGroup>, int) LoadGroups(string path, Dictionary<string, ParameterBase> parameters)
        {
            var root = LoadJson(path);
            int active = (int)root.GetValueOrDefault("active", 0);

            var groups = new List<ParameterGroup>();
            if (!root.TryGetValue("groups", out var gArrVar) || gArrVar.VariantType != Variant.Type.Array)
                return (groups, active);

            foreach (var gv in (GArray)gArrVar)
            {
                if (gv.VariantType != Variant.Type.Dictionary) continue;
                var g = (GDict)gv;

                var name = g.GetValueOrDefault("name", "Unnamed").AsString();
                var grp = new ParameterGroup(name);

                // parameters list
                var pidsVar = g.GetValueOrDefault("parameters", new GArray());
                if (pidsVar.VariantType == Variant.Type.Array)
                {
                    foreach (var pidV in (GArray)pidsVar)
                    {
                        var pid = pidV.AsString();
                        if (parameters.ContainsKey(pid))
                            grp.ParameterIds.Add(pid);
                        else
                            GD.PushWarning($"Group '{name}' references missing parameter id: {pid}");
                    }
                }

                // controllers map
                var ctrlVar = g.GetValueOrDefault("controllers", new GDict());
                if (ctrlVar.VariantType == Variant.Type.Dictionary)
                {
                    var cd = (GDict)ctrlVar;
                    foreach (var key in cd.Keys)
                        grp.ControllerForParam[key.AsString()] = (int)cd[key];
                }

                // controller_colors array -> enum
                var colVar = g.GetValueOrDefault("controller_colors", new GArray());
                if (colVar.VariantType == Variant.Type.Array)
                {
                    var ca = (GArray)colVar;
                    for (int i = 0; i < 16; i++)
                    {
                        var s = (i < ca.Count) ? ca[i].AsString() : "Black";
                        grp.ControllerColors[i] = ControllerColorUtil.ParseOrDefault(s, ControllerColor.Black);
                    }
                }

                groups.Add(grp);
            }

            if (groups.Count == 0) active = 0;
            else active = Mathf.Clamp(active, 0, groups.Count - 1);

            return (groups, active);
        }

        private static GDict LoadJson(string path)
        {
            using var f = FileAccess.Open(path, FileAccess.ModeFlags.Read);
            if (f == null)
            {
                GD.PushError($"Failed to open JSON: {path}");
                return new GDict();
            }

            var text = f.GetAsText();
            var parsed = Json.ParseString(text);
            if (parsed.VariantType != Variant.Type.Dictionary)
            {
                GD.PushError($"Invalid JSON (root not object): {path}");
                return new GDict();
            }
            return (GDict)parsed;
        }
    }

    internal static class GodotDictExt
    {
        public static GDict AsGodotDictionary(this Variant v)
            => v.VariantType == Variant.Type.Dictionary ? (GDict)v : new GDict();
    }
}
