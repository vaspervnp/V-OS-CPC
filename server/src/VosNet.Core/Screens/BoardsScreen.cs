using VosNet.Core.Services;
using VosNet.Core.Storage;
using VosNet.Telnet;

namespace VosNet.Core.Screens;

/// <summary>The message boards: the topics, their threads, a thread's
/// posts. A text is written line by line and ends with "." alone, as on
/// the old BBSs (at most 20 lines); one post a minute.</summary>
public sealed class BoardsScreen : IScreen
{
    public const int MaxLines = 20, MaxLine = 120, MaxTitle = 40;

    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        s.Where = "where.boards";
        while (true)
        {
            var boards = s.Ctx.Content.Boards();
            await s.OutAsync();
            await s.TitleAsync(s.T("boards.title"));
            await s.RuleAsync();
            for (int i = 0; i < boards.Count; i++)
                await s.OutAsync($"{i + 1,2} {TextWrap.Fit(boards[i].Name(s.Lang), 30)}{s.T("boards.threads", boards[i].Threads)}");
            var a = await s.AskAsync(s.T("boards.choose"));
            if (a == null) return null;
            if (!int.TryParse(a, out var k) || k < 1 || k > boards.Count) return new MainMenuScreen();
            if (!await ThreadsAsync(s, boards[k - 1])) return null;
        }
    }

    /// <summary>false: the connection closed.</summary>
    static async Task<bool> ThreadsAsync(Session s, BoardRow board)
    {
        const int page = 12;
        int first = 0;
        while (true)
        {
            var threads = s.Ctx.Content.Threads(board.Id);
            if (first >= threads.Count) first = 0;
            await s.OutAsync();
            await s.HeaderAsync(board.Name(s.Lang), s.T("boards.threads", threads.Count));
            await s.RuleAsync();
            if (threads.Count == 0) await s.OutAsync(s.T("boards.nothreads"));
            for (int i = first; i < Math.Min(threads.Count, first + page); i++)
            {
                var t = threads[i];
                var mark = t.Locked != 0 ? "*" : " ";
                var right = $" {t.Posts,3} {s.Ctx.Date(t.LastPost)}";
                await s.OutAsync($"{i + 1,3}{mark}{TextWrap.Fit(t.Title, s.Cols - 4 - right.Length)}{right}");
            }
            var a = await s.AskAsync(s.T(threads.Count > first + page ? "threads.choose.more" : "threads.choose"));
            if (a == null) return false;
            var up = a.ToUpperInvariant();
            if (up == "+" && threads.Count > first + page) { first += page; continue; }
            if (up == "N")
            {
                if (await NewThreadAsync(s, board) == null) return false;
                continue;
            }
            if (int.TryParse(a, out var k) && k >= 1 && k <= threads.Count)
            {
                if (!await ReadAsync(s, threads[k - 1])) return false;
                continue;
            }
            return true;
        }
    }

    static async Task<bool> ReadAsync(Session s, ThreadRow thread)
    {
        while (true)
        {
            var t = s.Ctx.Content.Thread(thread.Id);
            if (t == null) return true;
            var posts = s.Ctx.Content.Posts(t.Id);
            var rows = new List<string> { "", t.Title.ToUpperInvariant(), new('-', s.Cols) };
            for (int i = 0; i < posts.Count; i++)
            {
                var p = posts[i];
                rows.Add($"#{i + 1} {p.Author} {s.Ctx.Date(p.Created, time: true)}");
                rows.Add(p.Body);
                rows.Add("");
            }
            if (!await s.PageAsync(rows)) return !s.Token.IsCancellationRequested;
            var prompt = t.Locked != 0 ? "thread.locked" : "thread.choose";
            if (s.IsModerator) prompt += ".mod";
            var a = await s.AskAsync(s.T(prompt));
            if (a == null) return false;
            var words = a.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
            var cmd = words.Length > 0 ? words[0].ToUpperInvariant() : "";
            if (cmd == "R" && t.Locked == 0)
            {
                var body = await ComposeAsync(s);
                if (body == null) return !s.Token.IsCancellationRequested;
                if (body.Length > 0) s.Ctx.Content.AddPost(t.Id, s.User!.Id, s.User.Name, body, s.Ctx.Time.Unix());
                continue;
            }
            if ((cmd == "D" || cmd == "/DEL") && s.IsModerator && words.Length > 1 && int.TryParse(words[1], out var n)
                && n >= 1 && n <= posts.Count)
            {
                s.Ctx.Content.DeletePost(posts[n - 1].Id);
                s.Ctx.Admin.Audit(s.Ctx.Time.Unix(), s.User!.Id, s.User.Name, "DELETE POST", t.Title, $"#{n} {posts[n - 1].Author}");
                await s.OutAsync(s.T("thread.deleted", n));
                if (n == 1) return true;
                continue;
            }
            return true;
        }
    }

    static async Task<long?> NewThreadAsync(Session s, BoardRow board)
    {
        if (!s.CanWrite) { await s.OutAsync(s.T("guest.readonly")); return 0; }
        var title = await s.AskAsync(s.T("thread.title"), MaxTitle);
        if (title == null) return null;
        if (title.Length == 0) return 0;
        var body = await ComposeAsync(s);
        if (body == null) return s.Token.IsCancellationRequested ? null : 0;
        if (body.Length == 0) return 0;
        return s.Ctx.Content.AddThread(board.Id, title, s.User!.Id, s.User.Name, body, s.Ctx.Time.Unix());
    }

    /// <summary>The text, line by line up to "." alone; "" when given up
    /// (or too soon after the last post), null when the connection closed.</summary>
    static async Task<string?> ComposeAsync(Session s)
    {
        if (!s.CanWrite) { await s.OutAsync(s.T("guest.readonly")); return ""; }
        var last = s.Ctx.Content.LastPostBy(s.User!.Id);
        var now = s.Ctx.Time.Unix();
        if (last is { } l && now - l < s.Ctx.Options.PostInterval.TotalSeconds)
        {
            await s.OutAsync(s.T("post.wait", (long)s.Ctx.Options.PostInterval.TotalSeconds - (now - l)));
            return "";
        }
        await s.OutAsync(s.T("post.how", MaxLines));
        var lines = new List<string>();
        while (lines.Count < MaxLines)
        {
            await s.PromptAsync($"{lines.Count + 1,2}: ");
            var line = await s.ReadAsync();
            if (line == null) return null;
            if (line == ".") break;
            lines.Add(line.Length > MaxLine ? line[..MaxLine] : line);
        }
        var body = string.Join("\n", lines).Trim();
        if (body.Length == 0) return "";
        var ok = await s.AskAsync(s.T("post.send"));
        if (ok == null) return null;
        return ok.Length == 0 || ok.ToUpperInvariant() is "Y" or "YES" or "N" or "ΝΑΙ" or "Ν" ? body : "";
    }
}
