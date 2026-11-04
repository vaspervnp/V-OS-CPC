# 9. Auf einem echten CPC

V-OS wurde bisher nur in Emulatoren getestet: Caprice32, 1984 und CPCEMU. Ein echter CPC kann sich anders verhalten, beim Diskettenlaufwerk, bei der Tastatur, beim CRTC, beim Monitor oder mit einer AMX-Maus. Dieses Kapitel ist eine Liste von Dingen zum Ausprobieren, und was jedes tun soll. Wenn etwas etwas anderes tut, sag es uns bitte. Auch „alles hat funktioniert“ hilft.

## V-OS auf den CPC bringen

Die Veröffentlichung hat zwei Disketten-Images, `vos.dsk` (A:) und `apps.dsk` (B:). Jedes passt auf eine 3"-Diskette (180K). Einige Wege, sie zu nutzen:

- **Gotek oder HxC** anstelle eines Laufwerks: kopiere die `.dsk`-Dateien auf seinen USB-Stick.
- **Ein 3,5"-PC-Laufwerk**, als Laufwerk B: an den CPC angeschlossen: schreibe die Images auf Disketten (zum Beispiel mit SAMdisk oder DiskImager unter Windows).
- **Eine M4-Karte:** kopiere die Images auf ihre SD-Karte und binde sie über ihr Menü ein.

Dann, in BASIC: `RUN"VOS`.

## Was du zuerst notierst

- Das Modell (CPC 6128 oder 6128 Plus) und, wenn du ihn kennst, den CRTC-Typ (0 bis 4).
- Die Speichererweiterung (keine, 64K, 512K…), die Laufwerke, die Maus, eine M4-Karte.
- Den Monitor (CTM644 Farbe, GT65 grün, ein Fernseher über einen Adapter…).

## Die Liste

Jede Zeile: was du tun sollst, und was du sehen solltest.

**Starten**
- [ ] `RUN"VOS` von A:. Nach wenigen Sekunden: der Schreibtisch, die Menüleiste oben, die Laufwerkssymbole rechts. Nichts flackert oder springt.
- [ ] Das Bild füllt die ganze Röhre (Overscan, 384×272), an den Seiten und unten ist nichts abgeschnitten.
- [ ] HILFE > ÜBER V-OS zeigt die Versionsnummer der Veröffentlichung.
- [ ] SYSINFO (in der Programme-Ansicht, F2) zeigt den Speicher, den du hast.

**Das Diskettenlaufwerk**
- [ ] TAB auf dem Schreibtisch öffnet das Fenster von A:, mit seinen Dateien als Symbole. Ein zweites TAB: B:.
- [ ] Kopiere im Commander (F3) eine Datei von A: nach B: (^C). Verlasse dann V-OS (CONTROL+Q): in BASIC zeigt `CAT` auf B: die Datei, und `LOAD` liest sie.
- [ ] Benenne eine Datei auf B: um (^N) und lösche sie (^D).
- [ ] FORMATIEREN (DATA) im Menü DATEI des Commanders, auf einer Diskette, die du nicht brauchst. Dann `CAT` in BASIC: eine leere Diskette.
- [ ] Auch eine Diskette im SYSTEM-Format (dem von CP/M) wird gelesen.
- [ ] Optionen (F4): ändere die SPRACHE, ^S. Starte erneut mit `RUN"VOS`: V-OS startet in dieser Sprache.
- [ ] Ohne Diskette in B: sagt der Commander das, und V-OS hängt sich nicht auf.

**Die Tastatur**
- [ ] Jede Taste in NOTEPAD: Buchstaben, Ziffern, Zeichen, SHIFT, CAPS LOCK, die Pfeiltasten, DEL, CLR, COPY.
- [ ] CONTROL+SHIFT wechselt die Tastatursprache (EN, ΕΛ, …, rechts in der Menüleiste). Griechische Buchstaben und Umlaute kommen richtig heraus.
- [ ] Eine gehaltene Taste wiederholt sich im Tempo von VERZÖGERUNG und WIEDERHOLRATE in den Optionen.
- [ ] Die Funktionstasten: F1 Schreibtisch, F2 Programme, F3 Commander, F4 Optionen, F6 die laufenden Programme.

**Die AMX-Maus**
- [ ] Optionen: AMX-MAUS auf AN. Der Zeiger folgt der Maus waagrecht und senkrecht gleich schnell, in Modus 1 (der Schreibtisch) und in Modus 0 (die Programme-Ansicht).
- [ ] Springt er oder läuft er in die falsche Richtung, versuche den anderen Wert von AMX-LESEART.
- [ ] Linke Taste: ein Klick; auf dem Titel eines Fensters verschiebt sie es; an der Ecke unten rechts ändert sie seine Größe.

**Speicher**
- [ ] Ohne Erweiterung: NOTEPAD und PONG zusammen, mit F6 hin und her; STUDIO läuft allein.
- [ ] Mit Erweiterung: vier Programme gleichzeitig, jedes da, wo du es verlassen hast. PAINT mit einem großen Bild. Ein Bild auf dem Schreibtisch (Optionen, HINTERGRUNDBILD).

**Der Bildschirm**
- [ ] PAINT und die Programme-Ansicht in Modus 0 (16 Farben): die Farben stimmen.
- [ ] READER oder NOTEPAD mit einer Seite in Modus 2 (80 Spalten): lesbar, auch auf einem Farbmonitor.
- [ ] Der gemischte Bildschirm von Studio (Modus 0 oben, Modus 1 unten): die Trennlinie bleibt still, nichts flackert.
- [ ] Das dunkle Design (Optionen, DESIGN).

**Ton**
- [ ] MUSIC spielt ein Lied; es spielt weiter, während du zum Schreibtisch gehst und ein anderes Programm startest.
- [ ] Die Spiele (VROUVES, BRICKS, PONG) haben ihre Töne.

**Die M4-Karte** (wenn du eine hast)
- [ ] TAB auf dem Schreibtisch geht von B: weiter zu DISK, der SD-Karte, mit ihren Ordnern.
- [ ] NOTEPAD speichert eine Datei auf DISK und öffnet sie wieder.
- [ ] WEBGET lädt eine Datei herunter; READER öffnet eine Seite aus dem Web.

**Geschwindigkeit** (wie lange, mit einer Uhr)
- [ ] Von `RUN"VOS` bis zum Schreibtisch.
- [ ] Von F2 bis zur Programme-Ansicht, und vom Symbol eines Programms bis zum Programm.
- [ ] SHEET: BUDGET.VSH geöffnet und berechnet.

## Uns Bescheid geben

Öffne ein Issue auf <https://github.com/vaspervnp/V-OS-CPC/issues> mit:

- dem, was du zuerst notiert hast (das Modell, der Speicher, der Monitor…);
- den Zeilen, die etwas anderes getan haben, und was sie getan haben;
- einem Foto des Bildschirms, wenn etwas falsch aussieht.
