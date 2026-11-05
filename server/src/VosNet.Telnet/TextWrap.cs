using System.Text;

namespace VosNet.Telnet;

/// <summary>Word wrapping to a terminal's width.</summary>
public static class TextWrap
{
    /// <summary>The rows <paramref name="text"/> takes at
    /// <paramref name="width"/> columns: a row for each line of it, broken
    /// at spaces, a word longer than a row cut. No row is longer than the
    /// width.</summary>
    public static List<string> Wrap(string text, int width)
    {
        var rows = new List<string>();
        foreach (var raw in text.Replace("\r\n", "\n").Split('\n'))
        {
            var line = raw.Replace('\t', ' ').TrimEnd();
            if (line.Length <= width) { rows.Add(line); continue; }
            var indent = line.Length - line.TrimStart().Length;
            if (indent > width / 2) indent = 0;
            var row = new StringBuilder(line[..indent]);
            int rowStart = indent;
            foreach (var word in line[indent..].Split(' '))
            {
                var w = word;
                if (row.Length > rowStart && row.Length + 1 + w.Length > width)
                {
                    rows.Add(row.ToString().TrimEnd());
                    row.Clear().Append(' ', indent);
                }
                else if (row.Length > rowStart) row.Append(' ');
                while (row.Length + w.Length > width)
                {
                    int room = width - row.Length;
                    row.Append(w[..room]);
                    rows.Add(row.ToString());
                    row.Clear().Append(' ', indent);
                    w = w[room..];
                }
                row.Append(w);
            }
            rows.Add(row.ToString().TrimEnd());
        }
        return rows;
    }

    /// <summary><paramref name="s"/> cut or padded to exactly <paramref name="n"/>.</summary>
    public static string Fit(string s, int n) => s.Length > n ? s[..n] : s.PadRight(n);
}
