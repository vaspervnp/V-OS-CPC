# 3. Programme

## Starten und Beenden

Ein Programm startet auf eine dieser Arten:

- aus der Ansicht Programme: auswählen und RETURN drücken, oder zweimal klicken
- vom Schreibtisch oder aus dem Commander: DATEI > STARTEN
- aus einem anderen Programm, etwa Studio, das alles startet, was du erstellst

Jedes Programm hat sein eigenes Menü neben den gemeinsamen Menüs ANSICHT und HILFE. Es endet über sein Menü (meist BACK oder STOP, CONTROL+Q) und kehrt zu der Ansicht zurück, aus der es gestartet wurde.

## Mehrere Programme gleichzeitig

Es gibt zwei Arten von V-OS-Programmen:

- **Kleine, mit einer Relokationstabelle:** DEMO, MIXED und CLOCK, die Beispiele des Web-Editors (PONG, CATCH, STARCAT, COUNTER) und alles, was das [SDK](../../../sdk/README.de.md) erzeugt. Sie teilen sich 12K Speicher, und so viele, wie hineinpassen, laufen zusammen.
- **Programme, die den ganzen Speicher brauchen:** STUDIO und alles, was Studio erzeugt (CALC, MINES, FLAP, TICKER und deine eigenen). Ohne Speichererweiterung laufen sie nur allein. Läuft schon eines, erscheint „ERST EIN ANDERES PROGRAMM SCHLIESSEN“.

Wenn du zu einer Ansicht wechselst (F1–F4), während ein Programm läuft:

- Ein kleines Programm bleibt im Speicher. Du holst es in der Ansicht Programme (RETURN darauf) oder mit F6 wieder hervor, und es macht genau dort weiter, wo es war.
- Ein Programm, das den ganzen Speicher hat, endet, außer es gibt eine Speichererweiterung.

**F6** (ANSICHT > PROGRAMME) zeigt die Liste der laufenden Programme. Du wählst eines mit den Pfeilen und RETURN. Läuft keines, erscheint „KEIN PROGRAMM LÄUFT“.

**Mit einer Speichererweiterung** (z. B. 512K, die V-OS beim Start von selbst findet) bekommt jedes Programm, das den ganzen Speicher braucht, eine eigene Bank. So können STUDIO, CALC, DEMO und PONG alle zusammen laufen.

## Im Hintergrund

Ein Programm hinter einem anderen oder hinter einer Ansicht **friert** normalerweise **ein** und macht weiter, wenn es wieder nach vorne kommt.

Manche Programme verlangen, auch im Hintergrund **weiterzulaufen**, z. B. TICKER, das die Zeit zählt. Solange sie dort sind, zeichnen sie nicht und spielen keinen Ton. Wenn sie wieder nach vorne kommen, haben sie auch die Zeit mitgezählt, in der sie weg waren.

In Studio wählst du das für dein Programm mit STUDIO > IN BACKGROUND.

## Das Zubehörprogramm (ZUBEHÖR)

Ein kleines Programm wie CLOCK kann sich in einem Fenster **über allem** öffnen: über einer Ansicht oder einem Programm.

1. Wähle in der Ansicht Programme CLOCK aus und dann DATEI > ALS ZUBEHÖR (^A).
2. Ab dann öffnet und schließt **F5** es, wo du auch bist. Auch ESC schließt es.

Solange es offen ist, bekommt es die Tasten und Klicks. Sein Fenster lässt sich an seinem Titel verschieben. Wenn es sich schließt, wird neu gezeichnet, was darunter war.

## Die Programme auf der Diskette

| Programm | Was es ist |
|---|---|
| **STUDIO** | der Block-Editor: Du erstellst Programme auf dem CPC ([Kapitel 5](05-studio.md)) |
| **DEMO** | das erste V-OS-Programm: ein Quadrat, das sich von selbst bewegt. Die Pfeile steuern es, und SPACE ändert seine Farbe |
| **MIXED** | der „gemischte Bildschirm“: ein Streifen mit 16 Farben (Modus 0) zwischen Streifen in Modus 1. Ein Klick zeigt die Koordinaten |
| **CLOCK** | die Zeit seit dem Start von V-OS. Läuft auch als Zubehörprogramm |
| **CALC** | ein Taschenrechner in einem Fenster mit Schaltflächen, erstellt in Studio (es gibt auch `CALC.VBS`) |
| **MINES** | ein Minesweeper mit 8×6 Feldern und 8 Minen, erstellt in Studio. Ein Klick deckt ein Feld auf, und NEW startet ein neues Spiel |
| **BRICKS** | Mauerbrechen: ein Schläger mit ←/→, 32 Steine, 3 Leben, Level mit einem immer schnelleren Ball. Bei GAME OVER startet SPACE ein neues Spiel |
| **VROUVES** | Tower Defence, nach dem CPC-Spiel LET'S GO FOR VROUVES: 7 Level, vom Kafenio bis zum Friedhof, mit je 10 Wellen. Die V-OS-Diskette hat Level 1. Alle stehen auf seiner eigenen Diskette, `vrouves.dsk`: in B:, und DATEI > STARTEN im Commander. Die Pfeile bewegen den Cursor, 1–6 wählt einen Verteidiger, SPACE baut, S verkauft, N holt die nächste Welle, P pausiert. Mit dem SDK geschrieben (`myapps/vrouves`) |
| **PONG** | ein Ball und ein Schläger mit den Pfeilen, Punkte und Leben |
| **CATCH** | fange die fallenden Sterne |
| **STARCAT** | eine Katze mit Kostümen, die läuft, ein Stern, eine Melodie aus einer Liste |
| **COUNTER** | ein Zähler mit den Schaltflächen +1, −1 und 0, in Modus 1 |
| **FLAP** | ein Vogel, der mit den Flügeln schlägt (Kostüme), und ein Stern, der jede Sekunde das Kostüm wechselt |
| **TICKER** | zählt Sekunden und läuft im Hintergrund weiter |

- Blockprogramme sind `.VBN`-Dateien. Sie haben ein Menü PROGRAM > STOP (CONTROL+Q).
- Die, die auch eine `.VBS` haben (CALC, MINES, FLAP, TICKER), lassen sich in Studio öffnen, damit du sie ansehen oder ändern kannst.
- `VBRUN.SYS` ist kein Programm: Es ist der „Player“, den Studio braucht.
