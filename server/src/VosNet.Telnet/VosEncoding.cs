using System.Text;

namespace VosNet.Telnet;

/// <summary>The V-OS character set (tools/voscs.py): 0-127 ASCII, 160-255
/// ISO 8859-7 (code page 28597) as it is, so Greek is the same bytes,
/// and the letters of French, Spanish, German and Italian in the codes
/// ISO 8859-7 leaves free or V-OS does not use. 255 (¿ in V-OS) is never
/// written: it is telnet's IAC. What is not in the set goes by
/// <see cref="CharMap"/>.</summary>
public sealed class VosEncoding : Encoding
{
    public static readonly VosEncoding Instance = new();

    static readonly char[] Decode = new char[256];
    static readonly Dictionary<char, byte> EncodeMap = new();

    static VosEncoding()
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var greek = Encoding.GetEncoding(28597, EncoderFallback.ReplacementFallback, DecoderFallback.ReplacementFallback);
        int[] freed = [0xA0, 0xA5, 0xA6, 0xA9, 0xAA, 0xAC, 0xAD, 0xAE, 0xAF, 0xB1, 0xB2, 0xB3, 0xBD];
        for (int i = 0; i < 256; i++) Decode[i] = '?';
        for (int i = 0; i < 128; i++) Decode[i] = (char)i;
        for (int i = 0xA0; i < 0x100; i++)
        {
            if (freed.Contains(i)) continue;
            var c = greek.GetString([(byte)i]);
            if (c.Length == 1 && c[0] != '�' && c[0] != '?') Decode[i] = c[0];
        }
        // .NET's 28597 is the 1987 table; V-OS's (Python's) the 2003 one
        Decode[0xA1] = '\u2018';
        Decode[0xA2] = '\u2019';
        Decode[0xA4] = '\u20AC';
        const string caps = "ÀÁÂÄÇÈÉÊËÌÍÎÏÑÒÓÔÖÙÚÛÜ", small = "àáâäçèéêëìíîïñòóôöùúûüß";
        for (int i = 0; i < caps.Length; i++) Decode[0x80 + i] = caps[i];
        int[] smallCodes = [.. Enumerable.Range(0x96, 10), .. freed];
        for (int i = 0; i < small.Length; i++) Decode[smallCodes[i]] = small[i];
        Decode[0xD2] = '¡';
        Decode[0xFF] = '¿';
        for (int i = 255 - 1; i >= 0; i--)          // 255 left out
            if (Decode[i] != '?' || i == '?') EncodeMap[Decode[i]] = (byte)i;
    }

    public static bool Can(char c) => EncodeMap.ContainsKey(c);

    public override string EncodingName => "V-OS (ISO 8859-7)";

    public override int GetByteCount(char[] chars, int index, int count) =>
        GetBytesOf(new string(chars, index, count)).Length;

    public override int GetBytes(char[] chars, int charIndex, int charCount, byte[] bytes, int byteIndex)
    {
        var b = GetBytesOf(new string(chars, charIndex, charCount));
        b.CopyTo(bytes, byteIndex);
        return b.Length;
    }

    static byte[] GetBytesOf(string s)
    {
        var m = CharMap.Map(s, Can, latin: false);
        var r = new byte[m.Length];
        for (int i = 0; i < m.Length; i++) r[i] = EncodeMap.GetValueOrDefault(m[i], (byte)'?');
        return r;
    }

    public override int GetCharCount(byte[] bytes, int index, int count) => count;

    public override int GetChars(byte[] bytes, int byteIndex, int byteCount, char[] chars, int charIndex)
    {
        for (int i = 0; i < byteCount; i++) chars[charIndex + i] = Decode[bytes[byteIndex + i]];
        return byteCount;
    }

    public override int GetMaxByteCount(int charCount) => charCount * 3;
    public override int GetMaxCharCount(int byteCount) => byteCount;
}
