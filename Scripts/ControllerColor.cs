using System;
using System.Collections.Generic;

namespace ControllerApp.Model
{
    public enum ControllerColor : byte
    {
		BrightRed = 0,
		DarkRed = 1,
		BrightGreen = 2,
		DarkGreen = 3,
		BrightBlue = 4,
		NavyBlue = 5,
		Cyan = 6,
		Lavender = 7,
		Yellow = 8,
		DarkYellow = 9,
		DarkCyan = 10,
		Rose = 11,
		Orange = 12,
		Pink = 13,
		Violet = 14,
		Amber = 15,
		White = 16,
		Black = 17,
    }

    public static class ControllerColorUtil
    {
        private static readonly Dictionary<string, ControllerColor> _map =
            new(StringComparer.OrdinalIgnoreCase)
            {
                ["BrightRed"] = ControllerColor.BrightRed,
                ["DarkRed"] = ControllerColor.DarkRed,
                ["BrightGreen"] = ControllerColor.BrightGreen,
                ["DarkGreen"] = ControllerColor.DarkGreen,
                ["BrightBlue"] = ControllerColor.BrightBlue,
                ["NavyBlue"] = ControllerColor.NavyBlue,
                ["Cyan"] = ControllerColor.Cyan,
                ["Lavender"] = ControllerColor.Lavender,
                ["Yellow"] = ControllerColor.Yellow,
                ["DarkYellow"] = ControllerColor.DarkYellow,
                ["DarkCyan"] = ControllerColor.DarkCyan,
                ["Rose"] = ControllerColor.Rose,
                ["Orange"] = ControllerColor.Orange,
                ["Pink"] = ControllerColor.Pink,
                ["Violet"] = ControllerColor.Violet,
                ["Amber"] = ControllerColor.Amber,
                ["White"] = ControllerColor.White,
                ["Black"] = ControllerColor.Black,
            };

        public static ControllerColor ParseOrDefault(string? s, ControllerColor fallback = ControllerColor.Black)
        {
            if (string.IsNullOrWhiteSpace(s)) return fallback;
            return _map.TryGetValue(s.Trim(), out var c) ? c : fallback;
        }
    }
}
