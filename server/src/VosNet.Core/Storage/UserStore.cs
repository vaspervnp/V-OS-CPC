using Dapper;

namespace VosNet.Core.Storage;

public sealed class UserStore(Db db)
{
    public UserRow? ByName(string name)
    {
        using var c = db.Open();
        return c.QuerySingleOrDefault<UserRow>("SELECT * FROM users WHERE name_upper = @n", new { n = name.ToUpperInvariant() });
    }

    public UserRow? ById(long id)
    {
        using var c = db.Open();
        return c.QuerySingleOrDefault<UserRow>("SELECT * FROM users WHERE id = @id", new { id });
    }

    public long Insert(UserRow u)
    {
        using var c = db.Open();
        return c.ExecuteScalar<long>("""
            INSERT INTO users(name, name_upper, email, pw_hash, role, created, created_ip, must_change_pw)
            VALUES (@Name, @NameUpper, @Email, @PwHash, @Role, @Created, @CreatedIp, @MustChangePw);
            SELECT last_insert_rowid();
            """, u);
    }

    public int RegisteredFrom(string ip, long since)
    {
        using var c = db.Open();
        return c.ExecuteScalar<int>("SELECT COUNT(*) FROM users WHERE created_ip = @ip AND created >= @since", new { ip, since });
    }

    public void SetFailed(long id, long failed, long? lockedUntil)
    {
        using var c = db.Open();
        c.Execute("UPDATE users SET failed = @failed, locked_until = @lockedUntil WHERE id = @id", new { id, failed, lockedUntil });
    }

    public void LoggedIn(long id, long now, string ip, string via)
    {
        using var c = db.Open();
        c.Execute("""
            UPDATE users SET failed = 0, locked_until = NULL, last_seen = @now WHERE id = @id;
            INSERT INTO logins(at, user_id, ip, via) VALUES (@now, @id, @ip, @via);
            """, new { id, now, ip, via });
    }

    public void SetPassword(long id, string hash, bool mustChange)
    {
        using var c = db.Open();
        c.Execute("UPDATE users SET pw_hash = @hash, must_change_pw = @m WHERE id = @id", new { id, hash, m = mustChange ? 1 : 0 });
    }

    public void SetRole(long id, Role role)
    {
        using var c = db.Open();
        c.Execute("UPDATE users SET role = @r WHERE id = @id", new { id, r = Roles.Name(role) });
    }

    public void Delete(long id)
    {
        using var c = db.Open();
        c.Execute("DELETE FROM users WHERE id = @id", new { id });
    }

    public List<UserRow> Search(string? q, int limit = 100)
    {
        using var c = db.Open();
        return c.Query<UserRow>("""
            SELECT * FROM users WHERE @q IS NULL OR name_upper LIKE @q OR email LIKE @q
            ORDER BY name_upper LIMIT @limit
            """, new { q = string.IsNullOrWhiteSpace(q) ? null : "%" + q.Trim().ToUpperInvariant() + "%", limit }).ToList();
    }
}
