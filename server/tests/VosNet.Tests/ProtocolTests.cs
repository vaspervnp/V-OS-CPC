using System.Text;
using VosNet.Telnet;
using static VosNet.Telnet.Telnet;

namespace VosNet.Tests;

public class TelnetParserTests
{
    static List<TelnetEvent> Parse(TelnetParser p, params byte[] b)
    {
        var e = new List<TelnetEvent>();
        p.Parse(b, e);
        return e;
    }

    [Fact]
    public void IacIacIsTheByte255()
    {
        var e = Parse(new TelnetParser(), 65, IAC, IAC, 66);
        Assert.Single(e);
        Assert.Equal(new byte[] { 65, 255, 66 }, e[0].Data);
    }

    [Fact]
    public void ACommandInPieces()
    {
        var p = new TelnetParser();
        Assert.Empty(Parse(p, IAC));
        Assert.Empty(Parse(p, WILL));
        var e = Parse(p, TTYPE, 72);
        Assert.Equal(TelnetEventKind.Negotiation, e[0].Kind);
        Assert.Equal((WILL, TTYPE), (e[0].Verb, e[0].Option));
        Assert.Equal(new byte[] { 72 }, e[1].Data);
    }

    [Fact]
    public void ASubnegotiationInPiecesWithIacIac()
    {
        var p = new TelnetParser();
        Assert.Empty(Parse(p, IAC, SB, NAWS, 0, 80));
        var e = Parse(p, IAC, IAC, 0, 24, IAC, SE, 33);
        Assert.Equal(TelnetEventKind.Subnegotiation, e[0].Kind);
        Assert.Equal(NAWS, e[0].Option);
        Assert.Equal(new byte[] { 0, 80, 255, 0, 24 }, e[0].Data);
        Assert.Equal(new byte[] { 33 }, e[1].Data);
    }

    [Fact]
    public void ASubnegotiationOver64BytesIsDropped()
    {
        var p = new TelnetParser();
        var b = new List<byte> { IAC, SB, TTYPE };
        b.AddRange(Enumerable.Repeat((byte)'x', 100));
        b.AddRange([IAC, SE, (byte)'A']);
        var e = Parse(p, [.. b]);
        Assert.Single(e);
        Assert.Equal("A"u8.ToArray(), e[0].Data);
        Assert.Equal(1, p.Dropped);
    }

    [Fact]
    public void ASubnegotiationCutShortByACommand()
    {
        var p = new TelnetParser();
        var e = Parse(p, IAC, SB, TTYPE, 0, 65, IAC, WONT, ECHO, 66);
        Assert.Equal(TelnetEventKind.Negotiation, e[0].Kind);
        Assert.Equal((WONT, ECHO), (e[0].Verb, e[0].Option));
        Assert.Equal(new byte[] { 66 }, e[1].Data);
        Assert.Equal(1, p.Dropped);
    }
}

public class OptionNegotiatorTests
{
    static OptionNegotiator New() => new(o => o is TTYPE or NAWS);

    [Fact]
    public void AskedAndAcceptedNoReply()
    {
        var n = New();
        var o = new List<byte>();
        n.AskHim(TTYPE, true, o);
        Assert.Equal(new byte[] { IAC, DO, TTYPE }, o);
        o.Clear();
        n.Receive(WILL, TTYPE, o);
        Assert.Empty(o);                        // no DO again: no loop
        Assert.True(n.IsHim(TTYPE));
        n.Receive(WILL, TTYPE, o);
        Assert.Empty(o);
    }

    [Fact]
    public void VosRefusesAll()
    {
        var n = New();
        var o = new List<byte>();
        n.AskHim(TTYPE, true, o);
        n.AskHim(NAWS, true, o);
        o.Clear();
        n.Receive(WONT, TTYPE, o);
        n.Receive(WONT, NAWS, o);
        Assert.Empty(o);
        Assert.False(n.IsHim(TTYPE));
        Assert.True(n.HimAnswered(TTYPE) && n.HimAnswered(NAWS));
        n.Receive(WONT, TTYPE, o);              // again: nothing
        Assert.Empty(o);
    }

    [Fact]
    public void WhatWeDoNotWantIsRefused()
    {
        var n = New();
        var o = new List<byte>();
        n.Receive(WILL, ECHO, o);
        Assert.Equal(new byte[] { IAC, DONT, ECHO }, o);
        o.Clear();
        n.Receive(DO, SGA, o);
        Assert.Equal(new byte[] { IAC, WONT, SGA }, o);
        o.Clear();
        n.Receive(WILL, NAWS, o);               // offered, and wanted
        Assert.Equal(new byte[] { IAC, DO, NAWS }, o);
    }

    [Fact]
    public void EchoOfferedRefusedThenWithdrawnSendsNothing()
    {
        var n = New();
        var o = new List<byte>();
        n.SetUs(ECHO, true, o);
        Assert.Equal(new byte[] { IAC, WILL, ECHO }, o);
        o.Clear();
        n.Receive(DONT, ECHO, o);               // V-OS: DONT
        Assert.Empty(o);
        n.SetUs(ECHO, false, o);                // already off: no WONT
        Assert.Empty(o);
    }

    [Fact]
    public void EchoAcceptedThenWithdrawn()
    {
        var n = New();
        var o = new List<byte>();
        n.SetUs(ECHO, true, o);
        n.Receive(DO, ECHO, o);
        Assert.True(n.IsUs(ECHO));
        o.Clear();
        n.SetUs(ECHO, false, o);
        Assert.Equal(new byte[] { IAC, WONT, ECHO }, o);
        o.Clear();
        n.Receive(DONT, ECHO, o);
        Assert.Empty(o);
        Assert.False(n.IsUs(ECHO));
    }

    [Fact]
    public void QueueOpposite()
    {
        var n = New();
        var o = new List<byte>();
        n.SetUs(ECHO, true, o);                 // WANTYES
        n.SetUs(ECHO, false, o);                // queued: OPPOSITE
        o.Clear();
        n.Receive(DO, ECHO, o);                 // the yes comes: now off
        Assert.Equal(new byte[] { IAC, WONT, ECHO }, o);
        o.Clear();
        n.Receive(DONT, ECHO, o);
        Assert.Empty(o);
        Assert.Equal(OptionNegotiator.Q.No, n.Us(ECHO));
    }
}

public class LineReaderTests
{
    static List<string> Lines(LineReader r, byte[] b)
    {
        var l = new List<string>();
        foreach (var x in b)
            if (r.Feed(x) == LineResult.Line) l.Add(Encoding.Latin1.GetString(r.Last));
        return l;
    }

    [Theory]
    [InlineData("abc\r\ndef\r\n")]
    [InlineData("abc\r\0def\r\0")]
    [InlineData("abc\ndef\n")]
    [InlineData("abc\rdef\r")]
    public void TheEndsOfALine(string s) =>
        Assert.Equal(["abc", "def"], Lines(new LineReader(), Encoding.Latin1.GetBytes(s)));

    [Fact]
    public void BackspaceAndDelete() =>
        Assert.Equal(["ad"], Lines(new LineReader(), Encoding.Latin1.GetBytes("abc\b\x7f" + "d\r\n")));

    [Fact]
    public void BackspaceTakesAWholeUtf8Letter() =>
        Assert.Equal("κα", Encoding.UTF8.GetString(Encoding.Latin1.GetBytes(
            Lines(new LineReader(), [.. Encoding.UTF8.GetBytes("καλ"), 8, 13, 10])[0])));

    [Fact]
    public void AtMost256Bytes()
    {
        var l = Lines(new LineReader(), [.. Enumerable.Repeat((byte)'x', 300), 13, 10]);
        Assert.Equal(256, l[0].Length);
    }

    [Fact]
    public void AnsiLeftOut() =>
        Assert.Equal(["ab"], Lines(new LineReader(), Encoding.Latin1.GetBytes("a\x1b[A\x1b[1;5Cb\x1bOD\r\n")));

    [Fact]
    public void ACharacterAtATime()
    {
        var r = new LineReader();
        Assert.Equal(LineResult.Added, r.Feed((byte)'a'));
        Assert.Equal(LineResult.Erased, r.Feed(127));
        Assert.Equal(LineResult.None, r.Feed(127));      // nothing to erase
        Assert.Equal(LineResult.Line, r.Feed(13));
        Assert.Equal(LineResult.None, r.Feed(0));
    }
}

public class WrapAndEncodingTests
{
    [Fact]
    public void WrappedAt48()
    {
        var text = string.Join(" ", Enumerable.Repeat("ΚΑΛΗΜΕΡΑ V-OS", 30)) + " " + new string('X', 120);
        var rows = TextWrap.Wrap(text, 48);
        Assert.All(rows, r => Assert.True(r.Length <= 48, r));
        Assert.Equal(text.Replace(" ", ""), string.Concat(rows).Replace(" ", ""));
        Assert.StartsWith("ΚΑΛΗΜΕΡΑ V-OS ΚΑΛΗΜΕΡΑ", rows[0]);
    }

    [Fact]
    public void ARowOfExactly48StaysOne() =>
        Assert.Single(TextWrap.Wrap(new string('-', 48), 48));

    [Fact]
    public void KalimeraIn28597()
    {
        Assert.Equal(new byte[] { 0xCA, 0xE1, 0xEB, 0xE7, 0xEC, 0xDD, 0xF1, 0xE1 }, TerminalProfile.Vos.Encode("Καλημέρα"));
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        Assert.Equal(Encoding.GetEncoding(28597).GetBytes("Καλημέρα ΑΒΓ"), TerminalProfile.Vos.Encode("Καλημέρα ΑΒΓ"));
    }

    [Fact]
    public void WhatV_OSHasNot()
    {
        // ’ is in ISO 8859-7 (#A2), ʼ and “” are not
        Assert.Equal("'A\xA2 \"B\" ...-?", Encoding.Latin1.GetString(TerminalProfile.Vos.Encode("ʼA’ “B” …—😀")));
        Assert.Equal("ἀ".Normalize(), "ἀ");
        Assert.Equal(TerminalProfile.Vos.Encode("α"), TerminalProfile.Vos.Encode("ἀ"));   // polytonic: the letter
        Assert.Equal(new byte[] { 0x85 }, TerminalProfile.Vos.Encode("È"));               // V-OS's own letters
        Assert.DoesNotContain((byte)255, TerminalProfile.Vos.Encode("¿ÿ"));               // never IAC
    }

    [Fact]
    public void AsciiInLatinLetters()
    {
        Assert.Equal("Kalimera, ELLINIKA THEMA", Encoding.ASCII.GetString(TerminalProfile.Ascii.Encode("Καλημέρα, ΕΛΛΗΝΙΚΑ ΘΕΜΑ")));
        Assert.Equal("\"cafe\" ?", Encoding.ASCII.GetString(TerminalProfile.Ascii.Encode("“café” 😀")));
    }

    [Fact]
    public void IacDoubled() =>
        Assert.Equal(new byte[] { 1, 255, 255, 2 }, TerminalProfile.DoubleIac([1, 255, 2]));

    [Fact]
    public void InputUtf8Or28597()
    {
        var p = TerminalProfile.Utf8();
        Assert.Equal("Καλημέρα", p.Decode(Encoding.UTF8.GetBytes("Καλημέρα")));
        Assert.Equal("Καλημέρα", p.Decode([0xCA, 0xE1, 0xEB, 0xE7, 0xEC, 0xDD, 0xF1, 0xE1]));
        Assert.Equal("Καλημέρα", TerminalProfile.Vos.Decode([0xCA, 0xE1, 0xEB, 0xE7, 0xEC, 0xDD, 0xF1, 0xE1]));
    }

    [Fact]
    public void ReleaseMarkdownAsText()
    {
        var t = VosNet.Core.Services.Markdown.ToText("## MAIL and FTP\n\n* **MAIL**: [POP3](http://x), `SMTP`\n<br>\n\n\n![p](i.png)last");
        Assert.Equal("MAIL AND FTP\n\n- MAIL: POP3, SMTP\n\nlast", t);
    }
}
