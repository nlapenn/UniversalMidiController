using System;

namespace ControllerApp.Model
{
    public sealed class IntParameter : ParameterBase
    {
        public int Value { get; set; }

        public IntParameter(
            string id,
            string name,
            string displayName,
            string units,
            NrpnAddress nrpn,
            int rangeMin,
            int rangeMax,
            ScalingKind scaling,
            int value,
            string conv = "",
            bool signed14Bit = false)
            : base(id, ParameterKind.Int, name, displayName, units, nrpn, rangeMin, rangeMax, scaling, conv, signed14Bit)
        {
            Value = value;
        }

        public override string FormatValue()
		{
			if (!string.IsNullOrWhiteSpace(Conv))
				return ConvFormatter.Format(Conv, Value);

			// fallback if no conv: show raw with units
			return Units.Length > 0 ? $"{Value} {Units}" : Value.ToString();
		}

		public override double? DisplayNumeric()
		{
			// For now, keep numeric raw; if later you want “display numeric after conv”
			// we can add a numeric converter table too.
			return Value;
		}
    }
}
