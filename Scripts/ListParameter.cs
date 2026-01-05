using System;
using System.Collections.Generic;

namespace ControllerApp.Model
{
    public sealed class ListParameter : ParameterBase
    {
        public int Index { get; set; }
        public IReadOnlyList<string> Options { get; }

        public ListParameter(
            string id,
            string name,
            string displayName,
            string units,
            NrpnAddress nrpn,
            int rangeMin,
            int rangeMax,
            ScalingKind scaling,
            int index,
            IReadOnlyList<string> options,
            string conv = "",
            bool signed14Bit = false)
            : base(id, ParameterKind.List, name, displayName, units, nrpn, rangeMin, rangeMax, scaling, conv, signed14Bit)
        {
            Index = index;
            Options = options ?? Array.Empty<string>();
        }

        public string CurrentOption =>
            (Index >= 0 && Index < Options.Count) ? Options[Index] : "";

        public override string FormatValue() => CurrentOption;

        public override double? DisplayNumeric()
        {
            // Sometimes list values are numeric strings (e.g. "-3".."3")
            if (double.TryParse(CurrentOption, out var n))
                return n;
            return null;
        }
    }
}
