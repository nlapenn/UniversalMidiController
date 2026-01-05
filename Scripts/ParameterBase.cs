using System;

namespace ControllerApp.Model
{
    public enum ParameterKind { Int, Float, List }
    public enum ScalingKind { Linear, Log }

    public abstract class ParameterBase
    {
        public string Id { get; }
        public ParameterKind Kind { get; }
        public string Name { get; }
        public string DisplayName { get; }
        public string Units { get; }
        public NrpnAddress Nrpn { get; }

        public int RangeMin { get; }
        public int RangeMax { get; }
        public ScalingKind Scaling { get; }

        // Optional helpers from your JSON
        public string Conv { get; }           // e.g. "percent", "porta_time"
        public bool Signed14Bit { get; }      // if you add this later

        protected ParameterBase(
            string id,
            ParameterKind kind,
            string name,
            string displayName,
            string units,
            NrpnAddress nrpn,
            int rangeMin,
            int rangeMax,
            ScalingKind scaling,
            string conv,
            bool signed14Bit)
        {
            Id = id;
            Kind = kind;
            Name = name;
            DisplayName = string.IsNullOrWhiteSpace(displayName) ? name : displayName;
            Units = units ?? "";
            Nrpn = nrpn;
            RangeMin = rangeMin;
            RangeMax = rangeMax;
            Scaling = scaling;
            Conv = conv ?? "";
            Signed14Bit = signed14Bit;
        }

        public abstract string FormatValue();
        public abstract double? DisplayNumeric(); // numeric value after conv if applicable

        public override string ToString() => $"{Id} ({Kind}) = {FormatValue()}";
    }
}
