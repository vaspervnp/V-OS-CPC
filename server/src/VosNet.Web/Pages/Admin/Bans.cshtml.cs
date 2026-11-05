using Microsoft.AspNetCore.Mvc;
using VosNet.Core;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

/// <summary>IP or CIDR, until when, why; those the server put itself
/// (§7: robots, login failures) are "SERVER"'s.</summary>
public sealed class BansModel(ServerContext ctx) : AdminPage(ctx)
{
    public List<BanRow> Bans { get; private set; } = [];

    public void OnGet() => Bans = Ctx.Admin.Bans(Ctx.Time.Unix(), all: true).Take(300).ToList();

    public IActionResult OnPostAdd(string ip, int? hours, string reason)
    {
        if (!BanList.TryParse(ip ?? "", out var net))
        {
            Message = "NOT AN IP OR A CIDR RANGE.";
            return RedirectToPage();
        }
        var key = (ip ?? "").Contains('/') ? net.ToString() : (ip ?? "").Trim();
        Ctx.Bans.Add(key, hours is > 0 ? TimeSpan.FromHours(hours.Value) : null, (reason ?? "").Trim(), Me.Name);
        Audit("BAN", key, reason);
        foreach (var s in Ctx.Sessions.All.Where(s => net.Contains(s.Ip))) _ = s.KickAsync("login.banned");
        Message = $"{key} BANNED.";
        return RedirectToPage();
    }

    public IActionResult OnPostDelete(long id)
    {
        var b = Ctx.Admin.Bans(0, all: true).FirstOrDefault(x => x.Id == id);
        Ctx.Bans.Remove(id);
        Audit("LIFT BAN", b?.IpOrCidr);
        return RedirectToPage();
    }
}
