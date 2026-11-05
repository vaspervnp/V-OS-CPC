using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Time.Testing;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Tests;

/// <summary>The fake V-OS (and other clients) against the whole server.</summary>
public partial class ScenarioTests : IAsyncLifetime
{
    protected VosNetFactory F = new();
    protected int Port;

    public async Task InitializeAsync() => Port = await F.TelnetPortAsync();

    public async Task DisposeAsync()
    {
        await F.DisposeAsync();
        F.DeleteDir();
    }

    /// <summary>Connected, Greek chosen: the entry's choice on the screen.</summary>
    protected async Task<TestClient> GreekAsync(bool vos = true)
    {
        var c = await TestClient.ConnectAsync(Port, vos);
        await c.WaitAsync("2 ΕΛΛΗΝΙΚΑ");
        await c.SendAsync("2");
        await c.WaitAsync("3 ΕΠΙΣΚΕΠΤΗΣ");
        return c;
    }

    protected async Task<TestClient> LoginAsync(string name, string pw, bool vos = true)
    {
        var c = await GreekAsync(vos);
        await c.SendAsync("1");
        await c.WaitAsync("ΟΝΟΜΑ: ");
        await c.SendAsync(name);
        await c.WaitAsync("ΚΩΔΙΚΟΣ: ");
        await c.SendAsync(pw);
        await c.WaitAsync("Q QUIT");
        return c;
    }

    [Fact]
    public async Task VosSeesTheWelcomeAndTheMenuInGreekAt48()
    {
        await using var c = await TestClient.ConnectAsync(Port);
        var welcome = await c.WaitAsync("1 ENGLISH  2 ΕΛΛΗΝΙΚΑ");
        Assert.Contains("ΤΟ BBS ΤΟΥ V-OS", welcome);
        Assert.Contains(@"\_/        \___/|____/", welcome);
        Assert.Contains((Telnet.Telnet.DO, Telnet.Telnet.TTYPE), c.Negotiations);
        Assert.Contains((Telnet.Telnet.DO, Telnet.Telnet.NAWS), c.Negotiations);
        await c.SendAsync("2");
        await c.WaitAsync("1 ΣΥΝΔΕΣΗ  2 ΕΓΓΡΑΦΗ  3 ΕΠΙΣΚΕΠΤΗΣ");
        await c.SendAsync("3");
        var menu = await c.WaitAsync("Q QUIT        ΕΞΟΔΟΣ");
        Assert.Contains("V-OS NET                                1 ONLINE", menu);
        Assert.Contains("2 BOARDS      ΠΙΝΑΚΑΣ ΜΗΝΥΜΑΤΩΝ", menu);
        Assert.Contains(new string('-', 48), menu);
        await c.SendAsync("5");
        var who = await c.WaitAsync("RETURN: ΠΙΣΩ");
        Assert.Contains("GUEST        V-OS", who);                  // the profile came out V-OS
        await c.SendAsync("");
        await c.WaitAsync("Q QUIT");
        await c.SendAsync("Q");
        await c.WaitAsync("ΓΕΙΑ ΣΟΥ ΑΠΟ ΤΟ V-OS NET!");
        await c.WaitClosedAsync();
        c.AssertVosScreen();
        Assert.Equal(48, c.MaxColumns);
    }

    [Fact]
    public async Task RegisterThenLoginFromVos()
    {
        F.OneQuestion();
        await using (var c = await GreekAsync())
        {
            await c.SendAsync("2");
            await c.WaitAsync("ΟΝΟΜΑ: ");
            await c.SendAsync("Sysop");
            await c.WaitAsync("ΚΡΑΤΗΜΕΝΟ");
            await c.SendAsync("NIKOS");
            var w = await c.WaitAsync("ΚΩΔΙΚΟΣ (8-40): ");
            Assert.Contains("ΤΟ TELNET ΔΕΝ ΕΙΝΑΙ ΚΡΥΠΤΟΓΡΑΦΗΜΕΝΟ", w);
            Assert.Contains((Telnet.Telnet.WILL, Telnet.Telnet.ECHO), c.Negotiations);
            await c.SendAsync("short");
            await c.WaitAsync("ΚΩΔΙΚΟΣ (8-40): ");
            await c.SendAsync("secret-cpc-6128");
            await c.WaitAsync("ΞΑΝΑ: ");
            await c.SendAsync("secret-cpc-6128");
            await c.WaitAsync("EMAIL");
            await c.SendAsync("");
            await c.WaitAsync("2+2;");
            await c.SendAsync("4");
            await c.WaitAsync("ΚΑΛΩΣ ΗΡΘΕΣ, NIKOS! Η ΕΓΓΡΑΦΗ ΕΓΙΝΕ.");
            await c.WaitAsync("Q QUIT");
            await c.SendAsync("Q");
            await c.WaitClosedAsync();
            c.AssertVosScreen();
            Assert.DoesNotContain("secret-cpc-6128", c.Text);
            Assert.DoesNotContain("*", c.Text);                       // V-OS refused ECHO: no stars either
        }
        await using (var c = await LoginAsync("nikos", "secret-cpc-6128"))
        {
            await c.SendAsync("5");
            Assert.Contains("NIKOS        V-OS", await c.WaitAsync("RETURN: ΠΙΣΩ"));
            c.AssertVosScreen();
        }
        Assert.NotNull(F.Get<UserStore>().ByName("NIKOS"));
    }

    [Fact]
    public async Task ACommonClientGetsUtf8AndTheStarsForThePassword()
    {
        F.AddUser("MARIA", "maria-password");
        await using var c = await TestClient.ConnectAsync(Port, vos: false);
        await c.WaitAsync("2 ΕΛΛΗΝΙΚΑ");                            // UTF-8
        await c.SendAsync("2");
        await c.WaitAsync("3 ΕΠΙΣΚΕΠΤΗΣ");
        await c.SendAsync("1");
        await c.WaitAsync("ΟΝΟΜΑ: ");
        await c.SendAsync("MARIA");
        await c.WaitAsync("ΚΩΔΙΚΟΣ: ");
        Assert.True(c.ServerEcho);                                    // WILL ECHO, DO ECHO
        await c.TypeAsync("maria-pazz\b\bssword");                    // as PuTTY: a character at a time
        var after = await c.WaitAsync("Q QUIT");
        Assert.Contains("ΚΩΔΙΚΟΣ: **********\b \b\b \b******\r\n", after);
        Assert.False(c.ServerEcho);                                   // WONT ECHO after it
        Assert.True(c.SawEsc);                                        // ANSI colours for it
        Assert.DoesNotContain("password", c.Text);
        await c.SendAsync("5");
        Assert.Contains("MARIA        UTF8", await c.WaitAsync("RETURN: ΠΙΣΩ"));
    }

    [Fact]
    public async Task APlainClientGetsAsciiInLatinLetters()
    {
        await using var c = await TestClient.ConnectAsync(Port);
        // it answers nothing: as netcat (the fake V-OS answers, so a raw socket)
        using var raw = new System.Net.Sockets.TcpClient();
        await raw.ConnectAsync("127.0.0.1", Port);
        var s = raw.GetStream();
        var buf = new byte[4096];
        var got = new List<byte>();
        var end = DateTime.UtcNow.AddSeconds(8);
        while (DateTime.UtcNow < end && !System.Text.Encoding.ASCII.GetString(got.ToArray()).Contains("2 ELLINIKA"))
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(1));
            try { got.AddRange(buf.AsSpan(0, await s.ReadAsync(buf, cts.Token)).ToArray()); } catch (OperationCanceledException) { }
        }
        var text = System.Text.Encoding.Latin1.GetString(got.ToArray());
        Assert.Contains("1 ENGLISH  2 ELLINIKA", text);
        Assert.Contains("TO BBS TOY V-OS", text);
        Assert.DoesNotContain(got.Skip(6), b => b > 127);
    }

    [Fact]
    public async Task TwoClientsTalkInTheChat()
    {
        F.AddUser("NIKOS", "nikos-password");
        F.AddUser("MARIA", "maria-password");
        await using var a = await LoginAsync("NIKOS", "nikos-password");
        await using var b = await LoginAsync("MARIA", "maria-password");
        await a.SendAsync("3");
        await a.WaitAsync("/WHO  /ME ΚΕΙΜΕΝΟ  /QUIT");
        await b.SendAsync("3");
        await b.WaitAsync("/QUIT");
        await a.WaitAsync("ΜΠΗΚΕ Ο/Η MARIA");
        await b.SendAsync("ΓΕΙΑ ΣΟΥ ΝΙΚΟ, ΤΙ ΚΑΝΕΙΣ;");
        await a.WaitAsync("<MARIA> ΓΕΙΑ ΣΟΥ ΝΙΚΟ, ΤΙ ΚΑΝΕΙΣ;");
        await a.SendAsync("/me γράφει από τον CPC");
        await b.WaitAsync("* NIKOS γράφει από τον CPC");
        await b.SendAsync("/who");
        await b.WaitAsync("-- NIKOS, MARIA");
        await a.SendAsync("/quit");
        await a.WaitAsync("Q QUIT");
        await b.WaitAsync("ΕΦΥΓΕ Ο/Η NIKOS");
        // who comes in sees the last lines
        await a.SendAsync("3");
        await a.WaitAsync("<MARIA> ΓΕΙΑ ΣΟΥ ΝΙΚΟ, ΤΙ ΚΑΝΕΙΣ;");
        a.AssertVosScreen();
        b.AssertVosScreen();
    }

    [Fact]
    public async Task FiveChatLinesIn10Seconds()
    {
        F.AddUser("NIKOS", "nikos-password");
        await using var a = await LoginAsync("NIKOS", "nikos-password");
        await a.SendAsync("3");
        await a.WaitAsync("/QUIT");
        for (int i = 0; i < 5; i++) await a.SendAsync($"line {i}");
        await a.SendAsync("one too many");
        await a.WaitAsync("ΠΙΟ ΑΡΓΑ");
    }

    [Fact]
    public async Task ASecondLoginClosesTheFirst()
    {
        F.AddUser("NIKOS", "nikos-password");
        await using var a = await LoginAsync("NIKOS", "nikos-password");
        await using var b = await LoginAsync("NIKOS", "nikos-password");
        await a.WaitAsync("ΣΥΝΔΕΘΗΚΕΣ ΑΠΟ ΑΛΛΟΥ");
        await a.WaitClosedAsync();
        Assert.False(b.Closed);
    }

    [Fact]
    public async Task AGuestOnlyReads()
    {
        await using var c = await GreekAsync();
        await c.SendAsync("3");
        await c.WaitAsync("Q QUIT");
        await c.SendAsync("3");
        await c.WaitAsync("/QUIT");
        await c.SendAsync("hello");
        await c.WaitAsync("Ο ΕΠΙΣΚΕΠΤΗΣ ΜΟΝΟ ΔΙΑΒΑΖΕΙ");
        await c.SendAsync("/quit");
        await c.WaitAsync("Q QUIT");
        await c.SendAsync("4");
        await c.WaitAsync("RETURN: ΠΙΣΩ");
        await c.SendAsync("S");
        await c.WaitAsync("Ο ΕΠΙΣΚΕΠΤΗΣ ΜΟΝΟ ΔΙΑΒΑΖΕΙ");
    }

    [Fact]
    public async Task OnePostAMinute()
    {
        F.AddUser("NIKOS", "nikos-password");
        await using var c = await LoginAsync("NIKOS", "nikos-password");
        await c.SendAsync("2");
        await c.WaitAsync("ΘΕΜΑ, RETURN ΠΙΣΩ");
        await c.SendAsync("1");
        await c.WaitAsync("N ΝΕΟ");
        await c.SendAsync("N");
        await c.WaitAsync("ΤΙΤΛΟΣ: ");
        await c.SendAsync("ΠΡΩΤΟ ΝΗΜΑ");
        await c.WaitAsync(" 1: ");
        await c.SendAsync("Η ΠΡΩΤΗ ΓΡΑΜΜΗ");
        await c.WaitAsync(" 2: ");
        await c.SendAsync(".");
        await c.WaitAsync("RETURN ΤΟ ΣΤΕΛΝΕΙ");
        await c.SendAsync("");
        await c.WaitAsync("ΠΡΩΤΟ ΝΗΜΑ");
        await c.SendAsync("1");
        await c.WaitAsync("R ΑΠΑΝΤΗΣΗ");
        await c.SendAsync("R");
        await c.WaitAsync("ΕΝΑ ΜΗΝΥΜΑ ΤΟ ΛΕΠΤΟ");
        c.AssertVosScreen();
    }

    [Fact]
    public async Task TheLatestReleaseInNewsWrappedAndPaged()
    {
        await F.Get<ReleasesCache>().RefreshAsync(CancellationToken.None);
        F.Get<ContentStore>().AddNews("A LONG ONE", string.Join("\n", Enumerable.Range(1, 30).Select(i => $"ROW {i}: " + new string('x', 30))), "VASILHS", 1000);
        await using var c = await GreekAsync();
        await c.SendAsync("3");
        await c.WaitAsync("Q QUIT");
        await c.SendAsync("1");
        var list = await c.WaitAsync("ΑΡΙΘΜΟΣ ΓΙΑ ΑΝΑΓΝΩΣΗ");
        Assert.Contains(" 1 05.11.26 V-OS 0.53", list);
        await c.SendAsync("1");
        var news = await c.WaitAsync("RETURN: ΠΙΣΩ");
        Assert.Contains("MAIL AND FTP", news);
        Assert.Contains("- MAIL: POP3, SMTP over the M4", news);
        await c.SendAsync("");
        await c.WaitAsync("ΑΡΙΘΜΟΣ ΓΙΑ ΑΝΑΓΝΩΣΗ");
        await c.SendAsync("3");
        var page = await c.WaitAsync("RETURN: ΣΥΝΕΧΕΙΑ, Q: ΤΕΛΟΣ");
        Assert.Contains("ROW 18:", page);                             // 18 rows on V-OS's 20
        Assert.DoesNotContain("ROW 19:", page);
        await c.SendAsync("");
        await c.WaitAsync("ROW 30:");
        c.AssertVosScreen();
    }

    [Fact]
    public async Task AModeratorKicksAndDeletes()
    {
        F.AddUser("MOD", "moderator-pw", Role.Moderator);
        F.AddUser("NIKOS", "nikos-password");
        await using var m = await LoginAsync("MOD", "moderator-pw");
        await using var n = await LoginAsync("NIKOS", "nikos-password");
        await m.SendAsync("3");
        await m.WaitAsync("/KICK");
        await n.SendAsync("3");
        await n.WaitAsync("/QUIT");
        await n.SendAsync("spam");
        var line = await m.WaitAsync("<NIKOS> spam");
        var id = line[..line.IndexOf("<NIKOS>")].Split('\n').Last().Trim();
        await m.SendAsync("/del " + id);
        await n.WaitAsync($"Η ΓΡΑΜΜΗ {id} ΔΙΑΓΡΑΦΗΚΕ");
        await m.SendAsync("/kick NIKOS");
        await n.WaitAsync("ΣΕ ΕΒΓΑΛΕ ΕΞΩ ΕΝΑΣ ΣΥΝΤΟΝΙΣΤΗΣ");
        await n.WaitClosedAsync();
        Assert.Contains(F.Get<AdminStore>().AuditLog(), a => a.Action == "KICK" && a.Target == "NIKOS");
    }
}

/// <summary>The messages stay after a restart.</summary>
public class RestartTests
{
    [Fact]
    public async Task TheGuestbookAndTheBoardsAfterARestart()
    {
        var dir = Path.Combine(Path.GetTempPath(), "vosnet-test-" + Guid.NewGuid().ToString("N"));
        await using (var f = new VosNetFactory(dir))
        {
            var port = await f.TelnetPortAsync();
            f.AddUser("NIKOS", "nikos-password");
            var s = new ScenarioLogin(port);
            await using var c = await s.LoginAsync("NIKOS", "nikos-password");
            await c.SendAsync("4");
            await c.WaitAsync("S ΥΠΟΓΡΑΦΗ");
            await c.SendAsync("S");
            await c.WaitAsync("Η ΓΡΑΜΜΗ ΣΟΥ: ");
            await c.SendAsync("ΧΑΙΡΕΤΙΣΜΑΤΑ ΑΠΟ ΤΟ ΗΡΑΚΛΕΙΟ");
            await c.WaitAsync("ΕΥΧΑΡΙΣΤΟΥΜΕ!");
        }
        var g = new VosNetFactory(dir);
        try
        {
            var port = await g.TelnetPortAsync();
            await using var c = await new ScenarioLogin(port).GreekAsync();
            await c.SendAsync("3");
            await c.WaitAsync("Q QUIT");
            await c.SendAsync("4");
            var book = await c.WaitAsync("RETURN: ΠΙΣΩ");
            Assert.Contains("NIKOS ", book);
            Assert.Contains("  ΧΑΙΡΕΤΙΣΜΑΤΑ ΑΠΟ ΤΟ ΗΡΑΚΛΕΙΟ", book);
        }
        finally
        {
            await g.DisposeAsync();
            g.DeleteDir();
        }
    }
}

sealed class ScenarioLogin(int port)
{
    public async Task<TestClient> GreekAsync()
    {
        var c = await TestClient.ConnectAsync(port);
        await c.WaitAsync("2 ΕΛΛΗΝΙΚΑ");
        await c.SendAsync("2");
        await c.WaitAsync("3 ΕΠΙΣΚΕΠΤΗΣ");
        return c;
    }

    public async Task<TestClient> LoginAsync(string name, string pw)
    {
        var c = await GreekAsync();
        await c.SendAsync("1");
        await c.WaitAsync("ΟΝΟΜΑ: ");
        await c.SendAsync(name);
        await c.WaitAsync("ΚΩΔΙΚΟΣ: ");
        await c.SendAsync(pw);
        await c.WaitAsync("Q QUIT");
        return c;
    }
}

/// <summary>The time limits, with a fake clock.</summary>
public class TimeTests : IAsyncLifetime
{
    readonly FakeTimeProvider _time = new(DateTimeOffset.UtcNow);
    VosNetFactory _f = null!;
    int _port;

    public async Task InitializeAsync()
    {
        _f = new VosNetFactory { Services_ = s => s.AddSingleton<TimeProvider>(_time) };
        _port = await _f.TelnetPortAsync();
    }

    public async Task DisposeAsync()
    {
        await _f.DisposeAsync();
        _f.DeleteDir();
    }

    [Fact]
    public async Task NoChoiceIn60SecondsCloses()
    {
        await using var c = await TestClient.ConnectAsync(_port);
        await c.WaitAsync("2 ΕΛΛΗΝΙΚΑ");
        await Task.Delay(300);
        _time.Advance(TimeSpan.FromSeconds(61));
        await c.WaitClosedAsync();
    }

    [Fact]
    public async Task IdleWarnedAt13AndOutAt15()
    {
        await using var c = await new ScenarioLogin(_port).GreekAsync();
        await c.SendAsync("3");
        await c.WaitAsync("Q QUIT");
        await Task.Delay(300);
        _time.Advance(TimeSpan.FromMinutes(13));
        await c.WaitAsync("13 ΛΕΠΤΑ ΧΩΡΙΣ ΤΙΠΟΤΑ");
        Assert.False(c.Closed);
        await Task.Delay(300);
        _time.Advance(TimeSpan.FromMinutes(2));
        await c.WaitAsync("15 ΛΕΠΤΑ ΧΩΡΙΣ ΤΙΠΟΤΑ. ΓΕΙΑ ΣΟΥ!");
        await c.WaitClosedAsync();
        c.AssertVosScreen();
    }
}

/// <summary>V-OS's answers through the M4 board came 3.4 seconds late in
/// the 1984 emulator: a late WONT still makes the profile V-OS, and the
/// welcome is written again in Greek.</summary>
public class LateAnswerTests
{
    [Fact]
    public async Task ALateWontStillMakesItVos()
    {
        var f = new VosNetFactory();
        f.Settings["VosNet:DetectWait"] = "00:00:01";
        try
        {
            var port = await f.TelnetPortAsync();
            await using var c = await TestClient.ConnectAsync(port, vos: true, answerDelayMs: 2000);
            await c.WaitAsync("1 ENGLISH  2 ELLINIKA");                  // plain at first
            await c.WaitAsync("1 ENGLISH  2 ΕΛΛΗΝΙΚΑ");                  // then V-OS
            await c.SendAsync("2");
            await c.WaitAsync("3 ΕΠΙΣΚΕΠΤΗΣ");
            await c.SendAsync("3");
            await c.WaitAsync("Q QUIT");
            await c.SendAsync("5");
            Assert.Contains("GUEST        V-OS", await c.WaitAsync("RETURN: ΠΙΣΩ"));
            c.AssertVosScreen();
        }
        finally
        {
            await f.DisposeAsync();
            f.DeleteDir();
        }
    }
}

/// <summary>V-OS's TELNET from 0.54 answers TTYPE with "V-OS" and takes
/// the server's ECHO: the profile is V-OS at once, the password is *.</summary>
public partial class ScenarioTests
{
    [Fact]
    public async Task TtypeVosAndThePasswordAsStars()
    {
        F.AddUser("NIKOS", "nikos-password");
        await using var c = await TestClient.ConnectAsync(Port, vos: true, ttype: true);
        await c.WaitAsync("2 ΕΛΛΗΝΙΚΑ");
        await c.SendAsync("2");
        await c.WaitAsync("3 ΕΠΙΣΚΕΠΤΗΣ");
        await c.SendAsync("1");
        await c.WaitAsync("ΟΝΟΜΑ: ");
        await c.SendAsync("NIKOS");
        await c.WaitAsync("ΚΩΔΙΚΟΣ: ");
        Assert.True(c.ServerEcho);
        await c.SendAsync("nikos-password");
        var after = await c.WaitAsync("Q QUIT");
        Assert.StartsWith("**************\r\n\r\nV-OS NET", after);       // one CR LF of the stars, then the menu's
        Assert.False(c.ServerEcho);
        await c.SendAsync("5");
        Assert.Contains("NIKOS        V-OS", await c.WaitAsync("RETURN: ΠΙΣΩ"));
        c.AssertVosScreen();
        Assert.DoesNotContain("nikos-password", c.Text);
    }
}
