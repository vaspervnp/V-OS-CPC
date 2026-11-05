using VosNet.Core.Services;
using VosNet.Telnet;

namespace VosNet.Core.Screens;

/// <summary>The main menu (§2.3), by numbers since a line goes with
/// RETURN; the English words work too. TERM V-OS|UTF8|ASCII changes the
/// profile, LANG the language, PASSWORD the password.</summary>
public sealed class MainMenuScreen : IScreen
{
    static readonly string[] Items = ["NEWS", "BOARDS", "CHAT", "GUESTBOOK", "WHO", "HELP"];

    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        s.ReachedMenu = true;
        s.Where = "where.menu";
        await s.OutAsync();
        await s.HeaderAsync("V-OS NET", s.T("menu.online", s.Ctx.Sessions.Count));
        await s.RuleAsync();
        for (int i = 0; i < Items.Length; i++)
            await s.OutAsync($"{i + 1} {Items[i],-12}{s.T("menu." + Items[i].ToLowerInvariant())}");
        await s.OutAsync($"Q {"QUIT",-12}{s.T("menu.quit")}");
        while (true)
        {
            var a = await s.AskAsync(s.T("prompt"));
            if (a == null) return null;
            var words = a.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var cmd = words.Length > 0 ? words[0].ToUpperInvariant() : "";
            switch (cmd)
            {
                case "": return this;
                case "1" or "NEWS": return new NewsScreen();
                case "2" or "BOARDS": return new BoardsScreen();
                case "3" or "CHAT": return new ChatScreen();
                case "4" or "GUESTBOOK": return new GuestbookScreen();
                case "5" or "WHO": return new WhoScreen();
                case "6" or "HELP" or "?": return new HelpScreen();
                case "Q" or "QUIT" or "BYE": return new GoodbyeScreen();
                case "TERM":
                    if (words.Length > 1 && TerminalProfile.Parse(words[1]) is { } p)
                    {
                        s.Conn.Profile = p.Kind == TerminalKind.Utf8 ? TerminalProfile.Utf8(s.Conn.NawsWidth, s.Conn.NawsHeight) : p;
                        s.Conn.ProfileFixed = true;
                        await s.OutAsync(s.T("term.set", s.Profile.Name, s.Profile.Width, s.Profile.Height));
                        return this;
                    }
                    await s.OutAsync(s.T("term.usage", s.Profile.Name));
                    break;
                case "LANG":
                    var langs = s.Ctx.Texts.Languages;
                    s.Lang = langs[(langs.ToList().IndexOf(s.Lang) + 1) % langs.Count];
                    return this;
                case "PASSWORD" when s.CanWrite:
                    return new ChangePasswordScreen(mustChange: false);
                default:
                    await s.OutAsync(s.T("menu.unknown"));
                    break;
            }
        }
    }
}

/// <summary>Who is here: the name, the terminal, where, for how long.</summary>
public sealed class WhoScreen : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        s.Where = "where.who";
        await s.OutAsync();
        await s.HeaderAsync(s.T("who.title"), s.T("menu.online", s.Ctx.Sessions.Count));
        await s.RuleAsync();
        var now = s.Ctx.Time.GetUtcNow();
        var rows = s.Ctx.Sessions.All.Select(x =>
            $"{TextWrap.Fit(x.Name, 13)}{TextWrap.Fit(x.Profile.Name, 6)}{TextWrap.Fit(s.T(x.Where), 18)}{(int)(now - x.Since).TotalMinutes,4}'");
        await s.PageAsync(rows);
        await s.AskAsync(s.T("back"));
        return new MainMenuScreen();
    }
}

public sealed class HelpScreen : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        s.Where = "where.help";
        await s.OutAsync();
        await s.TitleAsync(s.T("help.title"));
        await s.RuleAsync();
        await s.PageAsync([s.T("help.text", s.Ctx.Options.HostName)]);
        await s.AskAsync(s.T("back"));
        return new MainMenuScreen();
    }
}

/// <summary>The news: the announcements and V-OS's releases on GitHub,
/// newest first; a number reads one.</summary>
public sealed class NewsScreen : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        s.Where = "where.news";
        var items = new List<(string Head, long When, string Body)>();
        foreach (var n in s.Ctx.Content.News(10))
            items.Add((n.Title, n.Created, n.Body));
        foreach (var r in s.Ctx.Releases.Releases.Take(10))
            items.Add((r.Name.Contains(r.Tag.TrimStart('v')) ? r.Name : $"V-OS {r.Tag} {r.Name}", r.Published.ToUnixTimeSeconds(), r.Text));
        items = items.OrderByDescending(i => i.When).Take(12).ToList();
        while (true)
        {
            await s.OutAsync();
            await s.TitleAsync(s.T("news.title"));
            await s.RuleAsync();
            if (items.Count == 0) await s.OutAsync(s.T("news.none"));
            for (int i = 0; i < items.Count; i++)
                await s.OutAsync(TextWrap.Fit($"{i + 1,2} {s.Ctx.Date(items[i].When)} {items[i].Head}", s.Cols).TrimEnd());
            var a = await s.AskAsync(s.T("news.choose"));
            if (a == null) return null;
            if (!int.TryParse(a, out var k) || k < 1 || k > items.Count) return new MainMenuScreen();
            var it = items[k - 1];
            await s.OutAsync();
            await s.TitleAsync(it.Head);
            await s.OutAsync(s.Ctx.Date(it.When));
            await s.RuleAsync();
            if (!await s.PageAsync([it.Body])) continue;
            if (await s.AskAsync(s.T("back")) == null) return null;
        }
    }
}

/// <summary>The guest book: the newest first; S signs it with a line of
/// at most 45 characters.</summary>
public sealed class GuestbookScreen : IScreen
{
    public const int Max = 45;

    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        s.Where = "where.guestbook";
        while (true)
        {
            await s.OutAsync();
            await s.TitleAsync(s.T("guestbook.title"));
            await s.RuleAsync();
            var rows = new List<string>();
            foreach (var g in s.Ctx.Content.Guestbook(100))
            {
                rows.Add($"{g.Author} {s.Ctx.Date(g.Created)}");
                rows.Add("  " + g.Text);
            }
            if (rows.Count == 0) rows.Add(s.T("guestbook.empty"));
            await s.PageAsync(rows);
            var a = await s.AskAsync(s.T(s.CanWrite ? "guestbook.choose" : "back"));
            if (a == null) return null;
            if (!a.Equals("S", StringComparison.OrdinalIgnoreCase)) return new MainMenuScreen();
            if (!s.CanWrite) { await s.OutAsync(s.T("guest.readonly")); continue; }
            var text = await s.AskAsync(s.T("guestbook.write"), Max);
            if (text == null) return null;
            if (text.Length == 0) continue;
            s.Ctx.Content.Sign(s.User!.Id, s.User.Name, text, s.Ctx.Time.Unix());
            await s.OutAsync(s.T("guestbook.thanks"));
        }
    }
}
