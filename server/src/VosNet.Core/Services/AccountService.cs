using System.Net;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using VosNet.Core.Storage;

namespace VosNet.Core.Services;

public enum RegisterError { None, BadName, Reserved, Taken, BadPassword, Mismatch, BadEmail, WrongAnswer, TooMany }
public enum LoginResult { Ok, Wrong, Locked, Banned }
public enum AdminResult { Ok, NotAllowed, NotFound }

public sealed record LoginOutcome(LoginResult Result, UserRow? User, long LockedMinutes = 0);

/// <summary>§3: registration, login with its locks, the roles. The
/// passwords are hashed with ASP.NET Core Identity's PasswordHasher
/// (PBKDF2-HMAC-SHA512, salted).</summary>
public sealed partial class AccountService
{
    public static readonly string[] ReservedNames = ["SYSOP", "ADMIN", "ROOT", "GUEST", "VOS", "SERVER"];
    public const int MinPassword = 8, MaxPassword = 40;
    const long Forever = 253402300799;      // 9999-12-31: locked by an admin

    readonly UserStore _users;
    readonly AdminStore _admin;
    readonly BanList _bans;
    readonly VosNetOptions _o;
    readonly TimeProvider _time;
    readonly PasswordHasher<UserRow> _hasher = new();
    readonly SlidingWindow _ipFailures;
    readonly string _dummyHash;

    public AccountService(UserStore users, AdminStore admin, BanList bans, IOptions<VosNetOptions> o, TimeProvider time)
    {
        _users = users;
        _admin = admin;
        _bans = bans;
        _o = o.Value;
        _time = time;
        _ipFailures = new(TimeSpan.FromHours(1), time);
        _dummyHash = _hasher.HashPassword(new UserRow(), "not a password at all");
    }

    [GeneratedRegex("^[A-Za-z0-9_]{3,12}$")]
    private static partial Regex NameRule();

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex EmailRule();

    public RegisterError CheckName(string name)
    {
        if (!NameRule().IsMatch(name)) return RegisterError.BadName;
        if (ReservedNames.Contains(name.ToUpperInvariant())) return RegisterError.Reserved;
        if (_users.ByName(name) != null) return RegisterError.Taken;
        return RegisterError.None;
    }

    public static bool GoodPassword(string pw) => pw.Length is >= MinPassword and <= MaxPassword;

    public static bool GoodEmail(string email) => email.Length <= 80 && EmailRule().IsMatch(email);

    /// <summary>3 registrations a day from an IP.</summary>
    public bool MayRegister(IPAddress ip) =>
        _users.RegisteredFrom(BanList.Normal(ip).ToString(), _time.Unix() - 86400) < _o.RegistrationsPerDay;

    public static bool Answers(QuestionRow q, string answer)
    {
        var a = answer.Trim().ToUpperInvariant();
        return q.Answer.Split('|').Any(x => x.Trim().ToUpperInvariant() == a);
    }

    public (RegisterError Error, UserRow? User) Register(string name, string password, string? email, IPAddress ip)
    {
        var e = CheckName(name);
        if (e != RegisterError.None) return (e, null);
        if (!GoodPassword(password)) return (RegisterError.BadPassword, null);
        if (!string.IsNullOrEmpty(email) && !GoodEmail(email)) return (RegisterError.BadEmail, null);
        if (!MayRegister(ip)) return (RegisterError.TooMany, null);
        var u = new UserRow
        {
            Name = name, NameUpper = name.ToUpperInvariant(), Email = string.IsNullOrEmpty(email) ? null : email,
            Role = Roles.Name(Role.User), Created = _time.Unix(), CreatedIp = BanList.Normal(ip).ToString(),
        };
        u.PwHash = _hasher.HashPassword(u, password);
        try { u.Id = _users.Insert(u); }
        catch (Microsoft.Data.Sqlite.SqliteException) { return (RegisterError.Taken, null); }   // at the same moment
        return (RegisterError.None, u);
    }

    /// <summary>5 wrong passwords lock the account for 15 minutes; over 20
    /// wrong an hour from an IP ban it.</summary>
    public LoginOutcome Login(string name, string password, IPAddress ip, string via)
    {
        var key = BanList.Normal(ip).ToString();
        if (_bans.Find(ip) != null) return new(LoginResult.Banned, null);
        var u = _users.ByName(name.Trim());
        var now = _time.Unix();
        if (u == null)
        {
            _hasher.VerifyHashedPassword(new UserRow(), _dummyHash, password);   // the same time
            IpFailed(key);
            return new(LoginResult.Wrong, null);
        }
        if (u.LockedUntil is { } until && until > now)
            return new(LoginResult.Locked, u, (until - now + 59) / 60);
        var r = _hasher.VerifyHashedPassword(u, u.PwHash, password);
        if (r == PasswordVerificationResult.Failed)
        {
            var failed = u.Failed + 1;
            if (failed >= _o.LoginFailuresToLock)
                _users.SetFailed(u.Id, 0, now + (long)_o.LockTime.TotalSeconds);
            else
                _users.SetFailed(u.Id, failed, u.LockedUntil);
            IpFailed(key);
            return new(LoginResult.Wrong, null);
        }
        if (r == PasswordVerificationResult.SuccessRehashNeeded)
            _users.SetPassword(u.Id, _hasher.HashPassword(u, password), u.MustChangePw != 0);
        _users.LoggedIn(u.Id, now, key, via);
        return new(LoginResult.Ok, _users.ById(u.Id));
    }

    void IpFailed(string key)
    {
        if (_ipFailures.Hit(key) > _o.IpFailuresPerHour)
        {
            _ipFailures.Clear(key);
            _bans.Add(key, _o.IpFailureBan, "LOGIN FAILURES", "SERVER");
        }
    }

    public void ChangePassword(long userId, string password)
    {
        var u = _users.ById(userId) ?? throw new InvalidOperationException("no such user");
        _users.SetPassword(userId, _hasher.HashPassword(u, password), false);
    }

    UserRow? Target(long id) => _users.ById(id);

    /// <summary>Who may change whose role (§3): ADMIN and OWNER give USER
    /// and MODERATOR; only the OWNER gives or takes ADMIN; nobody gives or
    /// takes OWNER here (only <see cref="SetOwner"/>, from the server's
    /// command line).</summary>
    public static bool MaySetRole(Role actor, Role target, Role role)
    {
        if (actor < Role.Admin) return false;
        if (target == Role.Owner || role == Role.Owner) return false;
        if ((target == Role.Admin || role == Role.Admin) && actor != Role.Owner) return false;
        return true;
    }

    /// <summary>May <paramref name="actor"/> manage (lock, reset, delete) a user of role <paramref name="target"/>?</summary>
    public static bool MayManage(Role actor, Role target) =>
        actor >= Role.Admin && target != Role.Owner && (target < Role.Admin || actor == Role.Owner);

    public AdminResult SetRole(UserRow actor, long targetId, Role role)
    {
        var t = Target(targetId);
        if (t == null) return AdminResult.NotFound;
        if (t.Id == actor.Id || !MaySetRole(actor.RoleValue, t.RoleValue, role)) return AdminResult.NotAllowed;
        _users.SetRole(t.Id, role);
        _admin.Audit(_time.Unix(), actor.Id, actor.Name, "ROLE", t.Name, $"{t.Role} -> {Roles.Name(role)}");
        return AdminResult.Ok;
    }

    public AdminResult Lock(UserRow actor, long targetId, bool locked)
    {
        var t = Target(targetId);
        if (t == null) return AdminResult.NotFound;
        if (t.Id == actor.Id || !MayManage(actor.RoleValue, t.RoleValue)) return AdminResult.NotAllowed;
        _users.SetFailed(t.Id, 0, locked ? Forever : null);
        _admin.Audit(_time.Unix(), actor.Id, actor.Name, locked ? "LOCK" : "UNLOCK", t.Name);
        return AdminResult.Ok;
    }

    /// <summary>A temporary password, shown once; it must be changed at the
    /// next login.</summary>
    public (AdminResult, string?) TemporaryPassword(UserRow actor, long targetId)
    {
        var t = Target(targetId);
        if (t == null) return (AdminResult.NotFound, null);
        if (t.Id == actor.Id || !MayManage(actor.RoleValue, t.RoleValue)) return (AdminResult.NotAllowed, null);
        const string letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var pw = RandomNumberGenerator.GetString(letters, 10);
        _users.SetPassword(t.Id, _hasher.HashPassword(t, pw), true);
        _users.SetFailed(t.Id, 0, null);
        _admin.Audit(_time.Unix(), actor.Id, actor.Name, "TEMP PASSWORD", t.Name);
        return (AdminResult.Ok, pw);
    }

    public AdminResult Delete(UserRow actor, long targetId)
    {
        var t = Target(targetId);
        if (t == null) return AdminResult.NotFound;
        if (t.Id == actor.Id || !MayManage(actor.RoleValue, t.RoleValue)) return AdminResult.NotAllowed;
        _users.Delete(t.Id);
        _admin.Audit(_time.Unix(), actor.Id, actor.Name, "DELETE USER", t.Name);
        return AdminResult.Ok;
    }

    /// <summary>The command line's set-owner: a registered user becomes OWNER.</summary>
    public bool SetOwner(string name)
    {
        var u = _users.ByName(name);
        if (u == null) return false;
        _users.SetRole(u.Id, Role.Owner);
        _admin.Audit(_time.Unix(), null, "SERVER", "SET OWNER", u.Name);
        return true;
    }
}
