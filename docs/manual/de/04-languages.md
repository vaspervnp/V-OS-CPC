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
- **Nur die Tastatur:** CONTROL+SHIFT schaltet die Tastatur zwischen der englischen und der des Pakets um. Die Menüleiste zeigt rechts, welche aktiv ist (EN, ΕΛ, FR, …).

Die Zeichen `@ # [ ] { } \ |` gibt es auf den Tastaturen der Pakete nicht, weil der CPC keine AltGr-Taste hat. Tippe sie mit der englischen Tastatur.

## Die Texte der Programme

Programme haben ihre eigenen Texte in **zwei Sprachen**: Englisch und, optional, einer weiteren (heute Griechisch). Ein Programm erscheint nur dann in seiner zweiten Sprache, wenn das Paket in dieser Sprache ist. Sonst erscheint es auf Englisch. Mit Französisch erscheint Studio also auf Englisch.

## Eine neue Sprache erstellen

Die Quellen der Sprachen liegen in `lang/<code>/`:

- `messages.txt`: die Systemtexte. Die Grundliste legt `lang/en/messages.txt` fest, und was in einem Paket fehlt, erscheint auf Englisch.
- `keymap.txt`: die Tasten, die sich von der englischen Tastatur unterscheiden.
- `pack.txt`: der Code, der Name, der Zeichensatz und die Schrift.

`tools/mklng.py` macht daraus eine `.LNG`, und das Makefile legt sie auf die Diskette. Die lateinischen Pakete teilen sich die Schrift `lang/latin1/font.txt`.
