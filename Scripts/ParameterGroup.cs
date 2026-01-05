using System;
using System.Collections.Generic;

namespace ControllerApp.Model
{
    public sealed class ParameterGroup
    {
        public string Name { get; }
        public List<string> ParameterIds { get; } = new();
        public Dictionary<string, int> ControllerForParam { get; } = new(StringComparer.Ordinal);
        public ControllerColor[] ControllerColors { get; } = new ControllerColor[16];

        public ParameterGroup(string name)
        {
            Name = string.IsNullOrWhiteSpace(name) ? "Unnamed" : name;
            for (int i = 0; i < 16; i++) ControllerColors[i] = ControllerColor.Black;
        }

        public int ControllerFor(string paramId)
            => ControllerForParam.TryGetValue(paramId, out var c) ? c : -1;

        public ControllerColor ColorForController(int controller)
        {
            if (controller < 0 || controller >= 16) return ControllerColor.Black;
            return ControllerColors[controller];
        }
    }
}
