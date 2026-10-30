# 3. Programs

## Starting and ending

A program starts in one of these ways:

- from the Launcher: select it and press RETURN, or click twice
- from the Desktop or the Commander: FILE > RUN
- from another program, such as Studio, which runs whatever you make

Each program has its own menu next to the common VIEW and HELP. It ends from its menu (usually BACK or STOP, CONTROL+Q) and returns to the view it was started from.

## Several programs at once

V-OS programs are of two kinds:

- **Small, with a relocation table:** DEMO, MIXED and CLOCK, the web editor examples (PONG, CATCH, STARCAT, COUNTER), and whatever the [SDK](../../../sdk/README.en.md) makes. They share 12K of memory, and as many as fit run together.
- **Programs that need all the memory:** STUDIO and whatever Studio makes (CALC, MINES, FLAP, TICKER and your own). Without a memory expansion they run on their own. If one is already running, you get "CLOSE ANOTHER PROGRAM FIRST".

When you go to a view (F1–F4) while a program is running:

- A small program stays in memory. You pick it up again from the Launcher (RETURN on it) or with F6, and it resumes exactly where it was.
- A program that has all the memory ends, unless there is a memory expansion.

**F6** (VIEW > PROGRAMS) shows the list of running programs. You choose one with the arrows and RETURN. If none is running, you get "NO PROGRAM IS RUNNING".

**With a memory expansion** (e.g. 512K, which V-OS finds by itself at start-up), every program that needs all the memory gets its own bank. So STUDIO, CALC, DEMO and PONG can all run together.

## In the background

A program behind another one, or behind a view, normally **freezes** and resumes when it comes back to the front.

Some programs ask to **keep running** in the background too, e.g. TICKER, which counts time. While there they do not draw or play sound. When they come back to the front, they have also counted the time they were away.

In Studio you choose this for your program with STUDIO > IN BACKGROUND.

## The desk accessory (ACCESSORY)

A small program, such as CLOCK, can open in a window **on top of anything**: a view or a program.

1. In the Launcher, select CLOCK and choose FILE > AS ACCESSORY (^A).
2. From then on, **F5** opens and closes it, wherever you are. ESC also closes it.

While it is open, it gets the keys and clicks. Its window can be dragged by its title. When it closes, whatever was underneath is redrawn.

## The programs on the disc

| Program | What it is |
|---|---|
| **STUDIO** | the block editor: you make programs on the CPC ([chapter 5](05-studio.md)) |
| **DEMO** | the first V-OS program: a square that moves by itself. The arrows steer it and SPACE changes its color |
| **MIXED** | the "mixed screen": a band with 16 colors (mode 0) between mode 1 bands. A click shows the coordinates |
| **CLOCK** | the time since V-OS started. It also runs as a desk accessory |
| **CALC** | a calculator in a window with buttons, made in Studio (there is also `CALC.VBS`) |
| **MINES** | an 8×6 minesweeper with 8 mines, made in Studio. A click opens a cell, and NEW starts a new game |
| **BRICKS** | brick breaking: a paddle with ←/→, 32 bricks, 3 lives, levels with an ever faster ball. At GAME OVER, SPACE for a new game |
| **VROUVES** | tower defence, from the CPC game LET'S GO FOR VROUVES: 7 stages, from the Kafenio to the cemetery, with 10 waves each. It is on its own disc, `vrouves.dsk`: put it in B: and press TAB in the Launcher. Arrows move the cursor, 1–6 picks a defender, SPACE builds, S sells, N calls the next wave, P pauses. Points for every invader and for the villagers left at the end of a stage. The disc keeps `VROUVES.SAV`: CONTINUE starts from the stage you reached, HIGH SCORES shows the best five with their names. Written with the SDK (`myapps/vrouves`) |
| **NOTEPAD** | a text editor in mode 1, 48×22, for files up to 4K. NEW, OPEN (only `.TXT` files), SAVE, SAVE AS, OTHER DRIVE. Arrows, DEL, CLR and RETURN; a click places the cursor. The bottom line shows the line and the column. EDIT menu: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT and the arrows select. The clipboard (up to 1K) is shared by all programs (`myapps/notepad`) |
| **PAINT** | drawing in mode 0 with 16 colors: a 128×128 picture (`.PIC`), or 64×64 at 2× zoom in 3 layers (`.LYR`, NEW LAYERS). Tools: P pencil, B brush, L line, X box, F fill; TAB changes the color. Arrows and COPY draw without a mouse. Layers: 1–3 choose one, H hides or shows it, U and D move it up and down, E is the eraser (`myapps/paint`) |
| **MUSIC** | plays Arkos Tracker 3 songs (`.MUS`, made by `make songs`), with three volume bars. It is on its own disc, `music.dsk`, in B:. OPEN, SPACE plays and stops. The music goes on behind other views and programs. Studio's MUSIC block starts it behind a program with a song (`myapps/music`) |
| **MARKDOWN** | an editor for Markdown files (`.MD`, up to 6K), like NOTEPAD. ^P shows the page: `#` headings, **bold**, *italic*, `code`, lists, quotes, lines, code blocks and underlined links, without the marks. Lines that follow each other make one paragraph (two spaces at the end break the line). The arrows scroll the page, RETURN or ^P go back to the text. It is on its own disc, `markdown.dsk`, with a `README.MD`. EDIT menu: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT and the arrows select. The clipboard (up to 1K) is shared by all programs (`myapps/markdown`) |
| **SYSINFO** | shows the V-OS and API versions, the memory (all of it and what is free for programs) and the free space on the discs in A: and B: (^R again). An example of `VOS_EXT` (`myapps/sysinfo`) |
| **WEBGET** | downloads files from the web with the M4 board: GET A FILE (^G) asks for an address (HTTP, e.g. `example.com/index.html`) and a name, and the file (up to 16K) is saved on the drive it shows (OTHER DRIVE). It also shows the network status. Without an M4 board: "NO M4 BOARD" (`myapps/webget`) |
| **READER** | reads Markdown pages (`.MD`, up to 6K) from the disc or from the web with the M4 board, shown as in MARKDOWN's preview. TAB selects the next link (inverted), RETURN opens it, DEL goes back to the previous page (it keeps 4). A link without `http://` opens next to the page, on the disc or on the same site. OPEN A FILE and OPEN AN ADDRESS (^U, HTTP, e.g. `example.com/README.md`). `https://` addresses cannot be opened. It is on its own disc, `reader.dsk`, with `INDEX.MD` and `ABOUT.MD` (`myapps/reader`) |
| **PONG** | a ball and a paddle with the arrows, score and lives |
| **CATCH** | catch the falling stars |
| **STARCAT** | a cat with costumes that walks, a star, a melody from a list |
| **COUNTER** | a counter with +1, −1 and 0 buttons, in mode 1 |
| **FLAP** | a bird that flaps its wings (costumes), and a star that changes costume every second |
| **TICKER** | counts seconds and keeps going in the background |

- Block programs are `.VBN` files. They have a PROGRAM > STOP menu (CONTROL+Q).
- Those that also have a `.VBS` (CALC, MINES, FLAP, TICKER) open in Studio so you can look at them or change them.
- `VBRUN.SYS` is not a program: it is the "player" that Studio needs.
