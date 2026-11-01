# Das V-OS-SDK: Programme in Assembler

Mit diesem SDK schreibst du deine eigenen Programme in Z80-Assembler. Sie laufen in V-OS wie DEMO oder CLOCK: Sie erscheinen in den Ansichten Programme, Schreibtisch und Commander, und sie haben ihr eigenes Menü, Schaltflächen, Dialoge, Ton und Dateien. Sie laufen auch neben anderen Programmen.

## Schnellstart

```bash
make new-app NAME=hello
```

Das legt den Ordner `myapps/hello/` aus `sdk/template/` an. Er enthält drei Dateien:

- `hello.asm`: das Programm. Die Pfeile bewegen ein Kästchen, es gibt eine Schaltfläche BEEP, einen Sekundenzähler und ein eigenes Menü (ABOUT, BACK) neben ANSICHT und HILFE.
- `texts.txt`: seine Texte, auf Englisch und Griechisch.
- `icon.txt`: sein Symbol, 16×16, für die Ansicht Programme.

```bash
make app NAME=hello
```

Das baut `build/HELLO.BIN` und legt es auf die Diskette der Programme, `build/apps.dsk`. `make run` legt sie in B: ein; im Launcher zeigt TAB das Laufwerk B:.

```bash
make run
```

Das öffnet die Diskette in Caprice32. HELLO steht in der Ansicht Programme, auf der letzten Seite.

- Ein einfaches `make` baut alle Programme in `myapps/` und legt sie zusammen mit V-OS auf die Diskette.
- Der Name hat 1–8 Kleinbuchstaben oder Ziffern und beginnt mit einem Buchstaben. Er darf nicht der Name eines V-OS-Programms sein (z. B. demo).
- Du brauchst RASM, Python 3 und iDSK, wie für ganz V-OS.
- In Caprice32 startest du das Programm selbst, aus der Ansicht Programme.

Ein größeres Programm:

- Leg weitere `.asm`-Dateien in seinen Ordner (z. B. `art.asm` mit Sprites) und hol sie mit `include "art.asm"` herein. Der Build findet sie und baut das Programm neu, wenn sie sich ändern.
- Was du in den Unterordner `disc/` legst (z. B. `disc/LEVEL1.DAT`), kommt unverändert auf die Diskette, für `VOS_LOAD`.
- Mit einem Unterordner `owndisc/` bekommt das Programm auch eine eigene Diskette, `build/<name>.dsk`, mit der `.BIN` und den Dateien aus `owndisc/`. Es kommt nicht auf `apps.dsk`. Du legst sie in B: ein und startest es aus dem Launcher (TAB, das andere Laufwerk). Von welchem Laufwerk es gestartet wurde, damit es seine Dateien von dort lädt, steht in `VOS_SELF`: `db Laufwerk`, dann sein Name (11 Bytes).
- **Eine Datei zum Öffnen (Version 14):** wenn RETURN auf dem Schreibtisch oder im Commander eine Datei in deinem Programm öffnet, enthält `VOS_OPEN` (`#B000`) `db 1, Laufwerk, 11-Byte-Name` (0: keine). Lies es in `init`, mit A = 0 und auch mit A = 2 (das Programm lief schon), und schreibe danach 0 hinein. Die Typen und ihre Programme stehen in der Tabelle `ft_open` des Kernels (`src/kernel/files_ext.asm`).
- Ein Programm mit Relocation-Tabelle (wie die des SDK) läuft bis 12K neben anderen; ein größeres (bis 16K) läuft ohne Speichererweiterung allein, wie eines ohne Tabelle (MARKDOWN, READER). Für den Rest lädst du Dateien in die Daten-Bank.

## Wie ein Programm funktioniert

Ein Programm ist eine `.BIN`, gebaut für `VOS_APP_ADDR` (`#4000`). Es beginnt so:

```
        include "api/vos_api.inc"
        org VOS_APP_ADDR
        jp init                 ; +0
        jp event                ; +3  HL -> das Ereignis
        jp redraw               ; +6
        db "VA", VOS_API_VERSION
        include "app_icon.asm"  ; +12 das Symbol (optional)
```

- **`init`** setzt Modus, Palette, Menü und Schaltflächen, schaltet bei Bedarf `VE_FRAME` ein und zeichnet alles.
  - A = 0: ein frischer Start.
  - A = 2: Das Programm kehrt aus einer Ansicht oder einem anderen Programm zurück. Sein Zustand ist so, wie es ihn verlassen hat; es setzt das oben Genannte erneut und zeichnet.
- **`event`** wird für jedes Ereignis aufgerufen und kehrt sofort zurück. Ein Programm wartet nie selbst (keine Warteschleife). Für Bewegung oder Zeit `VOS_TICKS` mit A = 1, dann kommt 50-mal pro Sekunde ein `VE_FRAME`.
- **`redraw`** zeichnet alles neu, z. B. wenn sich die Sprache ändert oder das Zubehörprogramm sich schließt.
- **Beenden:** `VOS_EXIT`, das zu der Ansicht zurückkehrt, die es gestartet hat.

### Die Reihenfolge in `event`

```
event:  ld a,(hl)
        cp VE_FRAME : jp z,frame        ; die Frames
        push hl
        call VOS_UI_EVENT               ; Menüs, Schaltflächen, CONTROL+Buchstabe
        pop hl
        or a : jr nz,command            ; A = der Befehl
        call VOS_MENU_OPEN : ret nz     ; Menü offen: die Tasten gehören ihm
        ...                             ; deine eigenen Tasten und Klicks
command: ...
        jp VOS_COMMAND                  ; was nicht deins ist (VIEW, HELP)
```

**Solange ein Menü offen ist, zeichne nicht.** Sonst zeichnest du darüber. Bei `VE_FRAME` aktualisiere den Zustand, aber zeichne nur, wenn `VOS_MENU_OPEN` Z ergibt. Dialoge (`VOS_DIALOG`, `VOS_INPUT`, `VOS_FILE_PICK`) haben ihre eigene Schleife, deshalb kommt kein Ereignis an, solange sie offen sind.

### Die Ereignisse

`HL` → 8 Bytes: `db type, code, char, mods; dw x, y`.

| type | was | code / char / x, y |
|---|---|---|
| `VE_KEY_DOWN` 1, `VE_KEY_REPEAT` 3, `VE_KEY_UP` 2 | Taste | code = Tastennummer (`VK_*`, Tastaturreihe·8 + Bit), char = das Zeichen in der Sprache des Pakets |
| `VE_PTR_DOWN` 5, `VE_PTR_UP` 6, `VE_PTR_MOVE` 4 | Zeiger | x, y in Pixeln des Modus |
| `VE_FRAME` 8 | Frame (mit `VOS_TICKS`) | — |
| `VE_LANG` 7 | die Tastatursprache hat sich geändert | — |

### Drei Arten von Programmen

- **Mit Relokationstabelle (die Voreinstellung des SDK):** `make app` baut es zweimal, bei `#4000` und bei `#4100`. `tools/mkreloc.py` fügt die Tabelle aus dem Unterschied hinzu.
  - Es läuft neben anderen Programmen, in den 12K ab `#5000`, und macht dort weiter, wo es aufgehört hat (F6 zeigt die laufenden Programme).
  - Seine Daten müssen in seinen eigenen Bytes liegen (Labels, `ds`), nie an festen Adressen.
  - Gibt `mkreloc.py` einen Fehler aus, wird irgendwo eine Adresse so benutzt, dass sie die Relokation nicht übersteht. Z. B. `ld a,label & 255`, oder nur das niedrige Byte einer Adresse.
- **Ohne Tabelle:** Es nimmt die ganze Bank (bis zu 16K, Code und Daten), läuft aber nur allein, außer es gibt eine Speichererweiterung. Dafür brauchst du eine eigene Regel im Makefile (siehe `STUDIO.BIN`).
- **Zubehörprogramm:** bis zu 4K, mit Tabelle. Es öffnet sich mit F5 über allem, und `init` bekommt A = 1. Siehe `apps/clock/clock.asm` und die Beschreibung in `src/api/vos_api.inc`.

### Regeln

- **Register:** Aufrufe verändern alle Register außer IX. Argumente kommen in A, BC, DE, HL (IX für `VOS_RECT` und `VOS_BLIT`). Ergebnisse kommen in A oder HL zurück. Bei einem Fehler ist Carry gesetzt und A = Fehlernummer, die `VOS_ERROR` anzeigt.
- **Speicher:** Blende keine andere Bank bei `#4000` ein, denn dann verschwindet das Programm unter dir. Für 16K mehr gibt es die Daten-Bank (`VOS_BANK_GET`, `VOS_BANK_PUT`, `VOS_DATA`). Sie wird mit Ansichten und anderen Programmen geteilt und behält ihre Daten nur, solange das Programm läuft. Mit einer Speichererweiterung (API 21) bekommt jedes Programm eine eigene, die ihren Inhalt bis zu seinem Ende behält, was auch immer dazwischen läuft; `VX_DATA` sagt, welche gilt (A = 1: eine eigene).
- **Koordinaten:** x in Pixeln des Modus (Modus 0: 0–191, Modus 1: 0–383, Modus 2: 0–767), y von 0 bis 258. Die Menüleiste belegt y 0–11.
- **RASM:** Bei Labels spielt Groß- und Kleinschreibung keine Rolle (`BOX` und `box` sind dasselbe). Hex wird mit `#` geschrieben und nicht mit `&`.

## Die Datenformate

- **Menüleiste** (`VOS_SET_BAR`): `db count; dw menu, ...`. Die gemeinsamen Menüs VIEW und HELP (auf dem Bildschirm ANSICHT und HILFE) kommen von `VOS_MENU_VIEW` und `VOS_MENU_HELP`.
- **Menü:** `db title, count` und für jeden Eintrag `db text, command, letter, 0`.
  - text: `VOS_SEPARATOR` für eine Linie
  - command: 1.., was `VOS_UI_EVENT` zurückgibt
  - letter: Kurzbefehl CONTROL+Buchstabe, oder 0
- **Schaltflächen** (`VOS_SET_WIDGETS`, dann `VOS_DRAW_WIDGETS`): `db count`, und für jede Schaltfläche `dw x, y; db Breite in Zeichen, text, command, 0`.
- **Dialog** (`VOS_DIALOG` → A = Schaltfläche, 0 die erste, ESC ergibt die letzte): `db title, text, Anzahl der Schaltflächen (1–3), button, ...`. Für die Schaltflächen `VM_OK`, `VM_YES` und `VM_NO`.
- **Texte** (`VOS_TEXTS`): erzeugt von `tools/mktexts.py` aus `texts.txt`, mit Zeilen `NAME | English | Greek`. Beide Spalten werden in UTF-8 geschrieben und werden zu Bytes des V-OS-Zeichensatzes (`tools/voscs.py`), der Griechisch und die lateinischen Buchstaben von Französisch, Spanisch, Deutsch und Italienisch enthält.
  - Es liefert `T_NAME` (`VT_FIRST` = `#C0` und aufwärts) und die Tabelle `texts:`. Bis zu 64 Texte.
  - Ein `|` ohne Leerzeichen davor und danach beginnt in Dialogen eine neue Zeile.
  - Texte gehen überall dorthin, wo ein „Text“ verlangt wird (Menüs, Schaltflächen, Dialoge). Mit `VOS_MSG` bekommst du ihre Adresse für `VOS_PRINT`.
- **Palette** (`VOS_PALETTE`): 17 Firmware-Farben (0–26): 16 Stifte und der Rand. In Modus 1 zählen die Stifte 0–3.
- **Rechteck** (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`.
- **Symbol:** 16 Zeilen mit 16 Zeichen in `icon.txt`. Jedes Zeichen ist ein Stift in Hex (Modus 0, Palette der Ansicht Programme) oder `.` für transparent. Die Ansicht Programme liest es von der Diskette: solange das Programm läuft, sind die 256 Bytes nach "IC" frei für Puffer (PAINT legt dort seine Zeilen ab).
- **Dateinamen** (`VOS_LOAD`, `VOS_SAVE`, `VOS_DELETE`, `VOS_RUN`): 11 Bytes, `"NAME    EXT"`. Laufwerk 0 = A:, 1 = B:.

## Die API (Version 22)

| Aufruf | Eingabe → Ausgabe | Was er tut |
|---|---|---|
| `VOS_EXIT` | — | Ende, zurück zu der Ansicht, die es gestartet hat |
| `VOS_TICKS` | A = 1 / 0 (+ `VOS_PTR_KEYS`) | `VE_FRAME` 50-mal pro Sekunde, oder keines. Mit `VOS_PTR_KEYS` (2) bewegen die Pfeile und COPY auch den Zeiger und klicken |
| `VOS_FRAMES` | → HL (und A Bits 16–23) | Frames seit dem Start |
| `VOS_RANDOM` | → A | 0–255 |
| `VOS_COMMAND` | A = Befehl | die gemeinsamen Befehle von VIEW und HELP (6–19). Nummeriere deine eigenen Befehle ab `VC_APP` (32), sonst startet ein Eintrag von VIEW oder HELP einen deiner Befehle |
| `VOS_ERROR` | A = Fehler | Fehlerdialog |
| `VOS_MODE` | A = 0 / 1 / 2 | Modus 0 (192×259, 16 Stifte), 1 (384×259, 4 Stifte) oder 2 (768×259, 2 Stifte, 96 Textspalten; Version 25). In Modus 2 zeichnen Menüs und Dialoge mit Stift 1 auf Stift 0: Stift 0 weiß und 1 schwarz ergeben schwarze Schrift auf weißem Papier (NOTEPAD, MARKDOWN, READER, SHEET mit ^M) |
| `VOS_PALETTE` | HL → 17 Farben | |
| `VOS_CLS` | A = Stift | löscht den Bildschirm |
| `VOS_PLOT` | HL = x, DE = y, A = Stift | ein Pixel |
| `VOS_RECT` | IX → Rechteck | gefülltes Rechteck |
| `VOS_COLOURS` | A = Textstift (+ `VOS_BOLD`, `VOS_ITALIC`, `VOS_UNDERLINE`), C = Hintergrund | für `VOS_PRINT` und `VOS_CHAR`. Die Stile entstehen aus derselben Schrift, für jede Sprache |
| `VOS_PRINT` | HL = x, DE = y, BC → Text, 0 | |
| `VOS_CHAR` | HL = x, DE = y, A = Zeichen | |
| `VOS_MSG` | A = Text → HL | die Adresse eines Textes (`T_*` oder eines Systemtextes) |
| `VOS_SET_BAR`, `VOS_DRAW_BAR` | HL → Menüleiste | |
| `VOS_UI_EVENT` | (das aktuelle Ereignis) → A | Befehl von Menü, Schaltfläche oder Kurzbefehl, 0 für keinen |
| `VOS_DIALOG` | HL → Dialog → A | |
| `VOS_INPUT` | A = Titel, HL → Text, C = Maximum → Carry bei Abbruch | Texteingabe (braucht C + 2 Bytes) |
| `VOS_SET_WIDGETS`, `VOS_DRAW_WIDGETS` | HL → Schaltflächen | |
| `VOS_MENU_VIEW`, `VOS_MENU_HELP` | → HL | die gemeinsamen Menüs |
| `VOS_CATALOG` | A = Laufwerk → A = Dateien, HL → Liste | je 16 Bytes: 11 der Name, bei +12 die Größe in K. Mit A = Laufwerk + `VOS_CAT_EXT` und HL → `"EXT"` nur die Dateien mit dieser Endung |
| `VOS_FILE_PICK` | A = Titel → A = Datei, Carry bei Abbruch | Auswahldialog, nach `VOS_CATALOG` |
| `VOS_LOAD` | A = Laufwerk, HL → Name, DE = wohin → BC = Länge | |
| `VOS_SAVE` | A = Laufwerk, HL → Name, DE = ab, BC = Länge | Binärdatei, ersetzt die alte. Mit A + `VOS_LOAD_IX` (#40, Version 20) sagt ihr Header, dass sie bei IX lädt, nicht bei DE (eine `.SCR`: IX = #C000) |
| `VOS_DELETE` | A = Laufwerk, HL → Name | |
| `VOS_TEXTS` | HL → Texttabelle | die Texte des Programms |
| `VOS_MENU_OPEN` | → NZ, wenn ein Menü offen ist | |
| `VOS_KEY_HELD` | A = Taste → NZ, solange gedrückt | für Spiele |
| `VOS_BLIT` | IX → `dw x, y; db bytes, lines; dw source; db source stride` | Bild: Paare (Maske, Pixel) |
| `VOS_SOUND` | A = Kanal 0–2, HL = Periode (Bit 15: Rauschen), C = Lautstärke 0–15, B = Frames | eine Note; 440 Hz ist Periode 142 |
| `VOS_SPLIT` | HL → `dw y1, y2; db 8 colors` (0 = schaltet ab) | gemischter Bildschirm: Modus 0 zwischen y1 und y2 |
| `VOS_RUN` | A = Laufwerk, HL → Name | startet ein anderes Programm, und danach startet dieses wieder |
| `VOS_KEEP` | → HL → 16 Bytes | Speicher, der zwischen Programmen erhalten bleibt |
| `VOS_BANK_GET`, `VOS_BANK_PUT` | HL = ab, DE = nach, BC = Bytes | Kopieren aus der und in die Daten-Bank |
| `VOS_BACKGROUND` | A = 1 / 0 | läuft weiter oder friert ein, wenn es hinter einem anderen liegt |
| `VOS_DRAG` | HL = x, DE = y, BC = w, A = h → Carry: neue HL, DE | ein Fenster an seinem Titel verschieben |
| `VOS_FIT` | dasselbe → HL, DE | holt ein Fenster in den Bildschirm hinein |
| `VOS_EXT` | A = ein `VX_*`-Aufruf, BC, DE, HL wie er es will → A, HL, C, DE, Carry | die Aufrufe nach der Tabelle (Version 15), unten |

**Die Aufrufe von `VOS_EXT`:** `VX_VERSION` → A = API, HL = V-OS-Version (BCD). `VX_FREE` C = Laufwerk → A = freie K. Unbekannt: Carry `VX_CLIP_PUT` HL = Text, BC = Bytes → die Zwischenablage (bis 1K). `VX_CLIP_GET` DE = wohin, BC = Platz → HL = Größe (Version 16). `VX_M4` HL → ein Befehl für die M4-Karte (db Größe, dw Befehl, Daten), DE → die Antwort, BC = Bytes; Carry: keine M4-Karte (Version 17). `VX_MEM` → HL = der RAM in K, DE = die freien K für Programme (Version 18). `VX_BEHIND` DE → db Laufwerk, 11-Byte-Name einer Datei: ihr Programm (nach Typ) startet hinter diesem, mit `init` A = 3 und der Datei in `VOS_OPEN` (Version 19; MUSIC kennt es). `VX_DATA` → A = 1, wenn die Daten-Bank die eigene ist (Speichererweiterung), 0, wenn es die geteilte Bank 4 ist (Version 21; NOTEPAD hält so Text bis 16K). `VX_DB` C = ein `DB_*`-Aufruf, DE, HL → eine Datenbank (Version 22, unten). `VX_UTF8` HL → ein Text, BC = Bytes, E = 0 im Speicher des Programms oder `VOS_DATA` in seiner Datenbank-Bank: ist er UTF-8 (vom PC oder aus dem Web), wird er dort zum V-OS-Zeichensatz → BC = Bytes jetzt, A = 1; A = 0: er war kein UTF-8 und bleibt, wie er war (Version 23; so machen es NOTEPAD und READER). `VX_CALC` C = ein `CALC_*`-Aufruf, DE → ein Block, HL → Text → Formeln und Zahlen (Version 24, unten). `VX_LANG` → HL = der Code der Sprache, die V-OS zeigt (`"EN"`, `"EL"`, `"FR"`…; L der erste Buchstabe) (Version 26; so zeigt VBRUN die Übersetzungen der Studio-Programme).

### Datenbanken (Version 22)

`VOS_EXT` mit A = `VX_DB` und C = einem `DB_*`-Aufruf arbeitet mit einer Datenbank: einer Datei `NAME.VDB` aus 1K-Seiten, so groß wie die Diskette erlaubt (bis 255K). Sie hat bis zu 8 Tabellen; eine Tabelle hat bis zu 10 Felder, Text (bis 255 Zeichen) oder eine Zahl (2 Bytes), und kann ein Schlüsselfeld haben (Text bis 64 Zeichen, oder eine Zahl) mit einem Index, damit FIND schnell ist. Ein Datensatz sind seine Felder hintereinander; seine Kennung (rid) ist eine 16-Bit-Zahl. Eine Datenbank ist jeweils offen, für das Programm, das sie geöffnet hat. Jeder Aufruf schreibt seine Änderungen auf die Diskette, bevor er zurückkehrt. Der Kernel lädt die Maschine, `DB.SYS`, beim ersten Mal von Laufwerk A:.

| Aufruf | Ein → aus |
|---|---|
| `DB_CREATE`, `DB_OPEN` | DE → db Laufwerk, 11-Byte-Name (`"STREETS VDB"`); OPEN → A = 1: Latin-1 (von V-OS 0.15) |
| `DB_CLOSE` | |
| `DB_TABLE` | DE → Name (8), Felder, Schlüsselfeld (0: keins), dann jedes Feld: Name (8), Typ, Länge → A = Tabelle |
| `DB_USE` | E = die Tabelle, die die Aufrufe unten nutzen |
| `DB_INFO` | E = Tabelle, HL → 124 Bytes: ihre Beschreibung → A = Tabellen |
| `DB_ADD` | HL → Datensatz → DE = rid |
| `DB_GET`, `DB_PUT` | DE = rid, HL → der Datensatz |
| `DB_DEL` | DE = rid |
| `DB_FIND` | HL → Schlüssel wie im Datensatz (Platz für einen Datensatz), E = zählende Bytes (0: alle) → DE = der erste Datensatz mit diesem Schlüssel oder danach |
| `DB_FIRST`, `DB_LAST`, `DB_NEXT`, `DB_PREV` | HL → Platz für den Datensatz, oder 0 → DE = rid, nach Schlüssel; Carry am Ende |
| `DB_COUNT` | → HL = Datensätze |

Fehler: Carry und A (`DB_ERR_*`, und die Fehler der Diskette), die `VOS_ERROR` zeigt. Text wird gespeichert, wie er getippt wurde, im V-OS-Zeichensatz, in allen Sprachen demselben: eine Datenbank kann Griechisch, Französisch und Deutsch zusammen enthalten. Nur eine Datenbank von V-OS 0.15 mit lateinischen Buchstaben (Latin-1) ist anders: `DB_OPEN` gibt dann A = 1; zeige `DB_ERR_ALPHABET` mit `VOS_ERROR`. Sortieren und FIND vergleichen Bytes: in einem `DB_TEXT`-Schlüssel sind Groß- und Kleinbuchstaben, und solche mit Akzent, verschieden. Ein `DB_ALPHA`-Feld (Typ 2, ab Version 23) ist Text wie `DB_TEXT`, wird als Schlüssel aber ohne Groß-/Kleinschreibung und Akzente sortiert und gefunden: ΕΛΕΝΗ, Ελένη und ελένη, oder Élodie und ELODIE, sind dasselbe; der Datensatz behält den Text, wie er getippt wurde. Beispiele sind STREETS (`myapps/streets`), ein Straßenverzeichnis, und DATABASE (`myapps/database`), ein ganzes Datenbankprogramm mit Tabellen, Liste und Formular; `tools/vdb.py` zeigt und prüft eine `.VDB`-Datei auf dem PC.

### Formeln (Version 24)

`VOS_EXT` mit A = `VX_CALC` und C = einem `CALC_*`-Aufruf berechnet Formeln, wie eine Tabellenkalkulation. Der Kernel lädt die Engine, `CALC.SYS`, beim ersten Mal von Laufwerk A:. Eine Zahl hat 32 Bit, in Hundertsteln (1234 ist 12.34), von -21474836.46 bis 21474836.46. Eine Formel hat `+ - * /`, Klammern, Zahlen (`12`, `3.5`, `.25`; eine dritte Dezimalstelle rundet), Zellen (`A1` bis `Z255`) und die Funktionen SUM, AVG, MIN, MAX, COUNT (von Werten, Zellen und Bereichen wie `B2:D9`, getrennt durch `,` oder `;`), ABS(x), INT(x) (abwärts auf eine ganze Zahl) und ROUND(x) oder ROUND(x, 0–2), groß oder klein geschrieben. Produkte und Quotienten werden auf das Hundertstel gerundet.

DE → der Block des Programms, `CB_SIZE` (10) Bytes: `CB_RESULT` (eine Zahl, 4 Bytes), `CB_COLS`, `CB_ROWS`, `CB_GRID` (dw), `CB_BANK`, `CB_AT`. Die Zellen sind ein Raster des Programms: `CB_COLS` × `CB_ROWS` Zahlen zu 4 Bytes, Zeile für Zeile, bei `CB_GRID`, in seiner Daten-Bank, wenn `CB_BANK` = `VOS_DATA`. Eine Zelle `CALC_NONE` hat keine Zahl (leer oder Text: 0 in `+ - * /`, von den Funktionen ausgelassen); `CALC_BAD` hat einen Fehler.

| Aufruf | Eingabe → Ausgabe |
|---|---|
| `CALC_EVAL` | HL → Formel, 0 (mit `=` davor oder nicht) → `CB_RESULT` und DE:HL (DE der hohe Teil) |
| `CALC_NUMBER` | HL → Text: nur eine Zahl? → wie `CALC_EVAL` |
| `CALC_TEXT` | `CB_RESULT` → Text bei HL (Platz für 13 Bytes: `-12.5`), A = seine Länge |
| `CALC_CELL` | HL → Text: eine Zelle (`b12`) am Anfang? → D = Spalte, E = Zeile (ab 0), A = ihre Zeichen |

Fehler: Carry und A (`CALC_ERR_*`: 30 falsche Formel, 31 Division durch null, 32 Zahl zu groß, 33 Zelle außerhalb des Rasters, 34 eine benutzte Zelle hat einen Fehler, 29 `CALC.SYS` ist nicht auf A:), die `VOS_ERROR` zeigt; dann ist `CB_RESULT` = `CALC_BAD` und `CB_AT` = die Stelle im Text. Das Beispiel ist SHEET (`myapps/sheet`), eine Tabellenkalkulation, die ihre Werte in ihrer Daten-Bank hält und die Formeln nach jeder Änderung neu berechnet.

Alle Details, z. B. zum Hintergrund, zum Zubehörprogramm und zu `VOS_SPLIT`, stehen in `src/api/vos_api.inc`. Beispiele findest du in `apps/demo/demo.asm` (Modus 0, Bewegung), `apps/clock/clock.asm` (Zubehör) und `apps/mixed/mixed.asm` (gemischter Bildschirm). Ein ganzes Spiel mit Sprites, einem Level aus einer Datei und Ton ist `myapps/vrouves/`.

Ein KI-Assistent, der ein Programm schreibt, sollte [`AI.md`](AI.md) lesen (auf Englisch): dieselben Regeln, kürzer, mit den Fallen von RASM und der Datenbank.

## Testen

`make test-sdk` baut die Vorlage als TEMPLATE.BIN und öffnet sie in Caprice32 aus der Ansicht Programme, mit Tastendrücken, die `src/kernel/test_script.asm` festlegt (Skript 15). Es macht Screenshots in `build/shots`: seinen Bildschirm, das Kästchen nach der Bewegung, sein Menü, den Dialog ABOUT und die Rückkehr zur Ansicht Programme.

Für deinen eigenen automatischen Test kopiere Skript 15 und das Ziel `test-sdk` des Makefiles.
