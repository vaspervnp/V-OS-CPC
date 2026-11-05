using Microsoft.AspNetCore.Mvc;
using VosNet.Core;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

/// <summary>Topics: add, rename, order; threads and posts: delete, lock a thread.</summary>
public sealed class BoardsModel(ServerContext ctx) : AdminPage(ctx)
{
    public List<BoardRow> Boards { get; private set; } = [];
    public BoardRow? Board { get; private set; }
    public List<ThreadRow> Threads { get; private set; } = [];
    public ThreadRow? Thread { get; private set; }
    public List<PostRow> Posts { get; private set; } = [];

    public void OnGet(long? board, long? thread)
    {
        Boards = Ctx.Content.Boards();
        Board = Boards.FirstOrDefault(b => b.Id == board);
        if (Board != null) Threads = Ctx.Content.Threads(Board.Id);
        if (thread is { } t && Ctx.Content.Thread(t) is { } th && th.BoardId == Board?.Id)
        {
            Thread = th;
            Posts = Ctx.Content.Posts(th.Id);
        }
    }

    public IActionResult OnPostAdd(string en, string el)
    {
        if (!string.IsNullOrWhiteSpace(en) && !string.IsNullOrWhiteSpace(el))
        {
            Ctx.Content.AddBoard(en.Trim().ToUpperInvariant(), el.Trim().ToUpperInvariant());
            Audit("ADD TOPIC", en);
        }
        return RedirectToPage();
    }

    public IActionResult OnPostRename(long id, string en, string el)
    {
        if (!string.IsNullOrWhiteSpace(en) && !string.IsNullOrWhiteSpace(el))
        {
            Ctx.Content.RenameBoard(id, en.Trim().ToUpperInvariant(), el.Trim().ToUpperInvariant());
            Audit("RENAME TOPIC", en);
        }
        return RedirectToPage();
    }

    public IActionResult OnPostMove(long id, int by)
    {
        Ctx.Content.MoveBoard(id, Math.Sign(by));
        return RedirectToPage();
    }

    public IActionResult OnPostDeleteBoard(long id)
    {
        var b = Ctx.Content.Boards().FirstOrDefault(x => x.Id == id);
        Ctx.Content.DeleteBoard(id);
        Audit("DELETE TOPIC", b?.NameEn);
        return RedirectToPage();
    }

    public IActionResult OnPostLockThread(long board, long id, bool locked)
    {
        Ctx.Content.LockThread(id, locked);
        Audit(locked ? "LOCK THREAD" : "UNLOCK THREAD", Ctx.Content.Thread(id)?.Title);
        return RedirectToPage(new { board });
    }

    public IActionResult OnPostDeleteThread(long board, long id)
    {
        Audit("DELETE THREAD", Ctx.Content.Thread(id)?.Title);
        Ctx.Content.DeleteThread(id);
        return RedirectToPage(new { board });
    }

    public IActionResult OnPostDeletePost(long board, long thread, long id)
    {
        Audit("DELETE POST", Ctx.Content.Thread(thread)?.Title, id.ToString());
        Ctx.Content.DeletePost(id);
        return RedirectToPage(new { board, thread });
    }
}
