# 4. Sprachen

V-OS spricht sechs Sprachen. Englisch ist eingebaut. Die anderen fünf sind **Sprachpakete**, Dateien auf der Diskette, die drei Dinge mitbringen: alle Systemtexte, die Tastatur und die Buchstaben (Schrift) der Sprache.

| Sprache | Datei | Tastatur |
|---|---|---|
| English | eingebaut (`ENGLISH.MSG`) | die englische des CPC |
| Ελληνικά | `GREEK.LNG` | Griechisch, mit Akzenten |
| Français | `FRENCH.LNG` | AZERTY, Ziffern mit SHIFT, Tottasten ^ und ¨ |
| Español | `SPANISH.LNG` | Ñ auf der Taste `:`, Tottasten ´ ¨ ` ^, und ¡ ¿ |
| Deutsch | `GERMAN.LNG` | QWERTZ, Ü Ö Ä ß, Tottasten ´ und ` |
| Italiano | `ITALIAN.LNG` | è é ò à ù ì auf eigenen Tasten |

## Die Sprache wechseln

- **Dauerhaft:** In den Optionen (F4) geht die Zeile SPRACHE der Reihe nach durch alle Sprachen. Jede wird sofort von A: geladen, und der ganze Bildschirm wird in ihr neu gezeichnet. Speichern (^S) behält sie auch für den nächsten Start.
- **Schnell:** CONTROL+L (ANSICHT > SPRACHE WECHSELN) schaltet zwischen Englisch und der Sprache des geladenen Pakets um.
- **Nur die Tastatur:** CONTROL+SHIFT wechselt die Tastatur. Die Menüleiste zeigt rechts, welche aktiv ist (EN, ΕΛ, FR, …). Mit TASTATUREN in Setup auf EN + SPRACHE geht es zwischen der englischen und der des Pakets; auf ALLE SECHS durch alle: EN, die des Pakets, die vier anderen und wieder EN. So kannst du Französisch mit der französischen Tastatur tippen, während das System auf Griechisch ist. Jedes Paket enthält die Tastaturen aller.

Die Zeichen `@ # [ ] { } \ |` gibt es auf den Tastaturen der Pakete nicht, weil der CPC keine AltGr-Taste hat. Tippe sie mit der englischen Tastatur.

## Die Texte der Programme

Programme haben ihre eigenen Texte in **zwei Sprachen**: Englisch und, optional, einer weiteren (heute Griechisch). Ein Programm erscheint nur dann in seiner zweiten Sprache, wenn das Paket in dieser Sprache ist. Sonst erscheint es auf Englisch. Mit Französisch erscheint Studio also auf Englisch.

## Ein Alphabet für alle

Alle Sprachen schreiben mit demselben Zeichensatz, dem **V-OS-Zeichensatz**, und jedes Paket hat alle seine Buchstaben. So kann ein Text oder eine Datenbank Griechisch, Französisch, Deutsch, Spanisch und Italienisch mischen, und alles erscheint richtig, welche Sprache auch aktiv ist: in Setup zeigt LANGUAGE ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL mit ihren eigenen Buchstaben.

Die Codes 128 bis 255 sind die griechischen von ISO 8859-7, unverändert, und die Codes, die es frei lässt, tragen À Á Â Ä Ç È É Ê Ë Ì Í Î Ï Ñ Ò Ó Ô Ö Ù Ú Û Ü, ihre Kleinbuchstaben, ß und ¡ ¿. Der Akzent ´ wird als griechischer Tonos (΄) geschrieben und µ als μ. Es gibt kein ÿ, Œ oder œ. Die Tabelle steht in `tools/voscs.py`. Eine griechische Textdatei vom PC (ISO 8859-7) wird so gelesen, wie sie ist; eine französische oder deutsche in Latin-1 muss umgewandelt werden.

Mit der englischen Tastatur gibt SHIFT und `^` das £.

Dateien in **UTF-8**, vom PC oder aus dem Web, öffnen NOTEPAD und READER und wandeln sie in den V-OS-Zeichensatz um; was er nicht hat (etwa Chinesisch), wird `?`. Auf dem PC wandelt `tools/voscv.py` Dateien in V-OS und zurück um (UTF-8, Latin-1 und andere) und sagt, was eine Datei ist (`check`).

## Eine neue Sprache erstellen

Die Quellen der Sprachen liegen in `lang/<code>/`:

- `messages.txt`: die Systemtexte. Die Grundliste legt `lang/en/messages.txt` fest, und was in einem Paket fehlt, erscheint auf Englisch.
- `keymap.txt`: die Tasten, die sich von der englischen Tastatur unterscheiden.
- `pack.txt`: der Code, der Name, der Zeichensatz und die Schrift.

`tools/mklng.py` macht daraus eine `.LNG`, und das Makefile legt sie auf die Diskette. Alle Pakete haben dieselbe Schrift, `lang/vos/font.txt`, und `charset vos`.
