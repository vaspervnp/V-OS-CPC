using System.Text.Json;

namespace VosNet.Core;

/// <summary>The texts of the screens, a file for each language
/// (texts/en.json, el.json...): "key": "text" with {0}, {1}... A key
/// missing in a language is taken from English.</summary>
public sealed class Texts
{
    readonly Dictionary<string, Dictionary<string, string>> _langs = new();

    public Texts(string dir)
    {
        foreach (var f in Directory.GetFiles(dir, "*.json"))
        {
            var d = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(f))!;
            _langs[Path.GetFileNameWithoutExtension(f)] = d;
        }
        if (!_langs.ContainsKey("en")) throw new InvalidOperationException($"No en.json in {dir}");
    }

    /// <summary>The languages, English first, then by their file's order
    /// of "order" (el, fr, es, de, it as V-OS).</summary>
    public IReadOnlyList<string> Languages =>
        _langs.Keys.OrderBy(k => int.TryParse(Get(k, "order"), out var o) ? o : 99).ThenBy(k => k).ToList();

    public string Get(string lang, string key)
    {
        if (_langs.TryGetValue(lang, out var d) && d.TryGetValue(key, out var s)) return s;
        return _langs["en"].TryGetValue(key, out var e) ? e : key;
    }

    public string Get(string lang, string key, params object?[] args) => string.Format(Get(lang, key), args);

    public bool Has(string lang) => _langs.ContainsKey(lang);
}
