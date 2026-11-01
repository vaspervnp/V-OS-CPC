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
- **Programs that need all the memory:** STUDIO and whatever Studio makes (CALC, MINES, FLAP, TICKER and your own). So are MARKDOWN and READER, which are over 12K. Without a memory expansion they run on their own. If one is already running, you get "CLOSE ANOTHER PROGRAM FIRST".

When you go to a view (F1–F4) while a program is running:

- A small program stays in memory. You pick it up again from the Launcher (RETURN on it) or with F6, and it resumes exactly where it was.
- A program that has all the memory ends, unless there is a memory expansion.

**F6** (VIEW > PROGRAMS) shows the list of running programs. You choose one with the arrows and RETURN. If none is running, you get "NO PROGRAM IS RUNNING".

**With a memory expansion** (e.g. 512K, which V-OS finds by itself at start-up), every program that needs all the memory gets its own bank. So STUDIO, CALC, DEMO and PONG can all run together. Since M43 every program also gets a data bank of its own, 16K, when it needs one: what it keeps there is not lost while other programs or views run.

## In the background

A program behind another one, or behind a view, normally **freezes** and resumes when it comes back to the front.

Some programs ask to **keep running** in the background too, e.g. TICKER, which counts time. While there they do not draw or play sound. When they come back to the front, they have also counted the time they were away.

In Studio you choose this for your program with STUDIO > IN BACKGROUND.

## The desk accessory (ACCESSORY)

A small program, such as CLOCK, can open in a window **on top of anything**: a view or a program.

1. In the Launcher, select CLOCK and choose FILE > AS ACCESSORY (^A).
2. From then on, **F5** opens and closes it, wherever you are. ESC also closes it.

While it is open, it gets the keys and clicks. Its window can be dragged by its title. When it closes, whatever was underneath is redrawn.

## The page (mode 2)

NOTEPAD, MARKDOWN, READER and SHEET have PAGE (MODE 2) in their menu, ^M. The screen goes to mode 2: black text on white paper, 768 pixels across, with the menus and dialogs black on white too. The editors (NOTEPAD and MARKDOWN) show 80 columns between the page's edges, a line where each page of 60 lines ends, and PAGE n in the last line. MARKDOWN's preview and READER show the page in 80 columns with its styles. SHEET shows 10 columns (A–J) with lines between them. ^M again goes back to mode 1.

## The programs on the disc

A CPC disc holds 180K, so V-OS comes on two. `vos.dsk` (A:) has the system, DEMO, MIXED, STUDIO and CLOCK, and the `.VBS` sources of the VB programs, which Studio opens from A:. `apps.dsk` (B:) has the others, from PONG to WEBGET: in the Launcher, TAB shows B:. Some programs have a disc of their own, as the table says.

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
| **NOTEPAD** | a text editor in mode 1, 48×22, for files up to 4K, or up to 16K with a memory expansion: then it keeps about 2.5K around the cursor in its memory and the rest in its own data bank, and SELECT ALL takes that part. NEW, OPEN (only `.TXT` files), SAVE, SAVE AS, OTHER DRIVE. Arrows, DEL, CLR and RETURN; a click places the cursor. The bottom line shows the line and the column. EDIT menu: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT and the arrows select. The clipboard (up to 1K) is shared by all programs (`myapps/notepad`) |
| **PAINT** | drawing in mode 0 with 16 colors: a picture of the whole CPC screen, 160×200 without the overscan (`.SCR`, 16K, which BASIC and other CPC programs load too; without a memory expansion 128×128, `.PIC`), or 64×64 at 2× zoom in 3 layers (`.LYR`, NEW LAYERS). Tools: P pencil, B brush, L line, X box, F fill; TAB changes the color. Arrows and COPY draw without a mouse. The window shows 128×128 of the picture: the bars on its right and under it show which part, and a click or a drag on them moves it. Under the colors: where the pointer is in the picture, and VIEW, the window's top left. Layers: 1–3 choose one, H hides or shows it, U and D move it up and down, E is the eraser. EXPORT .SCR (for the 128×128 picture and the layers; the whole screen is a `.SCR` already): the picture (the layers as they show) as a CPC screen, a 16K `NAME.SCR` (mode 0, in the middle, with the palette), for BASIC or other programs. In BASIC: `MODE 0:LOAD"NAME.SCR",&C000:FOR I=0 TO 15:INK I,PEEK(&C7D0+I):NEXT:BORDER PEEK(&C7E0)` (`myapps/paint`) |
| **MUSIC** | plays Arkos Tracker 3 songs (`.MUS`, made by `make songs`), with three volume bars. It is on its own disc, `music.dsk`, in B:. OPEN, SPACE plays and stops. The music goes on behind other views and programs. Studio's MUSIC block starts it behind a program with a song (`myapps/music`) |
| **MARKDOWN** | an editor for Markdown files (`.MD`, up to 6K), like NOTEPAD. ^P shows the page: `#` headings, **bold**, *italic*, `code`, lists, quotes, lines, code blocks and underlined links, without the marks. Lines that follow each other make one paragraph (two spaces at the end break the line). The arrows scroll the page, RETURN or ^P go back to the text. It is on its own disc, `markdown.dsk`, with a `README.MD`. EDIT menu: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT and the arrows select. The clipboard (up to 1K) is shared by all programs (`myapps/markdown`) |
| **SYSINFO** | shows the V-OS and API versions, the memory (all of it and what is free for programs) and the free space on the discs in A: and B: (^R again). An example of `VOS_EXT` (`myapps/sysinfo`) |
| **WEBGET** | downloads files from the web with the M4 board: GET A FILE (^G) asks for an address (HTTP, e.g. `example.com/index.html`) and a name, and the file (up to 16K) is saved on the drive it shows (OTHER DRIVE). It also shows the network status. Without an M4 board: "NO M4 BOARD" (`myapps/webget`) |
| **READER** | reads Markdown pages (`.MD`, up to 6K) from the disc or from the web with the M4 board, shown as in MARKDOWN's preview. TAB selects the next link (inverted), RETURN opens it, DEL goes back to the previous page (it keeps 4). A link without `http://` opens next to the page, on the disc or on the same site. OPEN A FILE and OPEN AN ADDRESS (^U, HTTP, e.g. `example.com/README.md`). `https://` addresses cannot be opened. It is on its own disc, `reader.dsk`, with `INDEX.MD` and `ABOUT.MD` (`myapps/reader`) |
| **STREETS** | a street index in a V-OS database: type the first letters of a street and see the streets that start so, with their area and post code; DEL takes a letter back. ^A adds a street, ^D deletes the first one in the list. The streets are in `STREETS.VDB` on its disc, `streets.dsk`, in B:; the first time it makes it, with streets of Athens. An example of the database API (`myapps/streets`) Finding ignores capitals, small letters and accents. |
| **DATABASE** | databases, like a small Access: ^N a new database (`NAME.VDB`), ^O open one, ^T a new table (its name, and fields: a name, TEXT up to 40 characters or NUMBER 0–65535, and whether it is sorted by the first one). The list shows a record a row and the fields in columns; the arrows choose and scroll, TAB goes to the next table, and if the table has a key, what you type goes to the records that start so (without case or accents). RETURN opens the form: a field a row, RETURN changes it, ^S saves, ^B back to the list. ^A a new record, ^D delete, ^W the other drive. It opens STREETS's `.VDB` too (`myapps/database`) |
| **SHEET** | a spreadsheet: 16 columns (A–P) and 64 rows, 5 columns and 19 rows on the screen. A cell holds, up to 40 characters, a number (`12`, `-3.5`; the decimal point is a dot), text, or a formula after `=`: `+ - * /`, brackets, cells (`B3`), SUM, AVG, MIN, MAX and COUNT of cells and ranges (`=SUM(B2:B9)`), ABS, INT, ROUND(x, 0–2). Numbers have two decimals, up to ±21474836.46. The arrows move the cursor, RETURN changes the cell, typing starts a new text, DEL (or CLR) empties it; after each change all the formulas are worked out again. The first line shows the cell's text. A cell with an error shows `#ERR`, a number that does not fit `########`. ^N new, ^O open, ^S save, ^A save as (`NAME.VSH`, a text file, a line a cell: `B3 =B1*2`), ^W the other drive. The formulas are worked out by `CALC.SYS` on A:, which any program can use (`VX_CALC`). It is on its own disc, `sheet.dsk`, with the example `BUDGET.VSH` (`myapps/sheet`) |
| **PONG** | a ball and a paddle with the arrows, score and lives |
| **CATCH** | catch the falling stars |
| **STARCAT** | a cat with costumes that walks, a star, a melody from a list |
| **COUNTER** | a counter with +1, −1 and 0 buttons, in mode 1 |
| **FLAP** | a bird that flaps its wings (costumes), and a star that changes costume every second |
| **TICKER** | counts seconds and keeps going in the background |

- Block programs are `.VBN` files. They have a PROGRAM > STOP menu (CONTROL+Q).
- Those that also have a `.VBS` (CALC, MINES, FLAP, TICKER) open in Studio so you can look at them or change them.
- `VBRUN.SYS` is not a program: it is the "player" that Studio needs.
