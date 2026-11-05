using System.Globalization;
using System.Text;

namespace VosNet.Telnet;

/// <summary>What a character becomes where an encoding does not have it:
/// the typographic quotes, dashes and the ellipsis their ASCII, a letter
/// with accents or breathings (polytonic Greek, French...) its base
/// letter, and in Latin letters (<c>latin</c>: for an ASCII terminal) the
/// Greek letters as Greeklish; anything else (an emoji) "?".</summary>
public static class CharMap
{
    static readonly Dictionary<char, string> Signs = new()
    {
        ['ʼ'] = "'", ['‘'] = "'", ['’'] = "'", ['‚'] = "'", ['‛'] = "'", ['′'] = "'",
        ['΄'] = "'", ['΅'] = "'", ['´'] = "'", ['·'] = ";",
        ['“'] = "\"", ['”'] = "\"", ['„'] = "\"", ['″'] = "\"", ['«'] = "\"", ['»'] = "\"",
        ['…'] = "...", ['–'] = "-", ['—'] = "-", ['―'] = "-", ['−'] = "-", ['­'] = "-",
        [' '] = " ", [' '] = " ", [' '] = " ", [' '] = " ", [' '] = " ",
        ['€'] = "EUR", ['©'] = "(C)", ['®'] = "(R)", ['™'] = "TM", ['·'] = ".", ['•'] = "*",
        ['¿'] = "?", ['¡'] = "!", ['ß'] = "ss", ['œ'] = "oe", ['Œ'] = "OE", ['æ'] = "ae", ['Æ'] = "AE",
    };

    const string GreekCaps = "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ";
    static readonly string[] LatinCaps =
        ["A", "V", "G", "D", "E", "Z", "I", "TH", "I", "K", "L", "M", "N", "KS", "O", "P", "R", "S", "T", "Y", "F", "CH", "PS", "O"];

    /// <summary>The replacement of <paramref name="c"/>, made only of
    /// characters <paramref name="can"/> accepts (or "?").</summary>
    public static string Replace(char c, Func<char, bool> can, bool latin)
    {
        if (char.IsSurrogate(c)) return "?";
        if (latin && Greek(c) is { } g) return g;
        if (Signs.TryGetValue(c, out var s) && s.All(can)) return s;
        var d = c.ToString().Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder();
        foreach (var ch in d)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch) == UnicodeCategory.NonSpacingMark) continue;
            if (can(ch)) sb.Append(ch);
            else if (latin && Greek(ch) is { } lg) sb.Append(lg);
            else return "?";
        }
        if (sb.Length > 0) return sb.ToString();
        return "?";
    }

    /// <summary>A Greek letter in Latin letters, or null.</summary>
    public static string? Greek(char c)
    {
        var d = c.ToString().Normalize(NormalizationForm.FormD)[0];
        if (d == 'ς') d = 'σ';
        bool small = char.IsLower(d);
        int i = GreekCaps.IndexOf(char.ToUpperInvariant(d));
        if (i < 0) return null;
        var l = LatinCaps[i];
        return small ? l.ToLowerInvariant() : l;
    }

    /// <summary>A whole string by the rules above, for one encoding.</summary>
    public static string Map(string text, Func<char, bool> can, bool latin)
    {
        var sb = new StringBuilder(text.Length);
        for (int i = 0; i < text.Length; i++)
        {
            var c = text[i];
            if (can(c)) sb.Append(c);
            else
            {
                sb.Append(Replace(c, can, latin));
                if (char.IsHighSurrogate(c) && i + 1 < text.Length && char.IsLowSurrogate(text[i + 1])) i++;
            }
        }
        return sb.ToString();
    }
}

/// <summary>An <see cref="EncoderFallback"/> by <see cref="CharMap"/>.</summary>
public sealed class MappingEncoderFallback(Func<char, bool> can, bool latin) : EncoderFallback
{
    public override int MaxCharCount => 3;
    public override EncoderFallbackBuffer CreateFallbackBuffer() => new Buffer(can, latin);

    sealed class Buffer(Func<char, bool> can, bool latin) : EncoderFallbackBuffer
    {
        string _s = "";
        int _i;

        public override bool Fallback(char charUnknown, int index)
        {
            _s = CharMap.Replace(charUnknown, can, latin);
            _i = 0;
            return true;
        }

        public override bool Fallback(char high, char low, int index)
        {
            _s = "?";
            _i = 0;
            return true;
        }

        public override char GetNextChar() => _i < _s.Length ? _s[_i++] : '\0';
        public override bool MovePrevious() { if (_i == 0) return false; _i--; return true; }
        public override int Remaining => _s.Length - _i;
        public override void Reset() { _s = ""; _i = 0; }
    }
}
