using System.Net;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;
using VosNet.Core;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Tests;

/// <summary>The accounts on a database of their own, the time a fake one.</summary>
public sealed class AccountFixture : IDisposable
{
    public readonly string Path_ = Path.Combine(Path.GetTempPath(), $"vosnet-acc-{Guid.NewGuid():N}.db");
    public readonly FakeTimeProvider Time = new(new DateTimeOffset(2026, 11, 5, 12, 0, 0, TimeSpan.Zero));
    public readonly UserStore Users;
    public readonly AdminStore Admin;
    public readonly BanList Bans;
    public readonly AccountService Accounts;
    public readonly IOptions<VosNetOptions> Options = Microsoft.Extensions.Options.Options.Create(new VosNetOptions());

    public AccountFixture()
    {
        var db = new Db(Path_);
        db.Migrate();
        Users = new UserStore(db);
        Admin = new AdminStore(db);
        Bans = new BanList(Admin, Time);
        Accounts = new AccountService(Users, Admin, Bans, Options, Time);
    }

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        foreach (var f in new[] { Path_, Path_ + "-wal", Path_ + "-shm" }) File.Delete(f);
    }
}

public class AccountTests
{
    static readonly IPAddress Ip = IPAddress.Parse("192.0.2.1");

    [Theory]
    [InlineData("AB", RegisterError.BadName)]
    [InlineData("ABCDEFGHIJKLM", RegisterError.BadName)]
    [InlineData("ΒΑΣΙΛΗΣ", RegisterError.BadName)]
    [InlineData("A-B", RegisterError.BadName)]
    [InlineData("sysop", RegisterError.Reserved)]
    [InlineData("Guest", RegisterError.Reserved)]
    [InlineData("VOS", RegisterError.Reserved)]
    [InlineData("Vasilhs_1", RegisterError.None)]
    public void Names(string name, RegisterError e)
    {
        using var f = new AccountFixture();
        Assert.Equal(e, f.Accounts.CheckName(name));
    }

    [Fact]
    public void ANameOnceWhateverItsCase()
    {
        using var f = new AccountFixture();
        Assert.Equal(RegisterError.None, f.Accounts.Register("Vasilhs", "12345678", null, Ip).Error);
        Assert.Equal(RegisterError.Taken, f.Accounts.Register("VASILHS", "12345678", null, IPAddress.Parse("192.0.2.2")).Error);
        Assert.Equal(RegisterError.Taken, f.Accounts.CheckName("vasilhs"));
    }

    [Theory]
    [InlineData("1234567", RegisterError.BadPassword)]
    [InlineData("12345678", RegisterError.None)]
    [InlineData("1234567890123456789012345678901234567890", RegisterError.None)]
    [InlineData("12345678901234567890123456789012345678901", RegisterError.BadPassword)]
    public void Passwords(string pw, RegisterError e)
    {
        using var f = new AccountFixture();
        Assert.Equal(e, f.Accounts.Register("USER1", pw, null, Ip).Error);
    }

    [Fact]
    public void ThreeRegistrationsADayFromAnIp()
    {
        using var f = new AccountFixture();
        for (int i = 0; i < 3; i++) Assert.Equal(RegisterError.None, f.Accounts.Register($"USER{i}", "12345678", null, Ip).Error);
        Assert.Equal(RegisterError.TooMany, f.Accounts.Register("USER9", "12345678", null, Ip).Error);
        Assert.Equal(RegisterError.None, f.Accounts.Register("OTHER", "12345678", null, IPAddress.Parse("192.0.2.7")).Error);
        f.Time.Advance(TimeSpan.FromHours(25));
        Assert.Equal(RegisterError.None, f.Accounts.Register("USER9", "12345678", null, Ip).Error);
    }

    [Fact]
    public void EmailOptionalButValid()
    {
        using var f = new AccountFixture();
        Assert.Equal(RegisterError.BadEmail, f.Accounts.Register("USER1", "12345678", "nope", Ip).Error);
        Assert.Equal(RegisterError.None, f.Accounts.Register("USER1", "12345678", "a@b.gr", Ip).Error);
    }

    [Fact]
    public void FiveWrongLockFor15Minutes()
    {
        using var f = new AccountFixture();
        f.Accounts.Register("USER1", "12345678", null, Ip);
        for (int i = 0; i < 5; i++) Assert.Equal(LoginResult.Wrong, f.Accounts.Login("USER1", "wrong-one", Ip, "V-OS").Result);
        var r = f.Accounts.Login("user1", "12345678", Ip, "V-OS");
        Assert.Equal(LoginResult.Locked, r.Result);
        Assert.Equal(15, r.LockedMinutes);
        f.Time.Advance(TimeSpan.FromMinutes(15));
        Assert.Equal(LoginResult.Ok, f.Accounts.Login("user1", "12345678", Ip, "V-OS").Result);
    }

    [Fact]
    public void Over20WrongAnHourBanTheIp()
    {
        using var f = new AccountFixture();
        for (int i = 0; i < 20; i++) f.Accounts.Login($"NOBODY{i}", "x", Ip, "V-OS");
        Assert.Null(f.Bans.Find(Ip));
        f.Accounts.Login("NOBODY", "x", Ip, "V-OS");
        Assert.Equal("SERVER", f.Bans.Find(Ip)?.By);
        Assert.Equal(LoginResult.Banned, f.Accounts.Login("NOBODY", "x", Ip, "V-OS").Result);
    }

    [Fact]
    public void TheRoles()
    {
        Assert.True(AccountService.MaySetRole(Role.Admin, Role.User, Role.Moderator));
        Assert.False(AccountService.MaySetRole(Role.Admin, Role.User, Role.Admin));      // the ADMIN does not give ADMIN
        Assert.False(AccountService.MaySetRole(Role.Admin, Role.Admin, Role.User));
        Assert.True(AccountService.MaySetRole(Role.Owner, Role.User, Role.Admin));
        Assert.True(AccountService.MaySetRole(Role.Owner, Role.Admin, Role.User));
        Assert.False(AccountService.MaySetRole(Role.Owner, Role.User, Role.Owner));      // OWNER only from the server
        Assert.False(AccountService.MaySetRole(Role.Owner, Role.Owner, Role.User));
        Assert.False(AccountService.MaySetRole(Role.Moderator, Role.User, Role.Moderator));
    }

    [Fact]
    public void SetOwnerAndTheAudit()
    {
        using var f = new AccountFixture();
        var (_, owner) = f.Accounts.Register("VASILHS", "12345678", null, Ip);
        var (_, admin) = f.Accounts.Register("ANNA", "12345678", null, IPAddress.Parse("192.0.2.3"));
        var (_, user) = f.Accounts.Register("NIKOS", "12345678", null, IPAddress.Parse("192.0.2.4"));
        Assert.False(f.Accounts.SetOwner("NOBODY"));
        Assert.True(f.Accounts.SetOwner("vasilhs"));
        var o = f.Users.ById(owner!.Id)!;
        Assert.Equal(Role.Owner, o.RoleValue);
        Assert.Equal(AdminResult.Ok, f.Accounts.SetRole(o, admin!.Id, Role.Admin));
        var a = f.Users.ById(admin.Id)!;
        Assert.Equal(AdminResult.NotAllowed, f.Accounts.SetRole(a, user!.Id, Role.Admin));
        Assert.Equal(AdminResult.Ok, f.Accounts.SetRole(a, user.Id, Role.Moderator));
        Assert.Equal(AdminResult.NotAllowed, f.Accounts.SetRole(a, o.Id, Role.User));
        Assert.Equal(AdminResult.NotAllowed, f.Accounts.Delete(a, o.Id));
        var log = f.Admin.AuditLog();
        Assert.Contains(log, x => x.Action == "SET OWNER" && x.Target == "VASILHS");
        Assert.Contains(log, x => x.Action == "ROLE" && x.Target == "NIKOS" && x.Actor == "ANNA");
    }

    [Fact]
    public void ATemporaryPasswordMustBeChanged()
    {
        using var f = new AccountFixture();
        f.Accounts.Register("VASILHS", "12345678", null, Ip);
        f.Accounts.SetOwner("VASILHS");
        var (_, u) = f.Accounts.Register("NIKOS", "12345678", null, IPAddress.Parse("192.0.2.4"));
        var (r, pw) = f.Accounts.TemporaryPassword(f.Users.ByName("VASILHS")!, u!.Id);
        Assert.Equal(AdminResult.Ok, r);
        var login = f.Accounts.Login("NIKOS", pw!, Ip, "V-OS");
        Assert.Equal(LoginResult.Ok, login.Result);
        Assert.Equal(1, login.User!.MustChangePw);
        f.Accounts.ChangePassword(u.Id, "a new password");
        Assert.Equal(0, f.Accounts.Login("NIKOS", "a new password", Ip, "V-OS").User!.MustChangePw);
    }
}

public class LimitTests
{
    [Fact]
    public void ConnectionsFromAnIp()
    {
        using var f = new AccountFixture();
        var l = new ConnectionLimiter(f.Options, f.Bans, f.Time);
        var ip = IPAddress.Parse("198.51.100.1");
        for (int i = 0; i < 4; i++) Assert.Equal(Admission.Ok, l.TryAdmit(ip));
        Assert.Equal(Admission.TooManyFromIp, l.TryAdmit(ip));
        Assert.Equal(Admission.Ok, l.TryAdmit(IPAddress.Parse("198.51.100.2")));
        for (int i = 0; i < 4; i++) l.Release(ip, true);
        // 10 new a minute: 5 so far
        for (int i = 0; i < 4; i++) { Assert.Equal(Admission.Ok, l.TryAdmit(ip)); l.Release(ip, true); }
        Assert.Equal(Admission.Ok, l.TryAdmit(ip));
        l.Release(ip, true);
        Assert.Equal(Admission.TooFast, l.TryAdmit(ip));
        f.Time.Advance(TimeSpan.FromMinutes(1));
        Assert.Equal(Admission.Ok, l.TryAdmit(ip));
    }

    [Fact]
    public void TwoHundredInAll()
    {
        using var f = new AccountFixture();
        var l = new ConnectionLimiter(f.Options, f.Bans, f.Time);
        for (int i = 0; i < 200; i++) Assert.Equal(Admission.Ok, l.TryAdmit(IPAddress.Parse($"203.0.{i / 4}.{i % 4 + 1}")));
        Assert.Equal(Admission.Full, l.TryAdmit(IPAddress.Parse("203.0.113.200")));
    }

    [Fact]
    public void RobotsAreBannedForADay()
    {
        using var f = new AccountFixture();
        var l = new ConnectionLimiter(f.Options, f.Bans, f.Time);
        var ip = IPAddress.Parse("198.51.100.9");
        for (int i = 0; i < 21; i++)
        {
            Assert.Equal(Admission.Ok, l.TryAdmit(ip));
            l.Release(ip, reachedMenu: false);
            f.Time.Advance(TimeSpan.FromSeconds(10));
        }
        Assert.Equal(Admission.Banned, l.TryAdmit(ip));
        f.Time.Advance(TimeSpan.FromHours(24));
        Assert.Equal(Admission.Ok, l.TryAdmit(ip));
    }

    [Fact]
    public void BansByCidr()
    {
        using var f = new AccountFixture();
        f.Bans.Add("10.1.0.0/16", null, "test", "ADMIN");
        Assert.NotNull(f.Bans.Find(IPAddress.Parse("10.1.200.3")));
        Assert.NotNull(f.Bans.Find(IPAddress.Parse("::ffff:10.1.2.3")));
        Assert.Null(f.Bans.Find(IPAddress.Parse("10.2.0.1")));
    }

    [Fact]
    public void ChatFiveLinesIn10Seconds()
    {
        var time = new FakeTimeProvider();
        var w = new SlidingWindow(TimeSpan.FromSeconds(10), time);
        for (int i = 1; i <= 5; i++) Assert.Equal(i, w.Hit("A"));
        Assert.Equal(6, w.Hit("A"));
        time.Advance(TimeSpan.FromSeconds(10));
        Assert.Equal(1, w.Hit("A"));
    }
}
