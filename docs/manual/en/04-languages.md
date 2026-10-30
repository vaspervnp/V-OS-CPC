# 4. Languages

V-OS speaks six languages. English is built in. The other five are **language packs**, files on the disk that bring three things: all the system texts, the keyboard, and the letters (font) of the language.

| Language | File | Keyboard |
|---|---|---|
| English | built in (`ENGLISH.MSG`) | the CPC's English one |
| Ελληνικά | `GREEK.LNG` | Greek, with accents |
| Français | `FRENCH.LNG` | AZERTY, digits with SHIFT, dead keys ^ and ¨ |
| Español | `SPANISH.LNG` | Ñ on the `:` key, dead keys ´ ¨ ` ^, and ¡ ¿ |
| Deutsch | `GERMAN.LNG` | QWERTZ, Ü Ö Ä ß, dead keys ´ and ` |
| Italiano | `ITALIAN.LNG` | è é ò à ù ì on their own keys |

## Switching language

- **Permanently:** in Setup (F4), the LANGUAGE line cycles through all the languages. Each one loads from A: at once, and the whole screen is redrawn in it. Saving (^S) keeps it for the next startup too.
- **Quickly:** CONTROL+L (VIEW > SWITCH LANGUAGE) switches between English and the language of the pack that is loaded.
- **Keyboard only:** CONTROL+SHIFT switches the keyboard between the English one and the pack's. The menu bar shows on the right which one is active (EN, ΕΛ, FR, …).

The symbols `@ # [ ] { } \ |` are not on the packs' keyboards, because the CPC has no AltGr. Type them with the English keyboard.

## Program texts

Programs have their own texts in **two languages**: English and, optionally, one more (today, Greek). A program appears in its second language only when the pack is in that language. Otherwise it appears in English. So, with French, Studio appears in English.

## Making a new language

The language sources are in `lang/<code>/`:

- `messages.txt`: the system texts. The base list is defined by `lang/en/messages.txt`, and anything missing from a pack appears in English.
- `keymap.txt`: the keys that differ from the English keyboard.
- `pack.txt`: the code, the name, the character set and the font.

`tools/mklng.py` turns them into a `.LNG`, and the Makefile puts it on the disk. The Latin packs share the font `lang/latin1/font.txt`.
