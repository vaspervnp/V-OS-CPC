using System.Security.Claims;
using Microsoft.AspNetCore.Mvc.RazorPages;
using VosNet.Core;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Web;

/// <summary>What the admin pages share: the services, who is signed in,
/// a message after an action, the audit log.</summary>
public abstract class AdminPage(ServerContext ctx) : PageModel
{
    public ServerContext Ctx { get; } = ctx;
    UserRow? _me;

    public UserRow Me => _me ??= Ctx.Users.ById(long.Parse(User.FindFirstValue(WebSetup.UserIdClaim)!))!;
    public bool IsOwner => Me.RoleValue == Role.Owner;

    [Microsoft.AspNetCore.Mvc.TempData] public string? Message { get; set; }

    protected void Audit(string action, string? target, string? detail = null) =>
        Ctx.Admin.Audit(Ctx.Time.Unix(), Me.Id, Me.Name, action, target, detail);

    public string Date(long? unix) => unix is { } u ? Clock.FromUnix(u).ToString("yyyy-MM-dd HH:mm") + " UTC" : "-";
}
