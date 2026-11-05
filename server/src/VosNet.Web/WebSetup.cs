using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using VosNet.Core.Storage;

namespace VosNet.Web;

/// <summary>The web (§4): /admin for ADMIN and OWNER with the telnet
/// account, a cookie HttpOnly, Secure, SameSite=Strict, antiforgery on
/// every form (Razor Pages' own); / the public page.</summary>
public static class WebSetup
{
    public const string Policy = "Admin";
    public const string UserIdClaim = "vosnet:uid";

    public static IServiceCollection AddVosNetWeb(this IServiceCollection services)
    {
        services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
            .AddCookie(c =>
            {
                c.Cookie.Name = "vosnet.admin";
                c.Cookie.HttpOnly = true;
                c.Cookie.SecurePolicy = CookieSecurePolicy.Always;
                c.Cookie.SameSite = SameSiteMode.Strict;
                c.LoginPath = "/admin/login";
                c.LogoutPath = "/admin/logout";
                c.AccessDeniedPath = "/admin/login";
                c.ExpireTimeSpan = TimeSpan.FromHours(8);
                c.SlidingExpiration = true;
                // each request: still there, still ADMIN or OWNER, not locked
                c.Events.OnValidatePrincipal = async ctx =>
                {
                    var users = ctx.HttpContext.RequestServices.GetRequiredService<UserStore>();
                    var id = long.TryParse(ctx.Principal?.FindFirstValue(UserIdClaim), out var i) ? i : 0;
                    var u = users.ById(id);
                    var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
                    if (u == null || u.RoleValue < Role.Admin || u.LockedUntil > now
                        || ctx.Principal!.FindFirstValue(ClaimTypes.Role) != u.Role)
                    {
                        ctx.RejectPrincipal();
                        await ctx.HttpContext.SignOutAsync();
                    }
                };
            });
        services.AddAuthorizationBuilder()
            .AddPolicy(Policy, p => p.RequireAuthenticatedUser().RequireRole(Roles.Name(Role.Admin), Roles.Name(Role.Owner)));
        services.AddAntiforgery(a =>
        {
            a.Cookie.Name = "vosnet.af";
            a.Cookie.SecurePolicy = CookieSecurePolicy.Always;
            a.Cookie.SameSite = SameSiteMode.Strict;
        });
        services.AddRazorPages(p =>
        {
            p.Conventions.AuthorizeFolder("/Admin", Policy);
            p.Conventions.AllowAnonymousToPage("/Admin/Login");
        });
        return services;
    }

    public static WebApplication UseVosNetWeb(this WebApplication app)
    {
        app.Use(async (ctx, next) =>
        {
            ctx.Response.Headers.XContentTypeOptions = "nosniff";
            ctx.Response.Headers.XFrameOptions = "DENY";
            ctx.Response.Headers["Referrer-Policy"] = "same-origin";
            ctx.Response.Headers.ContentSecurityPolicy = "default-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'";
            await next();
        });
        app.UseAuthentication();
        app.UseAuthorization();
        app.MapRazorPages();
        return app;
    }

    public static ClaimsPrincipal Principal(UserRow u) => new(new ClaimsIdentity(
    [
        new Claim(ClaimTypes.Name, u.Name),
        new Claim(UserIdClaim, u.Id.ToString()),
        new Claim(ClaimTypes.Role, u.Role),
    ], CookieAuthenticationDefaults.AuthenticationScheme));
}
