using Microsoft.AspNetCore.Mvc;
using VosNet.Core;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

/// <summary>Search; the role (USER or MODERATOR, ADMIN only by the
/// OWNER); lock and unlock; a temporary password, shown once; delete.</summary>
public sealed class UsersModel(ServerContext ctx) : AdminPage(ctx)
{
    [BindProperty(SupportsGet = true)] public string? Q { get; set; }
    public List<UserRow> Users { get; private set; } = [];
    public string? TempPassword { get; private set; }
    public string? TempFor { get; private set; }

    public void OnGet() => Users = Ctx.Users.Search(Q);

    IActionResult Done(AdminResult r, string ok)
    {
        Message = r switch { AdminResult.Ok => ok, AdminResult.NotFound => "NO SUCH USER.", _ => "NOT ALLOWED." };
        return RedirectToPage(new { q = Q });
    }

    public IActionResult OnPostRole(long id, Role role)
    {
        var r = Ctx.Accounts.SetRole(Me, id, role);
        return Done(r, $"{Ctx.Users.ById(id)?.Name} IS {Roles.Name(role)}.");
    }

    public IActionResult OnPostLock(long id, bool locked)
    {
        var r = Ctx.Accounts.Lock(Me, id, locked);
        if (r == AdminResult.Ok && locked && Ctx.Sessions.ByUser(id) is { } s) _ = s.KickAsync("web.kicked");
        return Done(r, $"{Ctx.Users.ById(id)?.Name} {(locked ? "LOCKED" : "UNLOCKED")}.");
    }

    public IActionResult OnPostTemp(long id)
    {
        var (r, pw) = Ctx.Accounts.TemporaryPassword(Me, id);
        if (r != AdminResult.Ok) return Done(r, "");
        TempPassword = pw;
        TempFor = Ctx.Users.ById(id)?.Name;
        Users = Ctx.Users.Search(Q);
        return Page();          // shown once: not kept anywhere
    }

    public IActionResult OnPostDelete(long id)
    {
        var name = Ctx.Users.ById(id)?.Name;
        var s = Ctx.Sessions.ByUser(id);
        var r = Ctx.Accounts.Delete(Me, id);
        if (r == AdminResult.Ok && s != null) _ = s.KickAsync("web.kicked");
        return Done(r, $"{name} DELETED.");
    }
}
