# 8. V-OS entwickeln

Für alle, die an V-OS selbst arbeiten. Programme *für* V-OS beschreibt das [SDK](../../../sdk/README.de.md).

## Was du brauchst

- [RASM](https://github.com/EdouardBERGE/rasm), den Assembler
- [iDSK](https://github.com/cpcsdk/idsk), für die Disketten-Images
- Python 3, für die Werkzeuge. `make docs` braucht außerdem `markdown` und `pymupdf`.
- GNU make 4.3 oder neuer
- zum Testen Caprice32 (snap `caprice32`)

## Build

| Befehl | Was er tut |
|---|---|
| `make` | `build/vos.dsk`: der Kernel, die Ansichten, die Sprachen, alle Programme und `myapps/*` |
| `make run` | öffnet die Diskette in Caprice32 (`RUN"VOS"`) |
| `make shot` | startet ohne Fenster und macht einen Screenshot |
| `make docs` | das Handbuch als PDFs: `docs/V-OS.pdf` (Griechisch) und `docs/V-OS-en.pdf`, `-fr`, `-es`, `-de`, `-it` |
| `make windows` | `build/V-OS-windows.zip`: `V-OS.exe` für Windows, mit CPCEMU 3.0.2 (CPC 6128, 576K, AMX-Maus, M4-Karte), `vos.dsk` in A: und `vrouves.dsk` in B:. V-OS startet von selbst. Braucht WSL und das portable Zip von CPCEMU (`CPCEMU_ZIP=…`) |
| `make songs` | die Songs von Arkos Tracker 3 als `.MUS`-Dateien in `myapps/music/owndisc` (`tools/mkmusic.py`; braucht Arkos Tracker 3, `ARKOS=…`) |
| `make new-app NAME=x`, `make app NAME=x` | dein eigenes Programm (SDK) |
| `make clean` | löscht `build/` |

## Aufbau des Repos

| Ordner | Inhalt |
|---|---|
| `src/vos.asm` | die Wurzel des Builds: Lader und Kernel, Schreiben auf die Diskette |
| `src/boot/` | der Lader, den AMSDOS bei `#4000` startet, Erkennung der RAM-Erweiterung |
| `src/kernel/` | Vektoren, Interrupts, Dateisystem, Ansichten, API (`api.asm`), Einstellungen, Kernel-Erweiterung (`ext.asm`), Testskripte (`test_script.asm`) |
| `src/drivers/` | Gate Array, CRTC, Tastatur, AMX-Maus, FDC, AY |
| `src/gfx/` | Overscan-Grafik, Text, gemischter Bildschirm |
| `src/ui/` | Menüs, Schaltflächen, Dialoge, Texteingabe, Dateiauswahl |
| `src/shell/` | die Ansichten als Overlays: Schreibtisch, Programme, Commander, Optionen |
| `src/api/vos_api.inc` | die API für Programme |
| `lang/` | die Sprachen (Texte, Tastaturen, Schriften) |
| `apps/` | die Programme in Assembler: DEMO, MIXED, STUDIO, CLOCK, und ihre Symbole |
| `blocks/` | der Web-Editor, `vbc.py`, `runtime.asm`, der Player von Studio (`player.asm`), Beispiele |
| `sdk/` | das SDK: Anleitung und Programmvorlage |
| `tools/` | Werkzeuge: Schriften, Sprachen, Texte, Symbole, Relokation, `.VBS` aus Text, Screenshots, PDF |
| `docs/` | dieses Handbuch auf Griechisch (`manual/`) und auf Englisch, Französisch, Spanisch, Deutsch und Italienisch (`manual/en/`, `fr/`, `es/`, `de/`, `it/`), die PDFs, die Anforderungen (`REQUIREMENTS.md`) |

## Speicher, kurz gefasst

| Bereich | Was er enthält |
|---|---|
| `#0000–#3DFF` | der Kernel. In Seite null, nach den Restart-Vektoren, die API-Tabelle bei `#0108` |
| bis `#4000` | der Stack des Kernels |
| `#4000–#7FFF` | das „Fenster“ für die Bänke |
| `#8000–#FFFF` | der 32K-Overscan-Bildschirm. In seinen Lücken Puffer des Kernels |

Die Bänke, die in das Fenster kommen:

| Bank | Was sie enthält |
|---|---|
| 4 | Datei- und Ladepuffer, und die Daten-Bank des laufenden Programms |
| 5 | die Ansicht bei `#4000–#4FFF`, und ab `#5000` die Programme mit Relokationstabelle (oder ein Programm ohne Tabelle in der ganzen Bank) |
| 6 | was die Menüs und Dialoge verdecken, und ab `#7000` das Zubehörprogramm |
| 7 | das Sprachpaket, die Listen des Commanders, die englischen Texte, und ab `#7000` die Kernel-Erweiterung |

Mit einer Speichererweiterung nehmen ihre Bänke Programme auf. Die Details, Adresse für Adresse, stehen in `docs/REQUIREMENTS.md` (§4.2 und in jedem Abschnitt „Υλοποίηση M…“ (Umsetzung)).

## Konventionen

- **RASM:** Hex wird `#C000` geschrieben und nicht `&C000`, weil RASM `&` als AND liest. Bei Labels spielt Groß- und Kleinschreibung keine Rolle.
- **Kommentare:** auf Englisch, kurz, wie im vorhandenen Code. Jede Datei beginnt mit einem Block, der sagt, was sie tut.
- **Dokumentation:** auf Griechisch. `README.md` und `docs/REQUIREMENTS.md` haben einen Abschnitt für jeden Meilenstein. Das Handbuch wird auf Griechisch geschrieben und in die anderen fünf Sprachen von V-OS übersetzt.
- **Texte:** Die Systemtexte stehen in `lang/*/messages.txt`, die Texte der Programme in `texts.txt` (für `tools/mktexts.py`).

## Tests

Die Tests starten V-OS in Caprice32 ohne Fenster und machen Screenshots in `build/shots/<delay>/`.

**Wie sie funktionieren:**

- Caprice32 ohne Fenster kann keine Pfeile, kein COPY und keine f-Tasten drücken. Deshalb werden die Tastendrücke von einem besonderen Build erzeugt: Ein `-DTEST_SCRIPT=n` fügt Skript n in `src/kernel/test_script.asm` ein, eine Tabelle von Tasten pro Frame.
- Jedes Ziel `make test-…` baut eine Diskette mit seinem Skript und macht bei jeder Verzögerung in `…_SHOTS` einen Screenshot.
- Die Verzögerung wird in „Z“-Drücken gemessen: jeweils etwa 2,5–3,5 Frames. Die Zuordnung ist nicht fest, deshalb fängst du einen Moment mit zwei oder drei Verzögerungen um ihn herum ein.
- Sobald V-OS auf die Diskette schreibt, schließt sich Caprice32 nicht mehr von selbst, und der Test endet mit einem Timeout. Das ist bei test-vars, test-costume und anderen zu erwarten.
- Die Screenshots siehst du dir selbst an, z. B. zu einem Bild zusammengesetzt mit `ffmpeg … hstack/vstack`.

| Ziel | Was es testet |
|---|---|
| `test-input` | Tasten, Studio: Blöcke, Dateien, Starten |
| `test-calc` | CALC mit Klicks, dann `CALC.VBS` in Studio |
| `test-costume` | Kostüm in Studio, Starten, erneutes Öffnen |
| `test-acc` | die Uhr als Zubehörprogramm |
| `test-multi`, `test-switch`, `test-expand`, `test-behind` | mehrere Programme, F6, Speichererweiterung, Hintergrund |
| `test-drag` | Fenster verschieben |
| `test-langs`, `test-lang` | die Sprachen, Speichern der Sprache |
| `test-mines`, `test-bricks` | die Spiele |
| `test-vars` | die 128 Variablen, SAVE/LOAD VARS |
| `test-sdk` | die SDK-Vorlage |
| `test-vrouves` | VROUVES von seiner Diskette in B:, über den Launcher (TAB): Bauen, Welle 1, das Geld, HIGH SCORES |
| `test-notepad` | NOTEPAD: Tippen, DEL, der Speicherdialog, OPEN mit nur `.TXT`-Dateien |
| `test-paint` | PAINT: Linie, Rechteck, Füllen, die Menüs, dann die Ebenen (eine ausblenden) |
| `test-about` | HILFE > ÜBER V-OS |
| `test-music` | MUSIC von `music.dsk` in B:: ein Song spielt und läuft hinter dem Launcher weiter |
| `test-amsdos`, `test-reboot`, `test-system` | V-OS-Dateien in BASIC, Neustart, SYSTEM-Diskette |

**Neues Skript:**

1. Füge ein `IF TEST_SCRIPT == n` am Anfang der Kette in `test_script.asm` hinzu, mit `ELSE` vor dem nächsten und einem weiteren `ENDIF` am Ende.
2. Füge im Makefile ein Ziel hinzu, wie `test-sdk`.

Jede Taste wird als `dw from, to : db row, bit` der Tastatur geschrieben. Die Tastennummer ist Reihe·8 + Bit, z. B. RETURN = 18 = Reihe 2, Bit 2.

**Ohne Emulator:** Der Code eines Programms läuft auch auf einem Z80 in Python (das Paket `z80`). Du lädst die `.BIN` bei `#4000` und lässt die API-Aufrufe sofort zurückkehren (oder tun, was nötig ist, z. B. Dateien in einem Dictionary). Dann rufst du init und event auf und liest den Speicher. Das ist bei Fehlern in Zahlen, Dateien und Sprüngen viel schneller als Screenshots. Die Adressen der Labels kommen von `rasm … -s -sl` (eine `.sym`-Datei).

## Bei jedem Meilenstein

1. Code, und ein Test in Caprice32: neu oder vorhanden, mit Screenshots.
2. Die Tests, die die Änderung berührt.
3. Ein Abschnitt in `README.md` und ein Abschnitt „Υλοποίηση M…“ (Umsetzung) in `docs/REQUIREMENTS.md`.
4. **Das Handbuch in allen sechs Sprachen aktualisieren** (`docs/manual/` auf Griechisch, `docs/manual/<code>/` für en, fr, es, de, it, und `sdk/README.md`, `sdk/README.<code>.md`, wenn sich die API ändert), dann `make docs` für alle PDFs.
5. Commit und Push.
