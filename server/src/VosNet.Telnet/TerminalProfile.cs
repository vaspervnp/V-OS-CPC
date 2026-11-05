using System.Text;

namespace VosNet.Telnet;

public enum TerminalKind { Vos, Utf8, Ascii }

/// <summary>Who connected (§5 of DESIGN.md): V-OS's TELNET (48×20, the
/// V-OS set, no ANSI), a common client (its NAWS size or 80×24, UTF-8,
/// ANSI colours) or a plain one (netcat, robots: 80×24, ASCII with Greek
/// in Latin letters).</summary>
public sealed record TerminalProfile(TerminalKind Kind, int Width, int Height, bool Ansi)
{
    public static readonly TerminalProfile Vos = new(TerminalKind.Vos, 48, 20, false);
    public static readonly TerminalProfile Ascii = new(TerminalKind.Ascii, 80, 24, false);
    public static TerminalProfile Utf8(int width = 80, int height = 24) =>
        new(TerminalKind.Utf8, width <= 0 ? 80 : Math.Clamp(width, 32, 200), height <= 0 ? 24 : Math.Clamp(height, 10, 100), true);

    static readonly Encoding Utf8Strict = new UTF8Encoding(false, true);
    static readonly Encoding AsciiOut = Encoding.GetEncoding("us-ascii",
        new MappingEncoderFallback(c => c < 128, latin: true), DecoderFallback.ReplacementFallback);

    public string Name => Kind switch { TerminalKind.Vos => "V-OS", TerminalKind.Utf8 => "UTF8", _ => "ASCII" };

    public Encoding Output => Kind switch
    {
        TerminalKind.Vos => VosEncoding.Instance,
        TerminalKind.Utf8 => new UTF8Encoding(false),
        _ => AsciiOut,
    };

    /// <summary>Rows of text on a page, the last two for the "RETURN" line.</summary>
    public int PageRows => Height - 2;

    /// <summary>Text → bytes for the network, IAC (255) doubled.</summary>
    public byte[] Encode(string text) => DoubleIac(Output.GetBytes(text));

    public static byte[] DoubleIac(byte[] b)
    {
        if (Array.IndexOf(b, Telnet.IAC) < 0) return b;
        var r = new List<byte>(b.Length + 8);
        foreach (var x in b)
        {
            r.Add(x);
            if (x == Telnet.IAC) r.Add(x);
        }
        return r.ToArray();
    }

    /// <summary>A line from the client: the V-OS set from V-OS, from the
    /// others UTF-8, or (not valid UTF-8) ISO 8859-7.</summary>
    public string Decode(byte[] line)
    {
        if (Kind == TerminalKind.Vos) return VosEncoding.Instance.GetString(line);
        try { return Utf8Strict.GetString(line); }
        catch (DecoderFallbackException) { return VosEncoding.Instance.GetString(line); }
    }

    public static TerminalProfile? Parse(string name) => name.Trim().ToUpperInvariant() switch
    {
        "V-OS" or "VOS" => Vos,
        "UTF8" or "UTF-8" => Utf8(),
        "ASCII" => Ascii,
        _ => null,
    };
}
