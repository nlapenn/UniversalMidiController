using System;
using System.Collections.Generic;

namespace ControllerApp.Model
{
    public static class ConvFormatter
    {
        private static string HzToString(double hz)
        {
            if (hz >= 1000.0)
                return $"{hz / 1000.0:0.000} KHz";
            return $"{hz:0.000} Hz";
        }

        private static string MsToString(double ms)
        {
            if (ms >= 1000.0)
                return $"{ms / 1000.0:0.000} s";
            return $"{ms:0.000} ms";
        }

        private static int AsInt(double v) => (int)Math.Round(v);

        private static string Percent(double v) => $"{AsInt(v)}%";
        private static string TenthsOfPercent(double v) => $"{AsInt(v) / 10.0:0.0}%";
        private static string Tenths(double v) => $"{AsInt(v) / 10.0:0.0}";
        private static string PitchFine(double v) => Tenths(v);

        private static string Balance(double v) => $"{50 - AsInt(v)}% f1";
        private static string Fx1Fx2Balance(double v) => $"{50 - AsInt(v)}% fx1";

        private static string FilterOffsetFreq(double v) => $"{AsInt(v) / 100.0:0.00}";

        private static string FilterFreq(double v)
        {
            int raw = AsInt(v);
            if (raw == 920) return "10.000 KHz";
            double hz = 20.0 * Math.Pow(1000.0, raw / 1023.0);
            return HzToString(hz);
        }

        private static string LfoFreq(double v)
        {
            int raw = AsInt(v);
            double hz = 0.01 * Math.Pow((1000.0 / 0.01), raw / 1023.0);
            return HzToString(hz);
        }

        private static string EnvTime(double v)
        {
            int raw = AsInt(v);
            if (raw == 256) return "hold";
            double ms = 0.5 * Math.Pow((30000.0 / 0.5), raw / 255.0);
            return MsToString(ms);
        }

        private static string ReleaseTime(double v)
        {
            int raw = AsInt(v);
            if (raw == 256) return "hold";
            double ms = 2.0 * Math.Pow((30000.0 / 2.0), raw / 255.0);
            return MsToString(ms);
        }

        private static string PortaTime(double v)
        {
            int raw = AsInt(v);
            double ms = 10.0 * Math.Pow(1000.0, raw / 127.0);
            return MsToString(ms);
        }

        private static string Integer(double v) => AsInt(v).ToString();

        private static readonly Dictionary<string, Func<double, string>> ConvToText =
            new(StringComparer.OrdinalIgnoreCase)
            {
                ["percent"] = Percent,
                ["tenths_of_percent"] = TenthsOfPercent,
                ["tenths"] = Tenths,
                ["pitch_fine"] = PitchFine,
                ["balance"] = Balance,
                ["fx1_fx2_balance"] = Fx1Fx2Balance,
                ["filter_offset_freq"] = FilterOffsetFreq,
                ["filter_freq"] = FilterFreq,
                ["lfo_freq"] = LfoFreq,
                ["env_time"] = EnvTime,
                ["release_time"] = ReleaseTime,
                ["porta_time"] = PortaTime,
                ["integer"] = Integer,
                ["integer_8bit"] = Integer,
                ["integer_16bit"] = Integer,
            };

        public static string Format(string? conv, double rawValue)
        {
            if (string.IsNullOrWhiteSpace(conv))
                return rawValue.ToString();

            if (ConvToText.TryGetValue(conv.Trim(), out var fn))
                return fn(rawValue);

            return rawValue.ToString();
        }
    }
}
