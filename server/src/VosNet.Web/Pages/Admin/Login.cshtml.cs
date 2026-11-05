using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using VosNet.Core;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

/// <summary>The same account and the same limits as telnet (5 wrong lock
/// it for 15 minutes, 20 an hour ban the IP).</summary>
public sealed class LoginModel(ServerContext ctx) : PageModel
{
    [BindProperty] public string? Name { get; set; }
    [BindProperty] public string? Password { get; set; }
    public string? Error { get; set; }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync(string? returnUrl)
    {
        var ip = HttpContext.Connection.RemoteIpAddress ?? System.Net.IPAddress.Loopback;
        var r = ctx.Accounts.Login(Name ?? "", Password ?? "", ip, "WEB");
        switch (r.Result)
        {
            case LoginResult.Ok when r.User!.RoleValue >= Role.Admin:
                await HttpContext.SignInAsync(WebSetup.Principal(r.User));
                ctx.Admin.Audit(ctx.Time.Unix(), r.User.Id, r.User.Name, "WEB LOGIN", null, ip.ToString());
                return LocalRedirect(Url.IsLocalUrl(returnUrl) && returnUrl!.StartsWith("/admin", StringComparison.OrdinalIgnoreCase) ? returnUrl : "/admin");
            case LoginResult.Ok:
                Error = "THIS ACCOUNT IS NOT AN ADMINISTRATOR.";
                break;
            case LoginResult.Locked:
                Error = $"THE ACCOUNT IS LOCKED FOR {r.LockedMinutes} MINUTES.";
                break;
            case LoginResult.Banned:
                Error = "THIS ADDRESS IS BANNED.";
                break;
            default:
                Error = "WRONG NAME OR PASSWORD.";
                break;
        }
        Response.StatusCode = 401;
        return Page();
    }
}
