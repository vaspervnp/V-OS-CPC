using Microsoft.AspNetCore.Mvc;
using VosNet.Core;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

/// <summary>Who is connected (user, IP, profile, screen), their
/// disconnection; registrations and logins a day.</summary>
public sealed class IndexModel(ServerContext ctx) : AdminPage(ctx)
{
    public List<DayCount> Days { get; private set; } = [];

    public void OnGet() => Days = Ctx.Admin.Days(Ctx.Time.Unix());

    public async Task<IActionResult> OnPostKickAsync(Guid id)
    {
        var s = Ctx.Sessions.Get(id);
        if (s != null)
        {
            await s.KickAsync("web.kicked");
            Audit("DISCONNECT", s.Name, s.Ip.ToString());
            Message = $"{s.Name} ({s.Ip}) DISCONNECTED.";
        }
        return RedirectToPage();
    }
}
