using System.Net;
using VosNet.Core.Storage;
using VosNet.Telnet;

namespace VosNet.Core.Screens;

/// <summary>Each screen: it runs until the user leaves it and gives the
/// next screen, or null to end the connection.</summary>
public interface IScreen
{
    Task<IScreen?> RunAsync(Session s, CancellationToken ct);
}

/// <summary>One user on one connection: the screens one after another,
/// the language, who logged in, and the writing to the terminal by its
/// profile (wrapped at its width, a page at a time).</summary>
public sealed class Session
{
    readonly CancellationTokenSource _end;

    public Session(TelnetConnection conn, ServerContext ctx, IPAddress ip, int port)
    {
        Conn = conn;
        Ctx = ctx;
        Ip = Services.BanList.Normal(ip);
        Port = port;
        Since = ctx.Time.GetUtcNow();
        _end = CancellationTokenSource.CreateLinkedTokenSource(conn.Closed);
        Lang = ctx.Texts.Languages[0];
    }

    public Guid Id { get; } = Guid.NewGuid();
    public TelnetConnection Conn { get; }
    public ServerContext Ctx { get; }
    public IPAddress Ip { get; }
    public int Port { get; }
    public DateTimeOffset Since { get; }
    public string Lang { get; set; }
    public UserRow? User { get; set; }
    public bool Guest { get; set; }
    public bool ReachedMenu { get; set; }
    /// <summary>The screen, a text key ("where.chat"...), for WHO.</summary>
    public string Where { get; set; } = "where.welcome";
    public CancellationToken Token => _end.Token;
    public TerminalProfile Profile => Conn.Profile;

    public string Name => User?.Name ?? "GUEST";
    public Role Role => User?.RoleValue ?? Role.User;
    public bool CanWrite => User != null && !Guest;
    public bool IsModerator => User != null && Role >= Role.Moderator;

    /// <summary>The width of the screens: the terminal's, but not over 80.</summary>
    public int Cols => Math.Min(Profile.Width, 80);

    public string T(string key) => Ctx.Texts.Get(Lang, key);
    public string T(string key, params object?[] args) => Ctx.Texts.Get(Lang, key, args);

    /// <summary>Text, wrapped, each row ended by CR LF.</summary>
    public Task OutAsync(string text = "") =>
        Conn.WriteAsync(string.Concat(TextWrap.Wrap(text, Profile.Width).Select(r => r + "\r\n")));

    /// <summary>A title: in colour on an ANSI terminal.</summary>
    public Task TitleAsync(string text) =>
        Profile.Ansi ? Conn.WriteAsync("\x1b[1;36m" + TextWrap.Fit(text, Cols).TrimEnd() + "\x1b[0m\r\n") : OutAsync(text);

    public Task RuleAsync() => OutAsync(new string('-', Cols));

    /// <summary>A heading line: the title on the left, <paramref name="right"/> on the right.</summary>
    public Task HeaderAsync(string title, string right)
    {
        var pad = Math.Max(1, Cols - title.Length - right.Length);
        return TitleAsync(title + new string(' ', pad) + right);
    }

    /// <summary>A prompt, the cursor after it.</summary>
    public Task PromptAsync(string text) => Conn.WriteAsync(text);

    /// <summary>A line from the user, or null: the connection closed, or
    /// <paramref name="deadline"/> passed. Idle 13 minutes: a warning;
    /// 15: the end. V-OS shows the line typed only at the bottom, so a new
    /// line follows for its window.</summary>
    public async Task<string?> ReadAsync(DateTimeOffset? deadline = null, CancellationToken interrupt = default)
    {
        var time = Ctx.Time;
        bool warned = false;
        while (!Token.IsCancellationRequested)
        {
            var now = time.GetUtcNow();
            var idle = now - Conn.LastInput;
            if (deadline is { } d && now >= d) { Conn.Close(); return null; }
            if (idle >= Ctx.Options.IdleClose)
            {
                await OutAsync("\r\n" + T("idle.bye"));
                Conn.Close();
                return null;
            }
            if (idle < Ctx.Options.IdleWarning) warned = false;
            else if (!warned)
            {
                warned = true;
                await OutAsync("\r\n" + T("idle.warning"));
            }
            var left = (idle < Ctx.Options.IdleWarning ? Ctx.Options.IdleWarning : Ctx.Options.IdleClose) - idle;
            if (deadline is { } d2 && d2 - now < left) left = d2 - now;
            using var timeout = new CancellationTokenSource(left, time);
            using var both = CancellationTokenSource.CreateLinkedTokenSource(Token, timeout.Token, interrupt);
            try
            {
                var line = await Conn.ReadLineAsync(both.Token);
                if (line == null) return null;
                if (Profile.Kind == TerminalKind.Vos) await Conn.WriteAsync("\r\n");
                return line.Trim();
            }
            catch (OperationCanceledException) when (!Token.IsCancellationRequested && !interrupt.IsCancellationRequested) { }
        }
        return null;
    }

    public async Task<string?> AskAsync(string prompt, int max = 45)
    {
        await PromptAsync(prompt);
        var line = await ReadAsync();
        return line != null && line.Length > max ? line[..max] : line;
    }

    /// <summary>The password: WILL ECHO before it and WONT ECHO after it
    /// (§3); a common client then shows nothing, and we answer * for each
    /// character.</summary>
    public async Task<string?> AskPasswordAsync(string prompt)
    {
        await Conn.SetPasswordAsync(true);
        await PromptAsync(prompt);
        try
        {
            using var timeout = new CancellationTokenSource(Ctx.Options.IdleClose, Ctx.Time);
            using var both = CancellationTokenSource.CreateLinkedTokenSource(Token, timeout.Token);
            var line = await Conn.ReadLineAsync(both.Token);
            if (line != null && Profile.Kind == TerminalKind.Vos) await Conn.WriteAsync("\r\n");
            return line;
        }
        catch (OperationCanceledException) { return null; }
        finally { await Conn.SetPasswordAsync(false); }
    }

    /// <summary>Rows a page at a time (18 on V-OS): RETURN the next, Q
    /// stops. false: stopped, or the connection closed.</summary>
    public async Task<bool> PageAsync(IEnumerable<string> text)
    {
        var rows = text.SelectMany(t => TextWrap.Wrap(t, Profile.Width)).ToList();
        int page = Math.Max(4, Profile.PageRows);
        for (int i = 0; i < rows.Count; i += page)
        {
            var n = Math.Min(page, rows.Count - i);
            await Conn.WriteAsync(string.Concat(rows.Skip(i).Take(n).Select(r => r + "\r\n")));
            if (i + n < rows.Count)
            {
                await PromptAsync(T("page.more"));
                var a = await ReadAsync();
                if (a == null || a.Equals("Q", StringComparison.OrdinalIgnoreCase)) return false;
            }
        }
        return true;
    }

    /// <summary>A message out of turn (the chat's, the server restarting).</summary>
    public Task NoticeAsync(string key) => OutAsync("\r\n*** " + T(key) + " ***");

    /// <summary>Closed from elsewhere: by a new login of the same user,
    /// by a moderator, by the web.</summary>
    public async Task KickAsync(string key)
    {
        await NoticeAsync(key);
        _end.Cancel();
        Conn.Close();
    }
}
