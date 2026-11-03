#!/usr/bin/env python3
"""demo - the V-OS demo for the videos: the keys (DEMO.KEY, played by the
-DDEMO build, src/kernel/demo.asm) and the captions, in the six languages.

usage: demo.py DEMO.KEY captions.json

One disc in A: (CPCEMU 2.5 for Linux has no drive B:): tools/video/
record.py makes it from build/demo_sys.dsk (make demo-sys) and the files
of APPS, in this order (the Launcher's), records the demo in CPCEMU
(576K, M4) and puts the captions on it. Times are frames (50 a second) from V-OS's start.
The keys are the same in every language: arrows, RETURN, ESC, F-keys
and CONTROL+letters, never a menu's text.
"""
import json
import struct
import sys

# the CPC's keyboard matrix: name -> (line, bit)
MATRIX = {}
for line, names in enumerate([
        ["UP", "RIGHT", "DOWN", "f9", "f6", "f3", "ENTER", "f."],
        ["LEFT", "COPY", "f7", "f8", "f5", "f1", "f2", "f0"],
        ["CLR", "[", "RETURN", "]", "f4", "SHIFT", "\\", "CONTROL"],
        ["^", "-", "@", "p", ";", ":", "/", "."],
        ["0", "9", "o", "i", "l", "k", "m", ","],
        ["8", "7", "u", "y", "h", "j", "n", " "],
        ["6", "5", "r", "t", "g", "f", "b", "v"],
        ["4", "3", "e", "w", "s", "d", "c", "x"],
        ["1", "2", "ESC", "q", "TAB", "a", "CAPS", "z"],
        ["J0", "J1", "J2", "J3", "J4", "J5", "J6", "DEL"]]):
    for bit, name in enumerate(names):
        MATRIX[name] = (line, 1 << bit)
SHIFTED = {"=": "-", "+": ";", "*": ":", "(": "8", ")": "9", "\"": "2",
           "!": "1", "?": "/", ">": ".", "<": ","}

# the programs, in the Launcher's order (the disc's catalog), with the
# files that go with them (build/ or myapps/*/owndisc/); DISC.BAS first,
# where AMSDOS reads it (record.py)
APPS = [                    # part 1, then part 2: a disc each (180K)
    [("DISC", []),                      # DISC.BAS: CPCEMU starts V-OS
     ("DEMO", ["DEMO.BIN"]), ("STUDIO", ["STUDIO.BIN"]),
     ("CLOCK", ["CLOCK.BIN"]), ("PONG", ["PONG.VBN"]),
     ("CALC", ["CALC.VBN"]), ("MINES", ["MINES.VBN"]),
     ("BRICKS", ["BRICKS.VBN"]), ("NOTEPAD", ["NOTEPAD.BIN"]),
     ("PAINT", ["PAINT.BIN"]),
     ("MUSIC", ["MUSIC.BIN", "music/CPCDREAM.MUS"]),
     ("VROUVES", ["VROUVES.BIN", "vrouves/VROUV1.DAT"])],
    [("DISC", []),
     ("MARKDOWN", ["MARKDOWN.BIN", "markdown/README.MD"]),
     ("READER", ["READER.BIN", "reader/INDEX.MD", "reader/ABOUT.MD"]),
     ("WEBGET", ["WEBGET.BIN"]), ("SYSINFO", ["SYSINFO.BIN"]),
     ("STREETS", ["STREETS.BIN"]), ("DATABASE", ["DATABASE.BIN"]),
     ("SHEET", ["SHEET.BIN", "sheet/BUDGET.VSH"])]]

LANGS = ["en", "el", "fr", "es", "de", "it"]


class Demo:
    def __init__(self, apps):
        self.names = [name for name, _ in apps]
        self.t = 0
        self.keys = []          # (frame, held, line, bits)
        self.captions = []      # [start, end, {lang: text}]

    def wait(self, seconds):
        self.t += int(seconds * 50)

    def raw(self, frame, held, line, bits):
        self.keys.append((frame, held, line, bits))

    def key(self, name, gap=0.3, held=4):
        line, bits = MATRIX[name]
        self.raw(self.t, held, line, bits)
        self.wait(gap)

    def hold(self, name, seconds, gap=0.2):
        line, bits = MATRIX[name]
        frames = int(seconds * 50)
        while frames > 0:
            n = min(frames, 250)
            self.raw(self.t, n, line, bits)
            self.t += n
            frames -= n
        self.wait(gap)

    def ctrl(self, letter, gap=1.0):
        line, bits = MATRIX["CONTROL"]
        self.raw(self.t, 15, line, bits)
        self.t += 5
        self.key(letter, gap)

    def shift(self, name, gap=0.15):
        line, bits = MATRIX["SHIFT"]
        self.raw(self.t, 8, line, bits)
        self.t += 2
        self.key(name, max(gap, 0.2))

    def type(self, text, gap=0.15):
        for ch in text:
            if ch in SHIFTED:
                self.shift(SHIFTED[ch], gap)
            elif ch.isupper():
                self.shift(ch.lower(), gap)
            elif ch == "\n":
                self.key("RETURN", gap)
            else:
                self.key(ch, gap)

    def caption(self, texts, sync=True):
        """A caption from now until the next one. sync: its first key
        changes the whole screen (a view, a program, a mode), where
        record.py puts it in the video (the demo's frames stop while the
        disc works, so they fall behind the video's time)."""
        assert set(texts) == set(LANGS), texts
        if self.captions and self.captions[-1][1] is None:
            self.captions[-1][1] = self.t
        self.captions.append([self.t, None, texts, sync])

    def launch(self, name, gap=5.0):
        """F2, the program's tile, RETURN."""
        self.key("f2", 1.5)
        for _ in range(8):              # to the first tile
            self.key("UP", 0.12)
        for _ in range(3):
            self.key("LEFT", 0.12)
        index = self.names.index(name)
        self.wait(0.3)
        for _ in range(index // 3):
            self.key("DOWN", 0.35)
        for _ in range(index % 3):
            self.key("RIGHT", 0.35)
        self.wait(0.6)
        self.key("RETURN", gap)

    def done(self):
        if self.captions and self.captions[-1][1] is None:
            self.captions[-1][1] = self.t
        self.keys.sort()


def part1():
    d = Demo(APPS[0])
    C = d.caption
    d.wait(6)                           # the start, the Desktop
    C({"en": "V-OS: a graphical operating system for the Amstrad CPC 6128",
       "el": "V-OS: ένα γραφικό λειτουργικό σύστημα για τον Amstrad CPC 6128",
       "fr": "V-OS : un système d'exploitation graphique pour l'Amstrad CPC 6128",
       "es": "V-OS: un sistema operativo gráfico para el Amstrad CPC 6128",
       "de": "V-OS: ein grafisches Betriebssystem für den Amstrad CPC 6128",
       "it": "V-OS: un sistema operativo grafico per l'Amstrad CPC 6128"}, False)
    d.wait(5)
    C({"en": "Here with a 512K memory expansion (576K) and the M4 board",
       "el": "Εδώ με επέκταση μνήμης 512K (576K) και την κάρτα M4",
       "fr": "Ici avec une extension mémoire de 512K (576K) et la carte M4",
       "es": "Aquí con una ampliación de memoria de 512K (576K) y la tarjeta M4",
       "de": "Hier mit einer 512K-Speichererweiterung (576K) und der M4-Karte",
       "it": "Qui con un'espansione di memoria da 512K (576K) e la scheda M4"}, False)
    d.wait(5)

    # ---- the views
    C({"en": "The Desktop (f1): a window with the files of a drive as icons",
       "el": "Η Επιφάνεια (f1): ένα παράθυρο με τα αρχεία μιας μονάδας ως εικονίδια",
       "fr": "Le Bureau (f1) : une fenêtre avec les fichiers d'un lecteur en icônes",
       "es": "El Escritorio (f1): una ventana con los archivos de una unidad como iconos",
       "de": "Der Desktop (f1): ein Fenster mit den Dateien eines Laufwerks als Symbolen",
       "it": "Il Desktop (f1): una finestra con i file di un'unità come icone"}, False)
    d.key("TAB", 2.0)                   # at first no window: A:
    for _ in range(5):
        d.key("RIGHT", 0.5)
    d.key("DOWN", 0.8)
    d.hold("DOWN", 1.0, 1.0)
    d.ctrl("k", 3.5)                    # the keys dialog
    d.key("RETURN", 1.5)
    C({"en": "The Commander (f3): two drives side by side, copy, rename, delete",
       "el": "Ο Διαχειριστής (f3): δύο μονάδες δίπλα δίπλα, αντιγραφή, μετονομασία, διαγραφή",
       "fr": "Le Commander (f3) : deux lecteurs côte à côte, copier, renommer, effacer",
       "es": "El Commander (f3): dos unidades lado a lado, copiar, renombrar, borrar",
       "de": "Der Commander (f3): zwei Laufwerke nebeneinander, kopieren, umbenennen, löschen",
       "it": "Il Commander (f3): due unità affiancate, copiare, rinominare, cancellare"})
    d.key("f3", 2.0)
    d.hold("DOWN", 2.5, 2.0)
    C({"en": "Setup (f4): language, keyboards, key repeat, mouse, colours",
       "el": "Ρυθμίσεις (f4): γλώσσα, πληκτρολόγια, επανάληψη πλήκτρων, ποντίκι, χρώματα",
       "fr": "Réglages (f4) : langue, claviers, répétition, souris, couleurs",
       "es": "Ajustes (f4): idioma, teclados, repetición, ratón, colores",
       "de": "Einstellungen (f4): Sprache, Tastaturen, Wiederholung, Maus, Farben",
       "it": "Impostazioni (f4): lingua, tastiere, ripetizione, mouse, colori"})
    d.key("f4", 2.0)
    for _ in range(6):
        d.key("DOWN", 0.6)
    d.wait(1.5)
    C({"en": "The Launcher (f2): the programs of a drive, with their icons",
       "el": "Ο Εκκινητής (f2): τα προγράμματα μιας μονάδας, με τα εικονίδιά τους",
       "fr": "Le Lanceur (f2) : les programmes d'un lecteur, avec leurs icônes",
       "es": "El Lanzador (f2): los programas de una unidad, con sus iconos",
       "de": "Der Launcher (f2): die Programme eines Laufwerks, mit ihren Symbolen",
       "it": "Il Launcher (f2): i programmi di un'unità, con le loro icone"})
    d.key("f2", 2.0)
    for _ in range(4):
        d.key("RIGHT", 0.5)
    for _ in range(5):
        d.key("DOWN", 0.7)
    d.wait(1.0)

    # ---- several programs, the switcher, the accessory
    C({"en": "Programs run side by side; with more RAM each gets a bank of its own",
       "el": "Τα προγράμματα τρέχουν δίπλα δίπλα· με επέκταση το καθένα έχει δική του bank",
       "fr": "Les programmes tournent côte à côte ; avec plus de RAM, chacun a sa banque",
       "es": "Los programas funcionan a la vez; con más RAM cada uno tiene su banco",
       "de": "Programme laufen nebeneinander; mit mehr RAM hat jedes seine eigene Bank",
       "it": "I programmi girano insieme; con più RAM ognuno ha il suo banco"})
    d.launch("DEMO", 2.5)
    d.key(" ", 1.0)
    d.key(" ", 1.5)
    d.launch("PONG", 2.0)
    d.hold("UP", 0.6, 0.2)
    d.hold("DOWN", 0.8, 1.5)
    d.launch("MINES", 5.0)
    C({"en": "f6: the programs that run; any of them goes on where it was",
       "el": "f6: τα προγράμματα που τρέχουν· όποιο διαλέξεις συνεχίζει από εκεί που ήταν",
       "fr": "f6 : les programmes en cours ; chacun reprend là où il en était",
       "es": "f6: los programas en marcha; cualquiera sigue donde estaba",
       "de": "f6: die laufenden Programme; jedes macht dort weiter, wo es war",
       "it": "f6: i programmi in esecuzione; ognuno riprende da dove era"})
    d.key("f6", 2.5)
    d.key("DOWN", 1.0)
    d.key("RETURN", 3.0)                # PONG again
    d.key("f6", 2.0)
    d.key("RETURN", 3.0)                # DEMO
    C({"en": "A desk accessory (CLOCK) opens over anything with f5",
       "el": "Ένα αξεσουάρ (CLOCK) ανοίγει πάνω από οτιδήποτε με το f5",
       "fr": "Un accessoire (CLOCK) s'ouvre par-dessus tout avec f5",
       "es": "Un accesorio (CLOCK) se abre sobre cualquier cosa con f5",
       "de": "Ein Zubehör (CLOCK) öffnet sich mit f5 über allem",
       "it": "Un accessorio (CLOCK) si apre sopra qualsiasi cosa con f5"})
    d.key("f2", 1.5)
    for _ in range(8):
        d.key("UP", 0.12)
    for _ in range(3):
        d.key("LEFT", 0.12)
    for _ in range(d.names.index("CLOCK")):
        d.key("RIGHT", 0.4)
    d.wait(0.6)
    d.ctrl("a", 4.0)                    # FILE > AS ACCESSORY
    d.key("f5", 2.0)                    # closed
    d.key("f6", 2.0)
    d.key("RETURN", 2.5)                # a program in front
    d.key("f5", 4.0)                    # the clock over it
    d.key("f5", 1.5)

    # ---- Studio and the block programs
    C({"en": "STUDIO: programs made of blocks, like Scratch, run by VBRUN",
       "el": "STUDIO: προγράμματα από τουβλάκια, όπως το Scratch, τα τρέχει το VBRUN",
       "fr": "STUDIO : des programmes en blocs, comme Scratch, lancés par VBRUN",
       "es": "STUDIO: programas hechos de bloques, como Scratch, que ejecuta VBRUN",
       "de": "STUDIO: Programme aus Blöcken, wie Scratch, ausgeführt von VBRUN",
       "it": "STUDIO: programmi fatti di blocchi, come Scratch, eseguiti da VBRUN"})
    d.launch("STUDIO", 4.0)
    d.key("DOWN", 0.8)
    d.key("RIGHT", 0.8)
    d.key("5", 1.0)
    d.key("TAB", 1.0)
    for _ in range(3):
        d.key("DOWN", 0.6)
    d.key("TAB", 1.0)
    d.hold("RIGHT", 0.8, 1.0)
    d.key("c", 1.5)
    d.key("TAB", 2.0)
    C({"en": "Games and examples made in Studio: CALC, MINES, BRICKS ...",
       "el": "Παιχνίδια και παραδείγματα φτιαγμένα στο Studio: CALC, MINES, BRICKS ...",
       "fr": "Jeux et exemples faits dans Studio : CALC, MINES, BRICKS ...",
       "es": "Juegos y ejemplos hechos en Studio: CALC, MINES, BRICKS ...",
       "de": "Spiele und Beispiele aus Studio: CALC, MINES, BRICKS ...",
       "it": "Giochi ed esempi fatti in Studio: CALC, MINES, BRICKS ..."})
    d.launch("CALC", 4.0)
    d.launch("MINES", 4.0)
    d.launch("BRICKS", 2.0)
    d.hold("RIGHT", 0.8, 0.5)
    d.hold("LEFT", 1.2, 0.5)
    d.hold("RIGHT", 0.6, 3.0)

    # ---- text: NOTEPAD and the page
    C({"en": "NOTEPAD: text files up to 16K with more RAM, Greek and Latin letters",
       "el": "NOTEPAD: κείμενα ως 16K με επέκταση, ελληνικά και λατινικά γράμματα",
       "fr": "NOTEPAD : des textes jusqu'à 16K avec plus de RAM, lettres grecques et latines",
       "es": "NOTEPAD: textos de hasta 16K con más RAM, letras griegas y latinas",
       "de": "NOTEPAD: Texte bis 16K mit mehr RAM, griechische und lateinische Buchstaben",
       "it": "NOTEPAD: testi fino a 16K con più RAM, lettere greche e latine"})
    d.launch("NOTEPAD", 3.0)
    d.type("Dear friends,\n\nV-OS runs on a CPC 6128 from 1985.\n"
           "It has windows, menus, a mouse pointer and many programs.\n")
    d.wait(1.0)
    C({"en": "^M: the page in mode 2, 80 columns, black on white, with its pages",
       "el": "^M: η σελίδα σε mode 2, 80 στήλες, μαύρα σε λευκό, με τις σελίδες της",
       "fr": "^M : la page en mode 2, 80 colonnes, noir sur blanc, avec ses pages",
       "es": "^M: la página en modo 2, 80 columnas, negro sobre blanco, con sus páginas",
       "de": "^M: die Seite in Modus 2, 80 Spalten, schwarz auf weiß, mit ihren Seiten",
       "it": "^M: la pagina in modo 2, 80 colonne, nero su bianco, con le sue pagine"})
    d.ctrl("m", 2.0)
    d.type("In mode 2 a line holds eighty characters, as on paper.\n")
    d.hold("RETURN", 4.0, 1.0)
    d.type("A new page starts after line sixty.\n", 0.12)
    d.wait(2.0)
    d.ctrl("m", 2.0)                    # NOTEPAD goes on behind

    # ---- PAINT
    C({"en": "PAINT: the whole CPC screen, 160 x 200, 16 colours, tools and layers",
       "el": "PAINT: όλη η οθόνη του CPC, 160 x 200, 16 χρώματα, εργαλεία και επίπεδα",
       "fr": "PAINT : tout l'écran du CPC, 160 x 200, 16 couleurs, outils et calques",
       "es": "PAINT: toda la pantalla del CPC, 160 x 200, 16 colores, herramientas y capas",
       "de": "PAINT: der ganze CPC-Bildschirm, 160 x 200, 16 Farben, Werkzeuge, Ebenen",
       "it": "PAINT: tutto lo schermo del CPC, 160 x 200, 16 colori, strumenti e livelli"})
    d.launch("PAINT", 6.0)
    d.raw(d.t, 2, 0x81, 30)             # the pointer on the picture
    d.raw(d.t, 2, 0x82, 140)
    d.wait(0.5)
    for _ in range(3):
        d.key("TAB", 0.3)
    line, bits = MATRIX["COPY"]         # held arrows speed up: short
    d.raw(d.t, 50, line, bits)          # holds, not to reach the menus
    d.hold("UP", 0.5, 1.2)
    d.key("x", 0.3)
    d.key("TAB", 0.3)
    d.raw(d.t, 50, line, bits)
    d.hold("LEFT", 0.5, 1.2)
    d.key("f", 0.3)
    d.key("TAB", 0.3)
    d.key("COPY", 3.0)
    C({"en": "The window moves with its scroll bars; the pointer's place and the window's",
       "el": "Το παράθυρο κινείται με τις μπάρες του· η θέση του pointer και του παραθύρου",
       "fr": "La fenêtre bouge avec ses barres ; la place du pointeur et celle de la fenêtre",
       "es": "La ventana se mueve con sus barras; la posición del puntero y de la ventana",
       "de": "Das Fenster bewegt sich mit seinen Leisten; Zeiger- und Fensterposition",
       "it": "La finestra si muove con le sue barre; la posizione del puntatore e della finestra"},
      sync=False)
    d.raw(d.t, 2, 0x81, 65)             # the bar on the right, near its
    d.raw(d.t, 2, 0x82, 140)            # bottom
    d.wait(0.3)
    d.key("COPY", 2.5)
    d.raw(d.t, 2, 0x81, 60)             # the bar below, at its right
    d.raw(d.t, 2, 0x82, 147)
    d.wait(0.3)
    d.key("COPY", 2.5)
    d.raw(d.t, 2, 0x81, 30)             # the pointer back on the picture
    d.raw(d.t, 2, 0x82, 80)
    d.wait(0.3)
    d.hold("RIGHT", 0.4, 2.5)

    # ---- music and a game
    C({"en": "MUSIC: Arkos Tracker songs, which go on behind other programs",
       "el": "MUSIC: τραγούδια του Arkos Tracker, που συνεχίζουν πίσω από άλλα προγράμματα",
       "fr": "MUSIC : des chansons Arkos Tracker, qui continuent derrière les autres programmes",
       "es": "MUSIC: canciones de Arkos Tracker, que siguen detrás de otros programas",
       "de": "MUSIC: Arkos-Tracker-Lieder, die hinter anderen Programmen weiterlaufen",
       "it": "MUSIC: brani di Arkos Tracker, che continuano dietro gli altri programmi"})
    d.launch("MUSIC", 5.0)
    d.ctrl("o", 2.0)
    d.key("RETURN", 6.0)
    C({"en": "VROUVES: a tower defence game, written with the SDK in assembly",
       "el": "VROUVES: ένα παιχνίδι tower defence, γραμμένο με το SDK σε assembly",
       "fr": "VROUVES : un jeu de tower defence, écrit avec le SDK en assembleur",
       "es": "VROUVES: un juego de tower defence, escrito con el SDK en ensamblador",
       "de": "VROUVES: ein Tower-Defence-Spiel, in Assembler mit dem SDK geschrieben",
       "it": "VROUVES: un gioco tower defence, scritto con l'SDK in assembly"})
    d.launch("VROUVES", 4.0)
    d.key(" ", 0.8)
    d.key("UP", 0.4)
    d.key("4", 0.4)
    d.key(" ", 0.8)
    d.key("n", 12.0)
    d.ctrl("q", 2.0)
    d.launch("MUSIC", 2.0)
    d.key(" ", 1.5)                     # stop
    d.ctrl("q", 1.0)

    d.done()
    return d


def part2():
    d = Demo(APPS[1])
    C = d.caption
    d.wait(4)
    # ---- MARKDOWN and READER
    C({"en": "MARKDOWN: an editor for .MD files with a preview of the page",
       "el": "MARKDOWN: ένας editor για αρχεία .MD με προεπισκόπηση της σελίδας",
       "fr": "MARKDOWN : un éditeur de fichiers .MD avec l'aperçu de la page",
       "es": "MARKDOWN: un editor de archivos .MD con vista previa de la página",
       "de": "MARKDOWN: ein Editor für .MD-Dateien mit einer Vorschau der Seite",
       "it": "MARKDOWN: un editor per file .MD con l'anteprima della pagina"})
    d.launch("MARKDOWN", 3.0)
    d.ctrl("o", 2.0)
    d.key("RETURN", 3.0)                # README.MD
    d.ctrl("p", 4.0)                    # the preview
    d.key("RIGHT", 3.0)
    d.ctrl("m", 5.0)                    # the page
    d.ctrl("m", 2.0)
    C({"en": "READER: Markdown pages from the disc, or from the web with the M4 board",
       "el": "READER: σελίδες Markdown από τη δισκέτα, ή από το web με την κάρτα M4",
       "fr": "READER : des pages Markdown de la disquette, ou du web avec la carte M4",
       "es": "READER: páginas Markdown del disquete, o de la web con la tarjeta M4",
       "de": "READER: Markdown-Seiten von der Diskette oder aus dem Web mit der M4-Karte",
       "it": "READER: pagine Markdown dal dischetto, o dal web con la scheda M4"})
    d.launch("READER", 4.0)
    d.key("TAB", 1.5)
    d.key("RETURN", 3.0)                # ABOUT.MD
    d.key("DEL", 3.0)                   # back
    d.ctrl("m", 4.0)                    # the page
    d.ctrl("m", 1.5)

    C({"en": "SYSINFO: the version, the memory and the free space on the discs",
       "el": "SYSINFO: η έκδοση, η μνήμη και ο ελεύθερος χώρος στις δισκέτες",
       "fr": "SYSINFO : la version, la mémoire et la place libre sur les disquettes",
       "es": "SYSINFO: la versión, la memoria y el espacio libre en los disquetes",
       "de": "SYSINFO: die Version, der Speicher und der freie Platz auf den Disketten",
       "it": "SYSINFO: la versione, la memoria e lo spazio libero sui dischetti"})
    d.launch("SYSINFO", 5.0)
    d.ctrl("q", 1.0)

    # ---- data: DATABASE, SHEET. STREETS is not shown: in the 1984
    # emulator its list puts an FF at #B1FC, where 1984 looks for the
    # 464 firmware's palette, and the screen turns one colour. Its
    # STREETS.VDB (tools/video, made by STREETS) is on the disc instead.
    C({"en": "DATABASE: tables, fields, a list and a form, like a small Access",
       "el": "DATABASE: πίνακες, πεδία, λίστα και φόρμα, όπως μια μικρή Access",
       "fr": "DATABASE : tables, champs, liste et formulaire, comme un petit Access",
       "es": "DATABASE: tablas, campos, lista y formulario, como un pequeño Access",
       "de": "DATABASE: Tabellen, Felder, Liste und Formular, wie ein kleines Access",
       "it": "DATABASE: tabelle, campi, elenco e modulo, come un piccolo Access"})
    d.launch("DATABASE", 3.0)
    d.ctrl("o", 2.0)
    d.key("RETURN", 4.0)                # STREETS.VDB
    for _ in range(4):
        d.key("DOWN", 0.5)
    d.key("RETURN", 3.0)                # the form
    d.ctrl("b", 2.0)
    d.ctrl("q", 1.0)
    C({"en": "SHEET: a spreadsheet; its formulas come from CALC.SYS, open to every program",
       "el": "SHEET: λογιστικό φύλλο· τους τύπους τους υπολογίζει το CALC.SYS, για κάθε πρόγραμμα",
       "fr": "SHEET : un tableur ; ses formules viennent de CALC.SYS, ouvert à tout programme",
       "es": "SHEET: una hoja de cálculo; sus fórmulas las calcula CALC.SYS, para todo programa",
       "de": "SHEET: eine Tabellenkalkulation; ihre Formeln rechnet CALC.SYS, für jedes Programm",
       "it": "SHEET: un foglio di calcolo; le formule le calcola CALC.SYS, per ogni programma"})
    d.launch("SHEET", 3.0)
    d.ctrl("o", 2.0)
    d.key("RETURN", 4.0)                # BUDGET.VSH
    for _ in range(3):
        d.key("DOWN", 0.4)
    d.key("RIGHT", 0.4)
    d.key("RIGHT", 1.0)
    d.ctrl("m", 4.0)                    # the page: 10 columns
    d.type("=sum(b2:b4)\n", 0.2)
    d.wait(2.5)
    d.ctrl("m", 2.0)

    # ---- the M4 board: its network (a download did not finish in CPCEMU)
    C({"en": "WEBGET: the M4 board's network; it downloads files from the web",
       "el": "WEBGET: το δίκτυο της κάρτας M4· κατεβάζει αρχεία από το web",
       "fr": "WEBGET : le réseau de la carte M4 ; il télécharge des fichiers du web",
       "es": "WEBGET: la red de la tarjeta M4; descarga archivos de la web",
       "de": "WEBGET: das Netz der M4-Karte; es lädt Dateien aus dem Web",
       "it": "WEBGET: la rete della scheda M4; scarica file dal web"})
    d.launch("WEBGET", 7.0)
    C({"en": "V-OS: open source, with an SDK for your own programs (github.com/vaspervnp/V-OS-CPC)",
       "el": "V-OS: ανοιχτός κώδικας, με SDK για τα δικά σας προγράμματα (github.com/vaspervnp/V-OS-CPC)",
       "fr": "V-OS : open source, avec un SDK pour vos programmes (github.com/vaspervnp/V-OS-CPC)",
       "es": "V-OS: código abierto, con un SDK para sus programas (github.com/vaspervnp/V-OS-CPC)",
       "de": "V-OS: Open Source, mit einem SDK für eigene Programme (github.com/vaspervnp/V-OS-CPC)",
       "it": "V-OS: open source, con un SDK per i tuoi programmi (github.com/vaspervnp/V-OS-CPC)"})
    d.key("f1", 6.0)
    d.done()
    return d


def main():
    """DEMO.KEY -> DEMO1.KEY and DEMO2.KEY beside it; the captions of
    both parts in one file."""
    parts = []
    for n, d in enumerate((part1(), part2()), 1):
        with open(sys.argv[1].replace("DEMO.KEY", f"DEMO{n}.KEY"), "wb") as f:
            for frame, held, line, bits in d.keys:
                f.write(struct.pack("<HBBB", frame, held, line, bits))
            f.write(b"\xff\xff")
        parts.append({"frames": d.t, "captions": d.captions, "apps": APPS[n - 1]})
        print(f"demo part {n}: {len(d.keys)} keys, {d.t / 50 / 60:.1f} minutes, "
              f"{len(d.captions)} captions, {len(d.keys) * 5 + 2} bytes")
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump({"parts": parts}, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
