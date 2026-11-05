using System.Text;
using System.Text.RegularExpressions;

namespace VosNet.Core.Services;

/// <summary>A release's markdown as plain text for a terminal.</summary>
public static partial class Markdown
{
    [GeneratedRegex(@"!\[[^\]]*\]\([^)]*\)")] private static partial Regex Image();
    [GeneratedRegex(@"\[([^\]]*)\]\([^)]*\)")] private static partial Regex Link();
    [GeneratedRegex(@"<[^>]+>")] private static partial Regex Html();
    [GeneratedRegex(@"(\*\*|__|`)")] private static partial Regex Marks();
    [GeneratedRegex(@"^\s*[-*+]\s+")] private static partial Regex Bullet();
    [GeneratedRegex(@"^#{1,6}\s*")] private static partial Regex Heading();
    [GeneratedRegex(@"^\s*\|?\s*:?-{3,}")] private static partial Regex TableRule();

    public static string ToText(string md)
    {
        var sb = new StringBuilder();
        bool blank = true;
        foreach (var raw in md.Replace("\r\n", "\n").Split('\n'))
        {
            var line = raw.TrimEnd();
            if (line.StartsWith("```") || TableRule().IsMatch(line)) continue;
            line = Image().Replace(line, "");
            line = Link().Replace(line, "$1");
            line = Html().Replace(line, "");
            bool head = Heading().IsMatch(line);
            line = Heading().Replace(line, "");
            line = Bullet().Replace(line, "- ");
            line = Marks().Replace(line, "");
            if (line.Trim().StartsWith('|')) line = line.Trim().Trim('|').Replace(" | ", "  ").Replace("|", " ");
            if (head) line = line.ToUpperInvariant();
            if (line.Trim().Length == 0)
            {
                if (!blank) sb.Append('\n');
                blank = true;
                continue;
            }
            sb.Append(line).Append('\n');
            blank = false;
        }
        return sb.ToString().TrimEnd();
    }
}
