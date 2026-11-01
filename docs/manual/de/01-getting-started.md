# 1. Erste Schritte

## Was du brauchst

- Einen Amstrad CPC 6128 oder einen Emulator dafür. V-OS wird mit Caprice32 getestet.
- Die V-OS-Diskette in Laufwerk A:, also die `build/vos.dsk`, die `make` erzeugt, und die Diskette der Programme, `build/apps.dsk`, in B:.
- Optional:
  - eine AMX-Maus
  - ein zweites Laufwerk (B:)
  - eine Speichererweiterung (z. B. 512K), für mehr Programme gleichzeitig

## Starten

Aus BASIC:

```
RUN"VOS
```

V-OS lädt den Kernel, schaltet die ROMs ab und übernimmt die ganze Maschine. Eine Speichererweiterung erkennt es von selbst.

- **Erste Ansicht:** der Schreibtisch. Du kannst das in den Optionen ändern, in der Zeile START-ANSICHT.
- **Sprache:** Englisch. Liegt eine `SETUP.CFG` auf der Diskette, startet es mit der Sprache und den Einstellungen, die dort gespeichert sind.
- **Beenden:** DATEI > ZURÜCK ZU BASIC (CONTROL+Q in den Ansichten). Es fragt nach einer Bestätigung und startet den CPC neu.

## Der Bildschirm

V-OS nutzt den ganzen Bildschirm (Overscan): 384×272 Pixel in Modus 1 (4 Farben) oder 192×272 in Modus 0 (16 Farben).

- **Menüleiste** (oben): die Menüs der Ansicht oder des Programms, meist DATEI oder das Menü des Programms, ANSICHT und HILFE. Rechts steht die Tastatursprache (EN, ΕΛ, …).
- **Unterste Zeile:** in jeder Ansicht die Tasten, die dort funktionieren.

## Tasten, die überall funktionieren

| Taste | Was sie tut |
|---|---|
| F1 | Schreibtisch |
| F2 | Programme |
| F3 | Commander |
| F4 | Optionen |
| F5 | öffnet und schließt das Zubehörprogramm (ZUBEHÖR) |
| F6 | die laufenden Programme, um eines auszuwählen |
| ESC | öffnet das erste Menü. In den Menüs wechseln ←/→ das Menü, ↑/↓ wählen einen Eintrag, RETURN führt ihn aus, ESC schließt |
| CONTROL+Buchstabe | die Kurzbefehle der Menüs (z. B. ^Q, ^L) |
| CONTROL+L | Sprache wechseln (ANSICHT > SPRACHE WECHSELN) |
| CONTROL+K | der Dialog mit den Tasten (HILFE > TASTEN) |
| CONTROL+SHIFT | wechselt die Tastatur: Englisch, die des Pakets und, mit TASTATUREN: ALLE SECHS in Setup, die der anderen Sprachen |
| TAB, SHIFT+TAB | bewegen den Fokus zwischen den Schaltflächen. RETURN, ENTER oder SPACE drücken die Schaltfläche, die den Fokus hat |

F1–F6 sind die Tasten f1–f6 auf dem Ziffernblock des CPC.

## Der Zeiger und die Maus

- **Mit einer AMX-Maus:** Der Zeiger bewegt sich mit der Maus, und ihre Taste klickt. Die Maus wird in den Optionen eingeschaltet und eingestellt (AMX-MAUS, AMX-LESEART).
- **Ohne Maus:** Der Zeiger bewegt sich mit den Pfeiltasten, und COPY klickt. In Ansichten, die die Pfeiltasten zum Auswählen nutzen (Schreibtisch, Programme, Commander), wählen die Pfeile Dateien und Programme aus, statt den Zeiger zu bewegen.

Das meiste funktioniert mit beidem: Ein Klick auf eine Datei oder ein Programm wählt es aus, ein zweiter Klick öffnet es.

## Fenster und Dialoge

- **Verschieben:** Jedes Fenster lässt sich an seiner Titelleiste verschieben: die Dialoge, das Fenster DATEIEN des Schreibtischs, das Zubehörprogramm und die Fenster von Blockprogrammen. Solange du die Taste hältst, wird ein gestrichelter Umriss gezeigt, und das Fenster wird dort neu gezeichnet, wo du loslässt.
- **Dialoge:** warten auf eine Antwort. TAB und ←/→ wechseln die Schaltfläche, RETURN drückt sie, und ESC wählt die letzte (meist NEIN oder ABBRUCH).
- **Texteingabe** (z. B. beim Umbenennen): Du tippst am Ende, DEL löscht, RETURN übernimmt und ESC bricht ab. Du kannst auch in der Sprache des Sprachpakets tippen.

## Disketten und Dateien

- **Format:** V-OS liest und schreibt AMSDOS-Disketten (Format DATA oder SYSTEM) in A: und B:. Auch BASIC kann seine Dateien lesen.
- **Namen:** 8 Zeichen plus 3 für den Typ (`NAME.TYP`).

Typen, denen du begegnen wirst:

| Typ | Was es ist |
|---|---|
| `.BIN` | ein V-OS-Programm (oder eine Binärdatei) |
| `.VBN` | ein V-OS-Programm, das mit Blöcken erstellt wurde |
| `.VBS` | ein Studio-Programm (sein Quelltext) |
| `.OVL`, `.MSG`, `.LNG` | Teile von V-OS selbst: Ansichten, Texte, Sprachen |
| `.SYS` | Systemdateien (z. B. `VBRUN.SYS`, der Player von Studio) |
| `SETUP.CFG` | die Einstellungen |

Die Einstellungen, Sprachen und Ansichten werden von A: gelesen, deshalb muss die V-OS-Diskette dort bleiben.

## Fehlermeldungen

Diskettenfehler werden in einem Dialog angezeigt: NICHT BEREIT, SCHREIBGESCHÜTZT, DATEI NICHT GEFUNDEN, DISKETTE VOLL, VERZEICHNIS VOLL, NAME SCHON VERGEBEN, UNGÜLTIGER NAME und andere.

Zwei weitere betreffen Programme:

- **KEIN V-OS-PROGRAMM:** Die Datei hat nicht den Kopf eines Programms.
- **ERST EIN ANDERES PROGRAMM SCHLIESSEN:** Es ist kein Platz frei. Siehe [Kapitel 3](03-programs.md).
