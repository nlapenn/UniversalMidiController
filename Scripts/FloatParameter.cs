using System;

namespace ControllerApp.Model
{
    public sealed class FloatParameter : ParameterBase
    {
        public double Value { get; set; }

        public FloatParameter(
            string id,
            string name,
            string displayName,
            string units,
            NrpnAddress nrpn,
            int rangeMin,
            int rangeMax,
            ScalingKind scaling,
            double value,
            string conv = "",
            bool signed14Bit = false)
            : base(id, ParameterKind.Float, name, displayName, units, nrpn, rangeMin, rangeMax, scaling, conv, signed14Bit)
        {
            Value = value;
        }

        public override string FormatValue()
		{
			if (!string.IsNullOrWhiteSpace(Conv))
				return ConvFormatter.Format(Conv, Value);

			return Units.Length > 0 ? $"{Value:0.###} {Units}" : $"{Value:0.###}";
		}

		public override double? DisplayNumeric() => Value;
    }
}
