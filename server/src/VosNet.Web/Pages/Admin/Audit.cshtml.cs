using VosNet.Core;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

public sealed class AuditModel(ServerContext ctx) : AdminPage(ctx)
{
    public List<AuditRow> Log { get; private set; } = [];

    public void OnGet() => Log = Ctx.Admin.AuditLog();
}
