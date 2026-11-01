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
- **Keyboard only:** CONTROL+SHIFT switches the keyboard. The menu bar shows on the right which one is active (EN, ΕΛ, FR, …). With Setup's KEYBOARDS at EN + PACK it goes between the English one and the pack's; at ALL SIX it goes through all of them: EN, the pack's, the other four, and EN again. So you can type French with the French keyboard while the system is in Greek. Every pack holds the keyboards of all of them.

The symbols `@ # [ ] { } \ |` are not on the packs' keyboards, because the CPC has no AltGr. Type them with the English keyboard.

## Program texts

Programs have their own texts in **two languages**: English and, optionally, one more (today, Greek). A program appears in its second language only when the pack is in that language. Otherwise it appears in English. So, with French, Studio appears in English. Studio's programs, though, can have their texts in all six languages ([chapter 5](05-studio.md)): CALC is called "CALCULATRICE" in French.

## One alphabet for all

All languages write with the same character set, the **V-OS set**, and every pack has all its letters. So a text or a database can mix Greek, French, German, Spanish and Italian, and they show right whatever language is active: in Setup, LANGUAGE shows ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL with their own letters.

Codes 128 to 255 are the Greek ones of ISO 8859-7, as they were, and the codes it leaves free hold À Á Â Ä Ç È É Ê Ë Ì Í Î Ï Ñ Ò Ó Ô Ö Ù Ú Û Ü, their small letters, ß and ¡ ¿. The ´ is written as the Greek tonos (΄) and µ as μ. There is no ÿ, Œ or œ. The table is in `tools/voscs.py`. A Greek text file from a PC (ISO 8859-7) reads as it is; a French or German one in Latin-1 needs converting.

With the English keyboard, SHIFT and `^` gives £.

Files in **UTF-8**, from a PC or the web, are opened by NOTEPAD and READER, which turn them into the V-OS set; what it has not (Chinese, say) becomes `?`. On the PC, `tools/voscv.py` converts files to and from V-OS (UTF-8, Latin-1 and others) and says what a file is (`check`).

## Making a new language

The language sources are in `lang/<code>/`:

- `messages.txt`: the system texts. The base list is defined by `lang/en/messages.txt`, and anything missing from a pack appears in English.
- `keymap.txt`: the keys that differ from the English keyboard.
- `pack.txt`: the code, the name, the character set and the font.

`tools/mklng.py` turns them into a `.LNG`, and the Makefile puts it on the disk. All packs have the same font, `lang/vos/font.txt`, and `charset vos`.
