using System.Text;

namespace VosNet.Telnet;

public enum LineResult { None, Added, Erased, Line }

/// <summary>Data bytes → lines. A line ends with CR LF, CR NUL, CR or LF
/// alone; BS and DEL erase the last character (a whole UTF-8 sequence);
/// ANSI sequences (ESC [ ... letter, ESC O x) and other control bytes are
/// left out; a line keeps at most <see cref="Max"/> bytes. Clients that
/// send a character at a time (PuTTY while the password is asked) are
/// read the same way: <see cref="LineResult.Added"/> and
/// <see cref="LineResult.Erased"/> say when to answer with * or BS.</summary>
public sealed class LineReader(int max = LineReader.DefaultMax)
{
    public const int DefaultMax = 256;

    enum Esc { None, Esc, Csi, Ss3 }

    readonly List<byte> _line = new(max);
    bool _afterCr;
    Esc _esc;

    public int Max { get; } = max;

    /// <summary>The line ended by the last <see cref="LineResult.Line"/>.</summary>
    public byte[] Last { get; private set; } = [];

    public LineResult Feed(byte b)
    {
        if (_esc != Esc.None)
        {
            switch (_esc)
            {
                case Esc.Esc:
                    _esc = b == (byte)'[' ? Esc.Csi : b == (byte)'O' ? Esc.Ss3 : Esc.None;
                    break;
                case Esc.Csi:
                    if (b >= 0x40 && b <= 0x7E) _esc = Esc.None;
                    break;
                case Esc.Ss3:
                    _esc = Esc.None;
                    break;
            }
            return LineResult.None;
        }
        if (_afterCr)
        {
            _afterCr = false;
            if (b is 10 or 0) return LineResult.None;
        }
        switch (b)
        {
            case 13:
                _afterCr = true;
                return End();
            case 10:
                return End();
            case 8 or 127:
                if (_line.Count == 0) return LineResult.None;
                int i = _line.Count - 1;
                while (i > 0 && (_line[i] & 0xC0) == 0x80) i--;
                _line.RemoveRange(i, _line.Count - i);
                return LineResult.Erased;
            case 27:
                _esc = Esc.Esc;
                return LineResult.None;
        }
        if (b < 32) return LineResult.None;
        if (_line.Count >= Max) return LineResult.None;
        _line.Add(b);
        // a UTF-8 sequence counts once, at its first byte
        return (b & 0xC0) == 0x80 ? LineResult.None : LineResult.Added;
    }

    LineResult End()
    {
        Last = _line.ToArray();
        _line.Clear();
        return LineResult.Line;
    }

    /// <summary>The line typed so far (for tests).</summary>
    public string Pending => Encoding.Latin1.GetString(_line.ToArray());
}
