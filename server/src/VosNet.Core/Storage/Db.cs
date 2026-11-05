using System.Reflection;
using Dapper;
using Microsoft.Data.Sqlite;

namespace VosNet.Core.Storage;

/// <summary>The SQLite database (WAL). The schema's changes are the
/// numbered files Migrations/NNN_*.sql, applied at the start in their
/// order; user_version says how far it is.</summary>
public sealed class Db
{
    readonly string _cs;

    static Db() => DefaultTypeMap.MatchNamesWithUnderscores = true;

    public Db(string path)
    {
        var dir = Path.GetDirectoryName(Path.GetFullPath(path));
        if (dir != null) Directory.CreateDirectory(dir);
        _cs = new SqliteConnectionStringBuilder { DataSource = path, Pooling = true }.ToString();
        Path_ = path;
    }

    public string Path_ { get; }

    public SqliteConnection Open()
    {
        var c = new SqliteConnection(_cs);
        c.Open();
        c.Execute("PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;");
        return c;
    }

    public void Migrate()
    {
        using var c = Open();
        c.Execute("PRAGMA journal_mode = WAL;");
        var version = c.ExecuteScalar<long>("PRAGMA user_version;");
        var asm = Assembly.GetExecutingAssembly();
        var scripts = asm.GetManifestResourceNames()
            .Where(n => n.Contains(".Migrations.") && n.EndsWith(".sql"))
            .Select(n => (Name: n, Number: int.Parse(n.Split(".Migrations.")[1][..3])))
            .OrderBy(s => s.Number);
        foreach (var (name, number) in scripts)
        {
            if (number <= version) continue;
            using var s = new StreamReader(asm.GetManifestResourceStream(name)!);
            using var tx = c.BeginTransaction();
            c.Execute(s.ReadToEnd(), transaction: tx);
            c.Execute($"PRAGMA user_version = {number};", transaction: tx);
            tx.Commit();
        }
    }
}
