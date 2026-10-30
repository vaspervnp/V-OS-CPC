# V-OS milestones

*Στα ελληνικά: [MILESTONES.el.md](MILESTONES.el.md).*

What each milestone added, the bugs found on the way, and what was tested and what was not, newest first. The design and the implementation details are in [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md).

**M41 (Studio: text styles and music; version 0.12):**
- **STYLE *n*:** a new block in LOOKS/SOUND. The PRINT and TEXT that follow are bold (1), italic (2), underlined (4), or those added together; 0 is plain. Also `text_style` for `vbc.py` and the web editor.
- **MUSIC *"name"*:** plays *name*`.MUS` from the program's disc behind it, with the MUSIC program from A: or B:. It is started only when the name changes, so a MUSIC inside FOREVER does not keep the disc busy. MUSIC goes on after the program ends; F6 brings it to the front. On a 6128 without an expansion there is no room beside a block program: "CLOSE ANOTHER PROGRAM FIRST". Also `music` for `vbc.py` and the web editor.
- **API 19, `VX_BEHIND`:** DE -> a file. In the main loop the kernel starts its program (by type, as the Desktop does) behind the caller, or finds it running, and calls its `init` with A = 3 and the file in `VOS_OPEN`: it takes the file and calls `VOS_BACKGROUND`, without drawing anything. MUSIC knows A = 3, and keeps playing when it gets the song it is already playing.
- **Room in the kernel:** a second kernel extension, `src/kernel/ext2.asm`, in base RAM bank 1 at #4100, which nothing used after boot (VOS.BIN is loaded there). The loader copies it there; `ext2_call` runs it. `VX_BEHIND`'s work is there. The screen set-up (`gfx_init`, the CRTC table, the black palette) moved to the loader: 124 bytes out of the kernel.
- **The tests fit again:** since M38 the kernel had grown, and the test builds of `test-calc`, `test-mines`, `test-switch` and seven others no longer assembled (not noticed then). The test scripts now live in the second extension too (the interrupt maps it in for a moment), and a key entry takes 5 bytes instead of 6. All 27 test builds assemble.
- **Studio and the player:** Studio's block table packs its default slots in 6 bytes (their high byte is always 0), which gave it the room for the two blocks. The player (VBRUN.SYS) leaves out the list routines, which only `vbc.py` programs use.
- **Bugs found:** `rt_music` filled 256 bytes instead of 8 (B was 0); `slot_find` left carry set when it found nothing, which `VX_BEHIND` took for an error; and `ext2_call`, put between `view_programs` and `ext_call`, broke F6, which falls through into `ext_call` (found by `test-switch`).
- **Tested** in Caprice32:
  - `test-styles`: STYLES.VBN shows plain, bold, italic, underline, all three, a number in bold italic, and plain again.
  - `test-music-block` (576K): TUNE.VBN starts MUSIC behind it with AGANAMEM.MUS; F6 shows "> TUNE" and MUSIC, and RETURN brings MUSIC to the front: A:AGANAMEM, PLAYING, the bars moving. With 128K: "CLOSE ANOTHER PROGRAM FIRST", and TUNE goes on.
  - `test-calc` (Studio with the packed table adds WINDOW "hi" 120 100), `test-mines`, `test-switch`, `test-sysinfo` (0.12, API 19), `test-markdown`, `test-reader`, `test-about`, and again `test-input`, `test-lang`, `test-langs`, `test-costume`, `test-acc`, `test-expand`, `test-behind`, `test-drag`, `test-bricks`, `test-sdk`, `test-vrouves`, `test-music`, `test-clip`, `test-open`, `test-paint`, `test-notepad`, `test-vars`, `test-multi`, `test-amsdos`, `test-reboot`, `test-system`.
- **Not tested:** on a real CPC.

**M40 (paragraphs and faster scrolling in MARKDOWN; version 0.11):**
- **Paragraphs:** in MARKDOWN's page and READER, lines that follow each other make one paragraph, as Markdown means them, and wrap together. Two spaces at the end of a line break it there. A list item's next lines go on in the item, and `>` lines in the quote. A blank line, a heading, a list item, a quote, a line or a code block start something new.
- **Faster scrolling:** the page used to be read from the text's start on every scroll. Now it keeps up to 64 checkpoints (where a text line starts, every 8 page lines or so, with the code-block state and the link count) and starts from the last one above the screen. A new text forgets them (`pv_new`).
- **Version:** V-OS is 0.11. From now on each milestone adds 0.01. `VOS_VERSION` is in `src/version.inc`, and the About dialog takes it from there (`{VERSION}` in the texts, like `{DATE}`).
- **Test fixed:** `test-markdown` had not shown the page for some milestones. Its shots came after the RETURN that goes back to the text. The keys are now further apart (RIGHT 1600, RETURN 2200) and the shots are at 430 and 530.
- **Tested:**
  - Python Z80 harness with READER's build: a 2.9K text with every element, at each of its 157 scroll positions, scrolled down, up and to random places with the checkpoints. Every screen is the same as a render from the text's start. Paragraphs, an item's second line, a quote's two lines and a two-space break come out right.
  - Caprice32: `test-markdown` (the README page on both screens, the two first lines joined), `test-reader` (ABOUT.MD's three lines are one paragraph), `test-about` (V-OS 0.11 BETA), `test-sysinfo` (0.11).
- **Not measured:** how much faster scrolling is on a real CPC. The harness's cycle counts were not reliable.

**M39 (a Markdown reader for the web):**
- **READER:** a new program (`myapps/reader`, 11K, on its own disc `reader.dsk` with `INDEX.MD` and `ABOUT.MD`). It shows `.MD` pages from the disc or from the web (the M4 board, HTTP, up to 6K) as MARKDOWN's preview does. TAB selects the next link, shown inverted, and the page scrolls to it; RETURN follows it; DEL goes back (4 pages are kept). OPEN A FILE, OPEN AN ADDRESS (^U), OTHER DRIVE.
- **Links:** a relative link opens next to the page: on the same drive for a disc page, on the same site and folder for a web page; `/x.md` from the top of the site; `http://…` anywhere. `https://` gives "ONLY HTTP ADDRESSES CAN BE OPENED", and the web without an M4 board gives "THE WEB NEEDS AN M4 BOARD".
- **Shared code:** MARKDOWN's page renderer moved to `myapps/markdown/page.asm` and `page_data.asm`, included by both programs. With `PV_LINKS` defined it also counts the links, inverts the selected one, and can draw only the rows of one link. MARKDOWN's size did not change.
- **SYSINFO:** it also shows the memory (128K on a 6128, 64K more for each block of a RAM expansion) and how much of it is free for programs, from the new `VX_MEM` (API 18), in the kernel extension.
- **Bug found** (in the Python harness): an absolute `http://` link from a web page gave an empty address, because the address had moved while its `http://` was cut off.
- **Tested:**
  - Caprice32 (`make test-reader`): `INDEX.MD` shows, TAB inverts "About READER", RETURN opens `ABOUT.MD`, DEL shows LOADING… and goes back to `INDEX.MD`, and the `https://` link gives the message. `test-sysinfo`: API 18, MEMORY 128K, FREE MEMORY 10K (bank 5's 12K less SYSINFO); with 576K, MEMORY 576K and FREE MEMORY 458K.
  - Python Z80 harness with the M4 emulated: the links resolve right (disc relative, web relative, `/top.md`, `http://`, `https://`), and a web page comes with `C_HTTPGETMEM` and three `C_COPYBUF`, with TAB turned into a space and the text the same.
- **Not tested:** a real web page through an M4 (see M38).

**M38 (the internet with the M4 board):**
- **WEBGET:** a new program (`myapps/webget`, 2.5K, on `vos.dsk`). GET A FILE (^G) asks for an HTTP address and a name (taken from the end of the address), the M4 board downloads the file, and WEBGET saves it on the drive it shows. Up to 16K, the size of the data bank. It also shows the network status, or "NO M4 BOARD".
- **API 17:** `VX_M4`, through `VOS_EXT`: HL → a command packet for the M4 (size, command, data), DE → where its response goes, BC = how many bytes. The kernel looks for the M4 ROM by its name ("M4 BOARD") once, sends the packet to `#FE00` and starts it with `#FC00`, then maps the ROM at `#C000` (where the screen is) only while it copies the response from the buffer that `#FF02` points to, with interrupts off. The search is in the kernel extension; the rest took 79 bytes of the main kernel.
- **M4 commands used:** `C_NETSTAT` (the network), `C_HTTPGETMEM` (up to 16K into the M4's buffer) and `C_COPYBUF` (512 bytes at a time), from spinpoint.org/cpc/m4info.txt.
- **Bugs found** (in the Python harness): `m4_rom` changed BC, so the response copy ran over 32K of memory; and a known M4 ROM was reported as "none" from the second call on.
- **Tested:**
  - Python Z80 harness with the kernel and its extension from `VOS.BIN` and CPCEMU's `M4.ROM`, with the M4 emulated from its documentation: the ROM is found in slot 6, `C_NETSTAT`, `C_HTTPGETMEM` and `C_COPYBUF` go out and their responses come back right, and the screen RAM is back at `#C000` afterwards.
  - The harness with WEBGET's GET: a 1,500-byte page comes in three pieces and is saved as `INDEX.HTM`, the same bytes.
  - Caprice32 (no M4): WEBGET shows NO M4 BOARD and ^G does nothing, without crashing. `test-sysinfo` shows API 17.
- **Not tested:** a real download. Here CPCEMU (the only emulator with an M4) does not show its window, and it writes the discs only when it is closed with F12, so `make test-webget` is for a machine with a screen. Not tested on a real M4 either.

**M37 (the clipboard):**
- **What changed:** NOTEPAD and MARKDOWN have an EDIT menu: COPY ^C, CUT ^X, PASTE ^V and SELECT ALL ^A. SHIFT with the arrows selects, and the selection is shown inverted. Typing, RETURN, DEL or CLR replace or delete the selection; an arrow without SHIFT or a click ends it.
- **Shared:** the clipboard is in the kernel, so text copied in one program can be pasted in another. It keeps up to 1K, in the free end of the kernel extension (bank 7, `#7B00–#7EFF`), which costs nothing in `VOS.BIN`.
- **API 16:** `VX_CLIP_PUT` (HL = text, BC = bytes) and `VX_CLIP_GET` (DE = where, BC = room; HL = the clipboard's size, BC = 0 for only the size), through `VOS_EXT`. They copy between the program's bank and bank 7 in pieces, with `bank_copy`. `VMOD_SHIFT` and `VMOD_CONTROL` describe the mods byte of key events.
- **Bug found:** after a file was opened in its program (M35), the view selected the program's file and not the file on its return. Now the kernel puts the file's name back.
- **Tested:** in Caprice32 with `make test-clip`: NOTEPAD with `HELLO.TXT`, SHIFT+RIGHT ×6 selects "HELLO ", ^C, DOWN, ^V pastes it, ^A selects all, ^X empties the text, ^V brings it back; ^Q, the Commander is on `HELLO.TXT` again, `README.MD` opens in MARKDOWN, and ^V puts the two lines before its first line. `test-open`, `test-notepad` and `test-markdown` again.
- **Not tested:** a paste bigger than the room left, and the clipboard with more than 1K.

**M36 (VOS_EXT, room for more calls):**
- **What changed:** the API's jump table gets one last call, `VOS_EXT` (API 15). A program puts a call number (`VX_*`) in A and the arguments in BC, DE and HL. An unknown number returns carry. New calls no longer need a place in the table.
- **Where the calls live:** `xa_table` in the kernel (`src/kernel/api.asm`) has the address of each one. A call in the main kernel gets HL as it was. A call in the kernel extension (bank 7, where there is about 1.6K free) runs through `ext_call` and finds HL in `xa_hl`; it cannot see the program's memory there. The dispatcher took 51 bytes of the main kernel.
- **The first calls:** `VX_VERSION` (in the kernel): A = API version, HL = V-OS version in BCD. `VX_FREE` (in the extension): C = drive → A = free K.
- **SYSINFO:** a small new program (`myapps/sysinfo`, 1.2K) that shows the V-OS and API versions and the free space on A: and B:, with styled text. It is an example of `VOS_EXT`.
- **Bug avoided:** background programs keep a copy of the jump table in GAP0, and 43 calls no longer fitted there (801 of 800 bytes). The language messages' buffer went from 160 to 152 bytes (the longest message is 139), and the copy starts 8 bytes earlier. `VOS_EXT` is quiet in the background, like most calls.
- **Tested:** in Caprice32 with `make test-sysinfo`: SYSINFO from the Commander shows 0.10, API 15, 23K free on A: and 165K on B:, the same as the Commander, ^R reads them again, ^Q goes back. `test-behind` (TICKER keeps counting in the background) and `test-music` again.
- **Not tested:** `VX_FREE` on an empty drive.

**M35 (opening files by type):**
- **What changed:** RETURN, ENTER or a second click on a file in the Desktop or the Commander now opens it. A program runs, as before. A `.TXT` opens in NOTEPAD, a `.MD` in MARKDOWN, a `.PIC` or `.LYR` in PAINT, and a `.MUS` in MUSIC, which starts playing it. Any other file shows its info, which is also on FILE > FILE INFO and ^I. The FILE menu's first item is now OPEN.
- **Where the program is:** on the file's drive, then on A:, then on B:. So `README.MD` on `markdown.dsk` in B: opens in MARKDOWN from B:, and a `.TXT` on B: opens in NOTEPAD from A:. If there is none, "NO PROGRAM FOR THIS FILE" (error 14).
- **API 14:** `VOS_OPEN` (`#B000`, in unused video RAM): `db 1, drive, name`. The program reads it in `init`, also when it was already running (A = 2), and writes 0 there. NOTEPAD, MARKDOWN and PAINT ask first if there are unsaved changes; PAINT picks the picture or layers mode by the extension.
- **Texts:** the hint lines of the Desktop and the Commander and the KEYS dialog say ENTER OPEN in all six languages. The hint lines that were wider than the screen in French, Spanish, German and Italian were shortened.
- **Tested:** in Caprice32 with `make test-open`: the Commander, `README.MD` on B: opens in MARKDOWN, back with ^Q, then `HELLO.TXT` on B: opens in NOTEPAD from A:. When NOTEPAD was not on the disc, the error came up as expected. `test-notepad`, `test-markdown` and `test-paint` again.
- **Not tested:** the Desktop (it calls the same `file_open`), `.PIC`, `.LYR` and `.MUS` from a view, and a program that was already running when its file was opened.

**M34 (MARKDOWN, text styles):**
- **Text styles:** `VOS_COLOURS` takes `VOS_BOLD`, `VOS_ITALIC` and `VOS_UNDERLINE` in bits 4–6 of A (API 13). They come from the same 8×8 font, as each letter is drawn, so they work in all languages. Bold: each row with itself one pixel to the right. Italic: the top four rows one pixel to the right, the bottom two one to the left. The kernel grew by 79 bytes.
- **MARKDOWN:** an editor for `.MD` files (up to 6K), from NOTEPAD, on its own disc, `markdown.dsk`, with a `README.MD`. ^P shows the page without the marks: headings, bold, italic, code, lists, numbered lists, quotes, lines, code blocks, links, `\` for a mark as it is. Long lines wrap at a space, under the start of their text.
- **Bug found:** the VIEW and HELP menus send commands 6–19 to the program, and NOTEPAD, PAINT and VROUVES had their own commands with the same numbers. In NOTEPAD, ^L (SWITCH LANGUAGE) did BACK, and in PAINT ABOUT V-OS left the program. Now the commands of programs start from `VC_APP` (32), and the SDK says so.
- **Tested:** in Caprice32 with `make test-markdown`: `README.MD` opens from B:, the page shows all the elements correctly on both of its screens, and RETURN goes back to the text. A page is drawn in about one second (the blanks at the end of lines with one `VOS_RECT`). Again `test-notepad`, `test-paint`, `test-vrouves`, `test-music`, `test-sdk`.
- **Not tested:** saving an `.MD` in Caprice32 (it is the NOTEPAD code), scrolling line by line.

**M33 (second drive in the Launcher, scores in VROUVES, NOTEPAD, PAINT, MUSIC, ABOUT):**
- **Launcher:** TAB, or FILE > OTHER DRIVE, shows the programs of B:. The page line starts with `A:` or `B:`, and a program started from B: returns to B:.
- **VROUVES:** only on its own disc now. Points for every invader and for the villagers at the end of the stage, with SCORE and STAGE under the HUD. `VROUVES.SAV` keeps the stage you reached (CONTINUE) and the five best scores with a name (HIGH SCORES).
- **NOTEPAD:** a text editor in mode 1, 48×22, up to 4K. It opens only `.TXT` files, and writes CR LF to the disc.
- **PAINT:** drawing in mode 0: a 128×128 picture (`.PIC`), or 64×64 at 2× zoom in 3 layers (`.LYR`) that change order, hide and show. Pencil, brush, line, box, fill, eraser. Arrows and COPY draw without a mouse.
- **MUSIC:** plays Arkos Tracker 3 songs with the AKM player (MIT), on its own disc, `music.dsk`. `make songs` makes the songs. The music continues behind other views.
- **ABOUT:** HELP > ABOUT V-OS shows "V-OS 0.1 BETA", the build date, Revive8bit, 2026 and Architect: Vasper, in the six languages.
- **Windows:** `make windows` now builds `V-OS.exe` with CPCEMU 3.0.2: 576K, AMX mouse, M4 card, the two discs, autostart.
- **Linux:** `make linux` builds `build/V-OS-linux.tar.gz`, with the `V-OS` script and CPCEMU 2.5 for x86_64 (3.0.2 has not been released for Linux), with the same settings and discs. It needs SDL2. `VKBD_LANGUAGE = 0` in `vos.cfg` (also for Windows) skips the question CPCEMU asks about the virtual keyboard at the first start.
- **SDK:** API 12 with `VOS_CAT_EXT` (catalogue with one extension) and `VOS_PTR_KEYS` (the pointer with the arrows). `sdk/AI.md` is a guide to the SDK for AI assistants.
- **Bugs found:**
  - PAINT cut the canvas: RASM calculated `CW / 2 * CH` wrongly. Now with parentheses.
  - In PAINT the box swapped the corners wrongly, and the background of a label stayed yellow.
  - The menu always put the arrows on the pointer after closing. Now it keeps what was in force before.
- **Tested:**
  - In Caprice32: `make test-vrouves` (from B: through the Launcher, HIGH SCORES), `test-notepad`, `test-paint` (and the layers), `test-about`, `test-music` (the song plays, the bars move, it continues behind the Launcher).
  - With Z80 in Python: the scores and the file of VROUVES, the editing and the CR LF of NOTEPAD, the tools and the layers of PAINT, the moving of the songs of MUSIC (the same byte for byte as SongToAkm's).
- **Not tested:** the sound (no window), the picture and the autostart of CPCEMU on Windows and Linux (only that it starts: in WSLg the window cannot be caught in a screenshot), entering a name in the score table in Caprice32.

**M32 (VROUVES: all 7 stages, on its own disc):**
- **What changed:** VROUVES now has all the stages of the original: Kafenio, Church, Town Hall, Bakery, School, Stadium, Cemetery. Each stage has its own map, roads and 10 waves. When a stage is saved, the next follows with money and vrouves from the start. On defeat you play the same stage again, and after the 7th the first starts again.
- **As in the original:** each stage has the defenders the original brings there (1 only Cretan and Psssst, from 5 all of them), and the others are missing from the bar. In stages 3 and 4 the invaders are tougher. The name of the stage, in English or in Greek, shows under the HUD until the first wave.
- **Its own disc:** `build/vrouves.dsk` has `VROUVES.BIN` and `VROUV1.DAT` to `VROUV7.DAT`. It goes in B:, and the game runs from the Commander (FILE > RUN). `vos.dsk` keeps VROUVES with stage 1. After this is saved, a message says that stages 2–7 are on the VROUVES disc.
- **SDK:** the `owndisc/` subfolder of a program gives it its own disc, `build/<name>.dsk`. The new `VOS_SELF` of the API tells a program which drive it started from.
- **Bugs found:**
  - In `import_art.py` the stage number was spoiled inside a loop, and all the stages got the name and the defenders of 3.
  - In the game, a HUD line of 24 characters was written into a buffer of 14 bytes.
- **Tested:**
  - With Z80 in Python: the 7 stages are drawn correctly and have the right defenders, the right difficulty and the right name in both languages. A win goes to the next stage, and after the 7th to 1. From A: the message about the disc comes, and a defeat starts the same stage again. In stages 3 and 6 three waves were played.
  - In Caprice32, with `make test-vrouves`, which now opens the game from its disc in B: through the Commander. Stage 1 loads from B:, with its name and only its two defenders. A Cretan and a Psssst are built, and wave 1 comes.
- **Not tested:** the sound, and the whole game up to the 7th stage in Caprice32.

**M31 (VROUVES, a game with the SDK):**
- **What it is:** LET'S GO FOR VROUVES for the CPC, tower defence, in a simplified form for V-OS: stage 1, the Kafenio. The invaders of Frankenstein & Moreau CO. come down the road to the Zonians' kafenio, and the villagers build defenders next to it to save the vrouves.
- **How to play:** the arrows move the cursor, 1–6 pick a defender (Cretan, Yiayia, Bride, Psssst, Cauldron, Baker), SPACE or RETURN builds, S sells, N brings the next wave at once, P pauses. With the mouse, a click on the stage builds and a click on the bar picks. Ten waves of drones, guards and tanks. The VROUVES menu has NEW GAME, NEXT WAVE, PAUSE, ABOUT.
- **From the original:** the sprites, the palette, the map, the roads and the waves come from `~/repos/VrouvesCPC` with `myapps/vrouves/import_art.py`, into `art.asm` and `disc/VROUV1.DAT`. Both are in the repo, so the build does not need the original.
- **Simplifications:** no neighbour bonuses, no projectiles in the air (the damage is immediate, with an effect on the target), no music, only sound effects.
- **The SDK grew:** a program in `myapps/` can have more `.asm` files in its folder (`include`), and whatever is in its `disc/` goes onto the disc as it is. The SDK guide says so in all six languages.
- **Size:** `VROUVES.BIN` is 11.5K (the limit for a program with a relocation table is 12K), `VROUV1.DAT` 3.4K. 9K are left on `vos.dsk`.
- **Tested in Caprice32** with the new `make test-vrouves`. It opens from the Launcher, a Cretan and a Psssst are built, the guards of wave 1 fall, the money goes up (5 → 30 → 50), the "NEXT IN 15" counts and the drones of wave 2 come. Before that, a Z80 in Python played up to wave 3 and produced the screen as a picture.
- **Not tested:** the sound (Caprice32 without a window has none), and the whole game up to a win or a defeat in Caprice32.
- **Next:** all 7 stages, on their own disc.

**M30 (SDK for assembly programs):**
- **What it does:** you write your own programs in Z80 assembly with the V-OS API, and they run like the system programs: in the Launcher, with menus, buttons, dialogs and sound, and next to other programs.
- **`make new-app NAME=hello`** creates `myapps/hello/` from `sdk/template/`.
  - The template is a program with a relocation table, in mode 1. The arrows move a box, there is a BEEP button, a seconds counter and its own menu (ABOUT, BACK).
  - Its texts are in English and Greek (`texts.txt`), and it has an icon (`icon.txt`).
  - The name is checked: 1–8 characters, not the name of a V-OS program.
- **`make app NAME=hello`** builds `build/HELLO.BIN` (texts, icon, two builds and a relocation table) and puts it on `build/vos.dsk`. Plain `make` puts in all of `myapps/*`, only on the normal disc and not on the test discs.
- **`sdk/README.md`:** a guide in Greek. It explains how a program works (init, event, redraw), the events, the three kinds of program, the rules, the formats of menus, buttons, dialogs and texts, and has a table with the 42 calls.
- **Tested in Caprice32** with the new `make test-sdk`. The TEMPLATE opens from the Launcher with its icon. The box moves with →/↑, the counter counts, ESC opens its menu, ABOUT shows the dialog, and ^Q returns to the Launcher.
- **Bug found:** the counter drew over the open menu. The template now does not draw while a menu is open, and the guide states it as a rule.
- **Not tested:** the sound of BEEP, because Caprice32 without a window has no sound.

**M29 (more room for the code of blocks):**
- **What changed:** when a Studio program starts, the player reads the block lines one by one from the copy of the file in the data bank. The kernel loads every program there first, at the same addresses. So the code it writes can go over the lines, which are not needed afterwards.
- **The costumes** are moved down first, to where the lines start, and the code follows right after.
- **Result:** the largest possible program (240 lines and 8 costumes) now has a guaranteed 4,000 bytes for its code, instead of 1,536. Every program gains 10 bytes for each of its lines.
- **Why not 16K:** the program sees only one 16K window (`#4000–#7FFF`), shared with the player, the runtime, the sprites, the variables and the stacks. Code in another bank would need a copy of the runtime in every bank and shared memory outside the window.
- **Tested:**
  - Off-emulator, with a Z80 in Python: FLAP (3 costumes) gives, with the old and the new player, the same costume images, the same scripts and the same sprite positions after 30 frames.
  - In Caprice32, with test-input, test-calc, test-mines, test-vars and test-costume.

**M28 (saving and restoring variables in Studio):**
- **Two new blocks** in the VARIABLES category:
  - `SAVE VARS group TO "name"` writes the variables to a text file.
  - `LOAD VARS group FROM "name"` restores them.
- **The group:** ALL (all 128) or by 8, that is A-H, A1-H1 … A15-H15. In Studio each letter A–H moves to the next eight and SPACE gives ALL. The help line says so.
- **The file:** one line for each variable, e.g. `A1=-5`. If the name has no type, it gets `.TXT`. Lowercase becomes uppercase.
  - SAVE VARS writes only the variables of the group.
  - LOAD VARS changes only those that are both in the file and in the group. It ignores lines it does not understand, and if the file is missing it changes nothing.
  - So the same file can restore all the variables or only one eight.
- **Player:**
  - The text is built and read in the data bank, and the writing and reading are done on the kernel stack (`rt_on_main`).
  - Their data (name, buffer) went to `#7750`, after the variables.
  - Their code (≈430 bytes) shrank the guaranteed room for the code of blocks: the largest possible program (240 lines and 8 costumes) now has 1.5K instead of 2K.
- **Studio:** it went over 16K by 275 bytes, and it fitted with two changes:
  - Its temporary variables went into the 258 bytes of the icon. Only the Launcher reads the icon from the disc, and Studio zeroes these bytes when it starts.
  - The program area is now exactly the size of the largest `.VBS` (5,033 bytes).
- **`tools/mkvbs.py`:** `SAVE_VARS "name" ALL` or `A3-H3`, and the same for `LOAD_VARS`.
- **Tested:**
  - **In Caprice32** with `make test-vars`. VARS.VBS writes all the variables to VARS.TXT, puts 9 in five of them and writes the row A1-H1 to ROW1.TXT. Then it loads VARS.TXT and the row of ROW1.TXT. The second line shows 0 9 7 12 10, as it should.
  - **In Studio,** in the same test: the blocks show as "SAVE VARS ALL TO "VARS"", and A changes A-H to A1-H1.
  - **Off-emulator,** with a Z80 in Python: the texts that are written, the negative numbers, lowercase, spaces, invalid lines (A16, Z9) and the group filter.
- **`vbc.py` does not have them** (the `.vbp` programs of the editor in HTML). They are only in the Studio blocks.

**M27 (BRICKS, a brick game):**
- **What it is:** a game where the ball breaks bricks, made with blocks (`blocks/examples/bricks.vbp`, through `blocks/vbc.py`). It is on the disc as `BRICKS.VBN` and runs from the Launcher (page 2).
- **The game:**
  - 32 bricks in four rows: red (4 points), orange (3), yellow (2), green (1).
  - The paddle moves with the arrows ←/→. The ball leaves the paddle, and its angle changes depending on where the paddle meets it.
  - You have 3 lives. As soon as all the bricks are broken, they are set up again, and the ball goes faster at each level (up to 5).
  - At GAME OVER, SPACE starts a new game.
  - Sounds on the paddle, on the bricks and on a lost ball.
- **How it is made:**
  - Each brick is a sprite with the same script: it appears, waits (WAIT UNTIL) for the ball to touch it, hides, adds points and sends "hit". With "hit", the ball reverses its vertical speed.
  - The 32 identical scripts are written by `tools/mkbricks.py`, and the Makefile rebuilds the `.vbp` when it changes.
  - A script does not send a message to itself, because the message would start it from the beginning. The new ball after a lost life is made inside the same loop, with the variable `serve`.
- **Tested in Caprice32** with the new `make test-bricks`:
  - BRICKS opens from the Launcher, and the paddle moves with →/←.
  - The bricks that are hit disappear, and the SCORE grows (1 for green).
  - The lives go down until GAME OVER. SPACE starts a new game with all the bricks, SCORE from the start and LIVES 3.
  - Passing to the next level was not tested, because the test does not play that well.
- **Size:** 13.7K, because `vbc.py` also writes into the file the stacks of the 39 scripts (128 bytes each).

**M26 (128 variables in Studio):**
- **What it does:** Studio programs have 128 variables instead of 64.
  - **Names:** A–H, A1–H7 as before, and now up to A15–H15. The letter is the number mod 8 and the number after the letter is the number ÷ 8: H15 is the 127th, the last.
  - Old programs do not change, because the `.VBS` already kept the variable in one byte.
- **In Studio:** the same letter again moves on A → A1 … → A15 → A. A digit in a variable slot goes through all 128. The help line says "AGAIN: A1-A15".
- **Player:** the 128 variables (256 bytes) went to `#7650`, in the gap after the state of the scripts, and are zeroed together with it. So the room for the code of blocks grew, instead of shrinking by 256 bytes. The REPEAT counters are now right below the sprites.
- **`tools/mkvbs.py`:** accepts A..H and A1..H15.
- **Tested in Caprice32** with `make test-vars`. VARS.VBS now uses H15 and C12. Studio shows them with two digits, and the program prints 0 5 7 12 10.

**M25 (bigger MINES):**
- **The game:** an 8×6 grid with 8 mines (it was 5×3 with 3). You win when you open the 40 safe cells.
- **How it was written without arrays:**
  - Each row is two variables: its mines (A1..F1) and its open cells (A2..F2), one bit for each column. Column c is bit c + 1, so the three columns around it are always bits c..c + 2, also at the edges.
  - Two scripts with a message read (3) and write (4) row A. Whoever calls them waits with UNTIL until A3 becomes 1.
  - The mines around a cell: for the three rows, H = (row ÷ 2^c) mod 8 and count = H − H/2 − H/4.
  - One click at a time: D3 is 2 while a click is being served, −2 while the mines are shown. Clicks in between are ignored.
  - The program is 218 block lines.
- **Changes to make it fit and run:**
  - **Lines:** up to 240 (it was 200) in Studio, in the player and in `mkvbs.py`.
  - **REPEAT:** the player gives each REPEAT its own counter (up to 64 REPEATs in a program), instead of 128 bytes for all. So the code of blocks fits.
  - **Buttons:** up to 64 in a window. The runtime draws them when a frame has not added any, not after every BUTTON, so the 49 buttons take fractions of a second.
  - **Kernel:** `ui_widget_ptr` computed the position of a widget in 8 bits and wrapped at the 32nd. Now it is 16 bits.
  - **`VOS_RANDOM`:** it is now a 16-bit xorshift, with the frame mixed into the seed first. The old generator (x·5 + frames) gave correlated pairs, and the mines gathered in the first row.
- **Tested in Caprice32** with `make test-mines`:
  - The 48 cells and NEW appear quickly.
  - The cells open with correct numbers (".", "1"), until a click lands on a mine.
  - Then all 8 mines show, scattered over 5 rows, and BOOM! erases "8 MINES". The next clicks are ignored, and NEW starts a clean grid.
  - A test that printed the values of the rows showed that the display of the mines agrees with them.

**M24 (64 variables in Studio):**
- **What it does:** Studio programs now have 64 variables instead of 8.
  - **Names:** A–H, as before, and then A1–H7. The letter is the number mod 8 and the digit is the number ÷ 8: A1 is the 8th, H7 the 63rd.
  - Old programs do not change.
- **In Studio:**
  - In a variable slot, the letter A–H chooses the variable. The same letter again moves on A → A1 → A2 … → A7 → A.
  - In a slot that accepts only a variable (SET, CHANGE, …), a digit goes to the next one, and goes through all 64.
  - The help line says "A-H: VARIABLE, AGAIN: A1-A7".
- **Player:** the 64 variables (128 bytes) are at `#7480`, below the sprites. The room for the code of blocks shrank by 128 bytes, and an assert makes sure at least 2K remain.
- **`tools/mkvbs.py`:** accepts A..H and A1..H7.
- **Tested in Caprice32** with the new `make test-vars`. Studio opens VARS.VBS and shows A1, H7, B2 and C5. Two presses of A turn "SET A" into "SET A2". With RUN it prints 0 5 7 12 10, so each variable has its own value. Like test-costume, it ends with a timeout, because RUN writes to the disc. test-mines, test-calc, test-langs, test-lang, test-drag, test-input, test-behind, test-multi, test-switch, test-expand and test-acc also pass.
- **Limit:** 58 bytes were left free in Studio.

**M23 (MINES, a minesweeper made with Studio):**
- **What it is:** `blocks/examples/mines.vbt`, from which `tools/mkvbs.py` makes `MINES.VBS` (opens in Studio) and `MINES.VBN` (runs from the Launcher).
- **The game:**
  - A 5×3 grid of cells with 3 mines, inside a window in mode 1.
  - Each cell is a button. A click opens it and shows how many mines it has around it ("." if it has none).
  - If you open a mine, all three show ("*") and BOOM!. The 12 safe cells give YOU WIN!.
  - NEW starts a new game.
- **With 8 variables and no arrays:**
  - The mines are three numbers (row×16+column). A mine is a neighbour when (mine − cell + 20) is 0..47 with remainder 3..5 when divided by 16.
  - The open cells are a bitmask of 15 bits.
  - The program is 196 block lines.
- **New block LABEL n TO text:**
  - It changes the text of button n, which keeps the same size. Without it this was not possible: whatever was written with PRINT over a button vanished as soon as the kernel redrew the button.
  - It is block 36 in Studio (WINDOWS category), in the player and in the runtime (`rt_label`). Old `.VBS` files stay correct.
- **Tested in Caprice32** with the new `make test-mines`. The cells open with correct numbers: the mines were at (1,4), (2,0) and (2,4), and the 1, 1, 2 next to them came out right. On the mine all three "*" and BOOM! appear, the next clicks are ignored, and NEW starts a clean grid. Studio shows the new block "LABEL TO" (test-calc). test-calc (with two more UP), test-langs, test-lang, test-drag, test-input, test-behind, test-multi, test-switch, test-expand and test-acc also pass. test-costume ends with the usual timeout.
- **Limits:**
  - It does not open by itself around a ".". That would need recursion or a list, which Studio does not have.
  - The first choice can be a mine.
  - Creating the window is slow, because each BUTTON redraws all the buttons.

**M22 (French, Spanish, German and Italian):**
- **What it does:** besides Greek there are now four more language packs: `FRENCH.LNG`, `SPANISH.LNG`, `GERMAN.LNG` and `ITALIAN.LNG`. Each brings all the system texts (102), its own keyboard and the letters it needs.
- **Setup > LANGUAGE:**
  - It cycles through ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO.
  - Each language is loaded at once from A:, with a "PLEASE WAIT" while it is read, and the whole screen is rewritten in it.
  - SETUP.CFG (version 2) keeps the pack too. At startup that pack is loaded, instead of the `GREEK.LNG` that was always loaded. An old SETUP.CFG is ignored.
  - With ENGLISH the last pack stays loaded, for the keyboard.
- **Keyboards (CTRL+SHIFT):**
  - **French:** AZERTY, with the digits on SHIFT. Dead keys ^ and ¨.
  - **Spanish:** Ñ on the `:` key. Dead keys ´ ¨ ` ^, and ¡ ¿.
  - **German:** QWERTZ, with Ü Ö Ä ß. Dead keys ´ and `.
  - **Italian:** è é ò à ù ì on their own keys.
- **Font:** the four languages are in ISO 8859-1 and share `lang/latin1/font.txt` (from font8x8, `tools/fonts/make_latin_font.py`). Capitals with an accent are 5 lines high, so there is room to show the accent.
- **Program texts (API 11):**
  - The `VOS_TEXTS` table now says which language the second column has (`db count, "EL"`). The kernel shows it only when the pack is of that language.
  - So, with French, Studio and the other programs appear in English and not with Greek texts in a Latin font.
- **Space:**
  - `ENGLISH.MSG` now has a limit of 2K (it is 1.5K), and the kernel extension grew to 4K (`#7000–#7FFF`).
  - The file commands (info, copy, delete, rename, format) went to the extension.
  - The kernel now ends at `#3C0E`, with ~500 bytes free.
- **Tested in Caprice32** with the new `make test-langs`. Setup cycles through the five languages and the whole screen changes each time. The Desktop appears in Italian, and in rename the Italian keyboard (IT) types è à ù ò. test-lang (Greek is saved and reloaded after a restart), test-drag, test-calc, test-input, test-behind, test-multi, test-switch, test-expand and test-acc also pass. test-costume ends with the usual timeout.
- **Limits:**
  - Programs have only English and Greek texts, so with the new languages they are in English.
  - Œ œ are missing (they are not in ISO 8859-1). @ # [ ] { } \ | cannot be typed with the new keyboards, since the CPC has no AltGr; they are typed with the English one (CTRL+SHIFT).

**M21 (movable windows):**
- **What it does:** every window can be dragged by its title bar with the mouse (or with COPY and the arrow keys, when the arrow keys move the mouse). While you hold the button, only a dashed outline is shown, and it follows the mouse. When you let go, the window is redrawn there.
- **Which windows:**
  - the system dialogs: messages, questions, text input, file selection
  - the FILES window of the Desktop, which stays where you left it, also when you change view
  - the desk accessory (CLOCK): the kernel redraws whatever was underneath, and then the clock in its new position
  - the WINDOWs of programs with blocks, together with their buttons
- **API 10:**
  - `VOS_DRAG`: a program calls it with its window when it gets a click. It returns carry and the new position, if the window was moved.
  - `VOS_FIT`: brings a window inside the screen. The accessory needs it, because it opens over views in both modes.
- **Rules:**
  - x becomes a multiple of 8.
  - The window stays below the menu bar and leaves 4 pixels for the shadow.
  - The outline is drawn with XOR, so it is erased without redrawing anything underneath.
- **Memory:**
  - The kernel had only 280 bytes free. The dragging went into the kernel extension.
  - To make it fit, the `bg_api` table (in GAP0) and the variables of F6 and of the background (`#9800`, `#A800`) were moved to hidden RAM.
  - The extension is now full up to `#7F00`.
- **Tested on Caprice32** with the new `make test-drag`. The dashed outline is shown and then the window in its new position, for FILES, for the KEYS dialog, for CLOCK over the Launcher, and for the CALC window. After the move, a click on the "1" of CALC at its new position gives 1. test-lang, test-calc, test-input, test-behind, test-multi, test-switch, test-expand and test-acc also pass. test-costume ends with the usual timeout.
- **Limits:**
  - Whatever a program with blocks has printed with PRINT is lost when its window is moved, as with every redraw.
  - FILES can cover the disc icons; you drag it back.
  - While a window is being dragged, the programs in the background wait.

**M20 (programs with blocks as `.VBN`):**
- **What it does:** programs made with blocks now have a type of their own, `.VBN`, to tell them apart from `.BIN`. They are ordinary V-OS programs with the same header, only with another extension.
  - RUN in Studio writes `NAME.VBN`.
  - `blocks/vbc.py` and `tools/mkvbs.py` also write `.VBN`. On the disc these are PONG, CATCH, STARCAT, COUNTER, FLAP, CALC and TICKER.
- **Desktop (FILES):** the page of a `.VBN` says "VBN" and has a ▶ symbol next to it, in the color of the page (dark when it is selected).
- **Launcher:** shows the `.VBN` as programs, together with `.BIN` and `.BAS`, and also reads the icon from them (the ▶ of the player). F6, the background and resuming work as before, because the kernel does not look at the extension.
- **Studio:** the check "not the name STUDIO" is no longer needed, because `STUDIO.VBN` does not collide with `STUDIO.BIN`.
- **Tested on Caprice32:** the Desktop shows the ▶ next to every `.VBN`. CALC.VBN starts from the Launcher (test-calc). RUN in Studio writes and runs `.VBN` (test-input). test-lang, test-behind, test-multi, test-switch, test-expand and test-acc also pass. test-costume ends with the usual timeout. The scripts needed no change, because the order of the files on the disc stayed the same.

**M19 (programs that run in the background):**
- **What it does:** when you make a program, you choose whether it freezes behind other programs and views (as before, and this is the default) or keeps running there.
  - **Studio:** STUDIO > IN BACKGROUND. The dialog says what the program does now ("THE PROGRAM PAUSES THERE" or "THE PROGRAM KEEPS RUNNING THERE") and YES changes it. The choice is saved in the `.VBS` (bit 6 of the background byte), so it stays in the `.BIN` too.
  - **Blocks editor (PC):** the box "Freezes in the background", `"freeze"` in the `.vbp`. In `tools/mkvbs.py`: `BEHIND RUN`.
- **In the background** the program gets one frame on every frame and runs its scripts, but it is not seen, not heard and gets no keys. When it comes to the front again (F6 or Launcher) it draws its state as it has become.
- **Kernel, API 9:** new call `VOS_BACKGROUND` (A = 1 runs, 0 freezes). While a program runs in the background, the kernel makes all calls silent except `VOS_FRAMES`, `VOS_RANDOM`, `VOS_KEEP` and `VOS_BACKGROUND`, so that it does not disturb the screen or the data of the program in front.
- **The player now resumes** from where it was when it comes to the front again. Before, a Studio program started from the beginning.
- **Studio loads the player from the disc** (`VBRUN.SYS`) only at RUN, instead of carrying it inside. It had been left with 5 bytes free; now it has 145, and `STUDIO.BIN` became 11K instead of 16K. `VBRUN.SYS` must be on A: together with Studio.
- **Example:** `TICKER` (`blocks/examples/ticker.vbt`) counts seconds and moves a ball, and runs in the background.
- **Tested on Caprice32** with the new `make test-behind` (576K). test-calc, test-multi, test-switch, test-expand, test-acc, test-input and test-lang also pass. test-costume ends with the usual timeout, with the same captures. RUN in Studio with `VBRUN.SYS` works in test-input, test-costume and test-calc. Three UP keys were added to test-calc, because the file list now has three files after CLOCK.BIN.
- **Limits:**
  - Studio programs need a bank of their own, so they run next to others only with a memory expansion. The programs of `vbc.py` run in the background also with 128K.
  - Whatever a program from blocks has printed with PRINT is lost on resume, until its next change (as since M16).
  - Behind a dialog, a menu or the F6 window the programs stop for a moment, and while the disc is reading they get no frames, so a timer in the background falls a little behind.

**M18 (memory expansion):**
- **What it does:** with a RAM expansion (64K up to 512K, through bits 3-5 of the Gate Array port) programs go into its banks too. The loader finds which ones exist at boot (`src/boot/expand.asm`).
- **Placement:**
  - Each program goes to the first space where it fits: first bank 5 above `#5000`, then the banks of the expansion from `#4000`.
  - Those with a relocation table share a bank. STUDIO, CALC and FLAP take a whole bank each and now run next to the others, without "CLOSE ANOTHER PROGRAM FIRST".
- **How many:** up to 15 programs. Their table was moved to the kernel extension of bank 7 (`#7F00`), and F6 shows up to 8.
- **Without an expansion** everything stays as in M16.
- **Fix:** the mixed screen and the sound of a program stop when you go to a view or another program. Before, the mixed screen of Studio or MIXED stayed active and spoiled the colors of the next one.
- **Tested on Caprice32** with 576K and the new `make test-expand`: STUDIO, DEMO, PONG and CALC together, and F6 resumes them. The other tests (with 128K) pass as before.
- **Limits:**
  - The data bank (bank 4) is shared. Studio refills it in `init`, so it works, but on resume it reopens the program that was saved last, and whatever was not saved is lost.
  - Programs in the background are frozen (in M19 this became a choice).

**M17 (switching programs):**
- **What it does:** F6, from any view or program, opens the PROGRAMS window with all that are running, in the order they were started. The program that runs now has ">" in front of it, and the next one is selected.
- **Controls:**
  - F6 or DOWN and UP move the selection.
  - RETURN, ENTER, SPACE or a click resume the selected program from where it was.
  - ESC or a click outside the window closes it.
  - With no programs it says "NO PROGRAM IS RUNNING".
- **Menu:** the same opens from PROGRAMS (F6) in the VIEW menu of the views.
- **Kernel extension:** the code is in bank 7 (`src/kernel/ext.asm`, at `#7800`, up to 2K), where the loader puts it. `lang_init`, which runs only at boot, was moved there too. The kernel gained space and ends at `#3CE3`.
- **Tested on Caprice32** with the new `make test-switch`.

**M16 (many programs together):**
- **What it does:** a program is no longer ended when you go to another view (F1-F4). In the Launcher, RUN on a program that is already running resumes it from where it was, and you can start more next to it. ^Q (or VOS_EXIT) closes it.
- **How many fit:** as many as fit in the 12K above the views (`#5000-#7FFF` of bank 5), up to four. E.g. DEMO, PONG, CATCH and CLOCK together.
- **STUDIO, CALC and FLAP** need the whole bank. They start only if nothing else is running; otherwise "CLOSE ANOTHER PROGRAM FIRST" appears.
- **API 8:** on resume `init` gets A = 2: the program sets up its screen again without losing its state (`src/api/vos_api.inc`).
- **Limits:**
  - Programs in the background are frozen.
  - A program from blocks loses on resume whatever it has printed, until the next change (in PONG the score).
  - Switching is done only through the Launcher (F6 was added in M17), and the tiles do not show which programs are running.
- **Tested on Caprice32** with the new `make test-multi`. test-acc, test-input, test-calc, test-costume and test-lang also pass.

**M15 (relocation in all programs):**
- First step to run many programs together: all programs that can be moved now have a relocation table (DEMO, MIXED, CLOCK, PONG, CATCH, STARCAT, COUNTER), and the kernel can load them at any page of the bank.
- STUDIO and its programs (CALC, FLAP) need the whole bank and stay at `#4000`.
- The kernel gained space: three buffers were moved to hidden places of the screen.
- **Tested on Caprice32** with `make test-reloc` (which became `test-multi` in M16): DEMO, PONG and MIXED run from `#6300`.

**M14 (relocation and a second program: desk accessory):**
- **What it does:** a small program (up to 4K) can run as an "accessory" over any other program or view.
  - In the Launcher: select the program, then FILE > AS ACCESSORY (^A). It is loaded and opened.
  - From then on **F5** opens and closes it, over Studio, the calculator or a view.
  - While it is open it gets the keys and the mouse. The program underneath waits, and on closing it is redrawn.
- **Relocation:** `tools/mkreloc.py` assembles the program at `#4000` and at `#4100` and finds the bytes that differ. These are the addresses of the program itself, and their table is put at the end of the file. The kernel moves the program to `#7000` of bank 6, where it stays as long as needed.
- **Example: CLOCK** (`apps/clock`, 888 bytes together with the table). It shows the time since V-OS started. As a program it has its own screen, as an accessory a small window. It closes with F5 or ESC.
- **API 7:** described in `src/api/vos_api.inc`. `init` gets A = 1 when the program starts as an accessory. `VOS_FRAMES` now gives 24 bits, almost 4 days.
- **Fix in the Launcher:** with more than 9 programs, changing the page with the arrow keys drew tiles in wrong positions. It showed up now, with the 10th program.
- **Limits:**
  - One accessory at a time.
  - It cannot change mode, palette or menu bar, nor use the data bank.
  - The kernel then had about 150 bytes free (`#3D68`).
- **Tested on Caprice32** with `make test-acc`: CLOCK over the Launcher (mode 0) and over the mixed screen of Studio, closing with F5 and with ESC, correct redraw. Also with a Z80 emulator, after relocation at `#7000`.

**M13 (costumes in Studio):**
- **Editor:** on the stage, E draws the costume of the sprite (a new one if it has none) and K changes which one it wears (none, 1, 2, ...).
  - The editor takes the place of the stage: a 16×16 grid, with the 16 pens below.
  - Keys: arrow keys, SPACE or RETURN to paint, 0-9 and A-F for a pen, `.` for transparent, E or TAB to finish. With the mouse, a click on a cell paints and a click on the row picks a pen.
- **Blocks:** `COSTUME n`, `NEXT COSTUME` (LOOKS/SOUND) and the value `COSTUME` (letter U). Up to 8 costumes per program, shared by all sprites.
- **Files:** `.VBS` format 3, with the costumes after the lines. Old `.VBS` files open normally.
- **Player:** turns the costumes into images when it starts, in mode 0 or 1, and produces the same bytes as `vbc.py`. `vbc.py` now also accepts a value in `switch_costume`.
- **Example:** `blocks/examples/flap.vbt`. FLAP has a bird that flaps its wings and a star that changes costume. It is on the disc as `FLAP.BIN` and `FLAP.VBS`.
- **File list:** UP from the first file goes to the last, and DOWN from the last to the first.
- **Fix in the tests:** the wrong save caused by an `ld bc,-vbs`, which RASM turned into `+vbs`, gave "DISC FULL". Now it is written `0 - vbs`.
- **Tested:**
  - On Caprice32: `make test-costume` draws with keys and clicks, does RUN, where the sprite is drawn with the costume, and CONTROL+Q, where NONAME.VBS opens with the costume. Also FLAP from the Launcher, and `make test-input`, `make test-calc`, `make test-lang`.
  - With a Z80 emulator in Python: the images of the player in mode 0 and 1 are the same as those of `vbc.py`.
- **Limit:** Studio has filled its bank (6 bytes are left).

**Windows and buttons in the editor and in `vbc.py`:**
- The web editor now has the category WINDOWS with the blocks `window`, `button`, `when button pressed` and the value `button`, as in Studio. The two tools again have the same blocks.
- In the `.vbp`: `{"block": "window", "title", "w", "h"}`, `{"block": "button", "text", "x", "y"}`, the event `"button"` and the value `{"button": true}`.
- The code of the windows is now in `blocks/runtime.asm` (`RT_UI`), shared by the Studio player and `vbc.py`. With a window, `print` writes inside it.
- Example: `blocks/examples/counter.vbp`, the COUNTER in mode 1, with buttons +1, -1 and 0. It is on the disc.

**Fix: the Launcher selection.** At the start, the Launcher selected the program whose number in the catalog was equal to the number of programs, instead of the one that was selected in the previous view (the A register was lost in `ln_load`). With 7 programs it landed on DEMO by chance. With COUNTER it landed on MIXED, and `make test-input` started PONG.

**The boot language:**
- At first, without `SETUP.CFG`, V-OS starts in English. The keyboard was already English.
- The boot language is changed in Setup (F4), in the LANGUAGE row.
- The command VIEW > SWITCH LANGUAGE (CONTROL+L) now also changes the setting. With saving in Setup (RETURN or ^S) it stays for the next boot.
- Tested with the new `make test-lang`: boot in English, Greek with CONTROL+L, saving, BASIC, `RUN"VOS`, and V-OS starts in Greek.

**Fix: the mixed screen after disc access (after M12):**
- **The symptom:** the zones of Studio were spoiled for good after a read or write on the disc, and sometimes Studio froze.
- **Cause:** the handler notices the VSYNC interrupt only if it serves it within about 3 lines.
  - A sector transfer keeps interrupts disabled for 16 ms. Interrupts are lost, so the counting of the 6 slices shifts.
  - With wrong counting, the wait of 45 lines of the mixed screen could fall exactly before the VSYNC in every frame. Then the VSYNC was never seen again.
  - Without VSYNC `int_frames` stopped, and `wait_frame` did not return.
- **Fix:** if 12 interrupts (2 frames) pass without VSYNC, the handler waits once actively for the start of the VSYNC and starts counting from there. This is not done between the sectors of one file, so that no sectors are lost (`interrupts.asm`).
- **How it was found:** with `-DTEST_TRACE` (only in test builds). It writes for every interrupt the slice, `int_frames` and the address that was interrupted, and shows them on the screen together with `-DTEST_DUMP`.
- **Tested on Caprice32:** `make test-input`, `make test-calc`, and capture 760, where the zones were wrong before. During the transfer of a sector the bottom zone may show stripes for a moment, as the API also says.

**M12 (operations, windows and buttons in Studio, mode 1):**
- **Operations** in VARIABLES: `DECREASE`, `MULTIPLY`, `DIVIDE`, `REMAINDER` (e.g. `MULTIPLY A BY 10`), 16-bit signed integers.
- **New category WINDOWS:**
  - `WINDOW "title" width height`: a window in the middle of the stage, with the look of the V-OS dialogs.
  - `BUTTON "text" AT x y`: a system button (mouse, TAB, RETURN). The buttons are numbered from 0 in the order they appear, up to 16.
  - `WHEN BUTTON`: starts when any button is pressed. The value `BUTTON` (key P in a value field) says which one.
  - `TEXT "text" AT x y`. `TEXT`, `BUTTON` and `PRINT` count from the inside of the window.
- **Texts in fields:** every program has up to 32 texts of 14 characters. When a block with text is added, Studio asks for it at once. With RETURN or a click on the field it changes.
- **`.VBS` format 2:** the texts go after the sprites. Files of format 1 open normally.
- **Mode 1:** a program can run in mode 1, with 384 pixels width, 48 columns and pens 0-3.
  - It is selected from EDIT > SCREEN MODE, and under the stage M0 or M1 is shown.
  - The preview of the stage, the arrow keys and the clicks then count in pixels of mode 1.
  - The player reads the mode when the program starts. It is saved in bit 7 of the background color.
- **Example:** the calculator `CALC` in mode 1 (`blocks/examples/calc.vbt`). `tools/mkvbs.py` makes `CALC.VBS` for Studio and `CALC.BIN` for the Launcher from text.
- **Tested:**
  - On a Z80 emulator, the calculator for 12+3=, 7*6=, 100/7=, 5-9= and 2+3*4=.
  - On Caprice32, with `make test-calc`: CALC in mode 1 with clicks on the buttons (12+3= gives 15), CALC.VBS in Studio, and adding a WINDOW with text from the dialog.
  - All of `make test-input`, with the CALC files on the disc.
  - Not tested in the emulator: sprites in a program of mode 1, that is the scale of the stage, the arrow keys and the clicks of Studio. CALC has no sprites.
- **Fix in the kernel (old bug, it was also in M11):** with more files on the disc, opening the `.VBS` in the test gave "NOT A V-OS PROGRAM" in a dialog that was not visible, and Studio looked stuck.
  - Cause: while a key is held, the auto-repeat sent events faster than the file list redrew its rows when it scrolled. The queue of 32 events filled up and the keys after that, like RETURN, were lost.
  - Now the repeat sends an event only when the queue is empty (`kbd.asm`), so a slow program does not lose keys.
  - Found with a new tool for tests: `-DTEST_DUMP=frame` shows the stack or memory as bits in the top line of the screen (`test_script.asm`).

**M11 (messages in Studio):**
- **New blocks** in EVENTS:
  - `WHEN I RECEIVE n` starts a script when message n is sent.
  - `SEND n` sends a message, and n can also be a variable.
  - So a sprite can start the scripts of others, as in Scratch.
- **Compatibility:** the blocks were put at the end of the list (24, 25), so old `.VBS` files open as before. The order in the palette is now set by a table (`pal_order`).
- **Texts:** the texts of Studio had reached the limit of 64, so the YES/NO buttons now come from the system. The API gives `VM_OK`, `VM_YES`, `VM_NO`, and the kernel checks that they match `MSG_BTN_*`.
- **Tested:** on a Z80 emulator, a program where sprite 1 sends message 7 at the edge and sprite 2 counts. On Caprice32 the blocks were seen in the palette, and all of `make test-input`.
- **Known problem (from M8a, fixed after M12):** the mixed screen of Studio can be spoiled for good after writes to the disc. In capture 960 of `make test-input` Studio is seen with the zones wrong.
  - On Caprice32 I measured the VSYNC directly, from bit 0 of the PPI. In the healthy state it lasts 7 lines on every frame. After the writes of RUN it appears irregularly: every 2-5 frames, for 0-3 lines.
  - So no interrupt sees it, and the counting of the interrupts is not set up again.
  - The kernel does not write to the CRTC after boot, and all `OUT` instructions have the right port. I do not know yet whether the code or the emulator is at fault. It needs a check on another emulator or on a real CPC.

**M10 (program icons):**
- **What is shown:** the Launcher shows the icon of each program on its card, with the name and the type below.
  - DEMO has a diamond, MIXED its zones, STUDIO three blocks one inside the other.
  - Programs with blocks (PONG, CATCH, STARCAT and those made by Studio) have a "play".
- **Format:** an optional `"IC"` and 256 bytes at `+12` of the program (`VOS_ICON` in `vos_api.inc`): 16×16 pixels in mode 0, with a mask, as `VOS_BLIT` draws them.
  - The icons are written as text in `apps/icons/` (a pen in hex or `.` for transparent) and are converted by the new `tools/mkicon.py`.
  - In the `.vbp` an `"icon"` with 16 lines gives its own icon to a program with blocks.
- **Launcher:** reads the first sector of each `.BIN` only the first time it draws a page, and keeps the icon. Moves within the same page do not read the disc again.
- **Fix in the mixed screen (bug from M8a):**
  - If a VSYNC interrupt was served late, for example after a sector transfer from the disc, the zones could stay wrong for good. The wait of 45 lines for the limit at line 12 then fell exactly before the VSYNC and kept every next VSYNC interrupt late.
  - It showed when Studio restarted after a program.
  - Now, if after the waits the VSYNC is active while it is not interrupt 0, the next interrupt counts as 0 (`split_irq`). **It is not enough:** see M11, which found the real picture.
  - The kernel ends at `#3C3E` and about 450 bytes are left (after M12 `#3C78`).
- **Tested on Caprice32:** the six icons in the Launcher, and all of `make test-input`. The return to Studio showed correct zones in those captures, but in M11 the error showed again.
- **Not tested:** a second page with programs, and a real CPC.

**M9 (data bank for programs):**
- **What it gives:** while a program runs, bank 4 is its own, another 16K. On the CPC 6128 the kernel uses all four extra banks, but bank 4 only in the views and when it loads the next view or the next program.
- **API version 6** (39 calls):
  - `VOS_BANK_GET` and `VOS_BANK_PUT` copy from and to the bank.
  - `VOS_LOAD` and `VOS_SAVE` with a drive + `VOS_DATA` load and save files directly in it.
  - The bank is never mapped to the place of the program, so the code stays up to 16K. The calls are made from the kernel stack, not from a stack inside the bank of the program.
- **Studio uses it:**
  - The player stays in the bank, and its space becomes the buffer of the program: Studio takes 11.3K instead of 14.6K.
  - RUN builds the `.BIN` inside the bank, so its header now has the correct load address `#4000`.
  - OPEN checks the file in the bank before it brings it into Studio, so a damaged file no longer erases the program that is open.
- **Kernel:** ends at `#3C2A` and about 470 bytes are left.
- **Tested on Caprice32** with all of `make test-input`: OPEN, RUN and the reload after the run go through the bank.
- **Not tested:** OPEN of a file that is not a program, and a real CPC.

**M8c (Studio: running the program):**
- **RUN (CONTROL+R)** in the STUDIO menu:
  - Saves `NAME.VBS`, writes `NAME.BIN` and runs it.
  - When the program stops (PROGRAM > STOP, CONTROL+Q), Studio starts again with the same program open.
  - The `.BIN` is a normal V-OS program and also runs from the Launcher.
- **The player** (`blocks/player.asm`, 3.7K): the M7 runtime plus a compiler for the lines of the `.VBS`.
  - The `.BIN` is the player and, right after it, the program. When it starts, the player writes the Z80 code of the blocks, the same code `vbc.py` produces, and then runs the runtime.
  - The compiling happens there and not inside Studio, because of memory: Studio needs only the player (11.5K in total, 14.6K with the space for the `.VBS`), and the code gets the whole bank of the program.
  - The `WHEN …` blocks become scripts, up to 16. Whatever is left open is closed at the next `WHEN`. In a stage script, the motion and looks blocks do nothing.
- **Kernel, API version 5** (37 calls):
  - `VOS_RUN` runs a program and then starts again the one that called it.
  - `VOS_KEEP` gives 16 bytes that stay from program to program. Studio writes there which `.VBS` to open.
  - The 16-byte text table, which needs a page start, moved to `#8000`, screen memory that is not visible. Before, it lost up to 255 bytes to alignment.
  - The kernel ends at `#3BB2` and about 590 bytes are left.
- **Tested:**
  - The compiler, with a program that uses almost all the blocks. It ran on a Z80 emulator in Python and in Caprice32: loops, `IF`/`ELSE`, `WAIT UNTIL`, random, "touching", note, `PRINT` and variables.
  - The whole flow in Caprice32, with the `make test-input` script: CONTROL+R in Studio, the program runs, CONTROL+Q, and Studio returns with the program as it was.
- **Not tested:** a real CPC. (The load address in the header of the `.BIN` was wrong; it was fixed in M9.)

**M8b (Studio: the blocks editor inside V-OS):**
- **What it is:** the `STUDIO` program (`apps/studio`) on the mixed screen.
  - Top, in mode 0 with 16 colours: the stage at half size and the list of the objects (colour, x y, size).
  - Bottom, in mode 1 with 48 columns: the palette of blocks, the script and a status line that says what the keys do where you are.
  - The boundary is at line 138, so the whole stage fits. It costs 13 lines of waiting, about 4% of the time, on top of the 45 of the menu bar line.
- **The program** is a list of lines, one block each:
  - The `WHEN …` blocks start a script for one object or for the stage.
  - `FOREVER`, `REPEAT` and `IF` open a block that is closed with `END`. The indent comes from the lines themselves.
  - There are 24 blocks in 5 categories: events, control, motion, looks/sound, variables. There can be up to 6 objects, and the variables are A–H.
  - Each block has up to three fields. A field holds a number, a variable, the x or y of an object, random, "key is pressed", "touching", "at edge", or a comparison `< = >`.
- **Controls:**
  - TAB goes from the script to the palette and to the stage.
  - In the script: the arrows choose a line and a field, RETURN puts the block of the palette below, and CLR deletes the line. A block that opens goes in together with its `END`, and is deleted together with it.
  - In a chosen field, the digits write a number, A–H a variable, X/Y/R/K/T/Z the other kinds, and DEL deletes a digit. The letters are read as keys, so they work with the Greek keyboard too.
  - On the stage: the arrows move the object, 1–6 choose it, C changes the colour and W/H the size.
  - With the mouse: a click on a block of the palette adds it, a click on a field chooses it, a second click changes its kind. A click on the stage puts the object there.
- **Files:** SAVE writes `NAME.VBS` (binary format, described at the start of `studio.asm`) and OPEN reads it back. The texts, English and Greek, come from `apps/studio/texts.txt` with the new `tools/mktexts.py`.
- **Kernel:** with the split active, the dialogs are centred inside the mode 0 zone. The file list shows 8 lines there instead of 10.
- **Tested in Caprice32** with the `make test-input` script:
  - Studio starts from the Launcher, with the two zones in place.
  - With keys: line and field, the `5` in `SPEED`, the `REPEAT 10` with its `END` from the palette, moving and colouring the object.
  - The file: save as `NONAME.VBS`, NEW, and open from the file list, which brings the program back as it was.
  - With clicks (the test build puts the pointer at a given x, y): a block from the palette, choosing a field and changing its kind, a position on the stage.
- **Not tested** on a real CPC.

**M8a (mixed screen, the first part of Studio):**
- **What it does:** a zone in mode 0 (16 colours, 192 pixels) between two zones in mode 1 (4 colours, 384 pixels). Each zone has its own colours for pens 0–3. The change is made in the interrupt (`src/gfx/split.asm`), and the program sets the boundaries with the new call `VOS_SPLIT`.
- **Cost:** a boundary right below lines 22, 74, 126, 178 or 230 costs nothing. On any other line the interrupt waits, 64 µs per line. Below the menu bar line (y = 12) the wait is 45 lines, about 14% of the time. I measured the interrupt lines in Caprice32.
- **Drawing:** `VOS_MODE` now selects only how the program draws, and each zone is drawn in its own mode. The kernel draws the menu bar in mode 1 and the menus that fall below it in mode 0, with wide letters, as §2.3 defines.
- **Mouse:** the pointer is drawn in the mode of the line where it is. In events, x is given in pixels of the zone where the click happened.
- **Timing fix:** with a long wait, reading the keyboard and the mouse in the same interrupt made the screen miss the mode change on some frames. This 50 Hz work is now done in an interrupt where the split does not wait.
- **API version 4** (35 calls). The kernel ends at `#3B37` and about 700 bytes are left.
- **Program `MIXED`:** menu bar and status line in mode 1, and between them 16 colours and a square that bounces in mode 0. A click shows the x, y of the event.
- **Tested in Caprice32** with the `make test-input` script:
  - The mode change falls exactly on line 12 and on line 230, and was stable in 11 snapshots.
  - The menu opens from the menu bar with a click and with ESC.
  - The pointer is drawn correctly in both zones.
  - The click in mode 0 gives `X=010` where the pointer is at 20 pixels of mode 1.
  - SPACE returns to the Launcher, with mode 0 on the whole screen.
- **Limits:**
  - While the disc is read or written, the interrupts are off for a short time and the screen may flicker.
  - A pointer exactly on the boundary is drawn with the mode of its upper line.
  - The dialogs are drawn in the mode the program has chosen, so in mode 0.
  - Not tested on a real CPC, nor on other CRTC types.

**M7b (costumes, sound, lists):**
- **Costumes:** an object can have pictures instead of a rectangle. You draw them in the editor, pixel by pixel, with the pens of the mode or with "transparent". Blocks: switch costume, next costume, costume number. The size of the object becomes that of the costume.
- **Drawing:** new call `VOS_BLIT` in the kernel. Each byte of the picture comes with a mask, so transparent is separate from pen 0. The x is rounded to a whole byte (2 pixels in mode 0). Objects are now clipped on all four edges, and are not lost when they go a little off to the left or the top.
- **Sound:** a driver for the AY (`src/drivers/psg.asm`) and the call `VOS_SOUND`: channel, tone or noise, volume, duration in frames. The kernel stops the note by itself when its time is over. Blocks: play note (waits), start note, noise, stop sounds, volume. The notes are MIDI numbers (60 = C).
- **Lists:** of 16-bit numbers, with a fixed maximum length (`"max"`, 64 if missing). Blocks: add, delete, insert at, replace, empty, item, length, "contains…?". Numbering starts from 1, and an item out of range gives 0.
- **API version 3** (34 calls). The kernel grew by 256 bytes (it ends at `#3911`).
- **Example `STARCAT`:** a cat with two costumes, which walks with the arrows, and a star. It plays a melody from a list, a noise is heard when the cat catches the star, and it prints a check of the lists (`4 9 5 1 / 0 2 7 0`). It is the "Example" of the editor.
- **Not tested:** the sound. Caprice32 without a window gives no sound and no snapshot of it, so only the code has been checked.

**M7 (blocks, Scratch-style):**
- **Editor** (`blocks/editor.html`): a page with Blockly, in Greek or in English. It has the categories events, control, motion, looks, text, operators, sensors and variables. It also has windows with buttons. The objects (rectangles with position, size, colour and speed) are defined in a table, and the stage shows them with the colours of the CPC; they are dragged with the mouse. It opens and saves `.vbp`.
- **`.vbp`:** JSON with the program only: name, mode, objects, variables, scripts. The editor rebuilds the blocks from it, so it also opens files written by hand. The description of all the blocks is at the start of `blocks/vbc.py`.
- **Compiler** (`blocks/vbc.py`): produces a readable `.ASM`, with one comment per block. It compiles it with RASM into a `.BIN` for the V-OS API and, with `--dsk`, writes it to the disc. 16-bit signed numbers; comparisons give 1 or 0. The texts are written in ISO 8859-7, so Greek works.
- **Runtime** (`blocks/runtime.asm`, ≈2K): each script is a coroutine with its own stack and gives up the processor at the end of each repetition. In each frame, all the scripts that are active run once, and then the objects that changed are redrawn. It has a menu PROGRAM → STOP (^Q) next to the common ones.
- **Examples:** `PONG` (ball, paddle with the arrows, score and lives, GAME OVER) and `CATCH`. They are on the discs and run from the Launcher.
- **Left:** text in variables (done in M7b: costumes, sound, lists).

**M6b (space in the kernel):** the English texts became the file `ENGLISH.MSG` (1.5K) on the disc. The kernel loads it into bank 7 and `lang_msg` uses it like the messages of the packs. The kernel went down from `#3D11` to `#3811`, so about 1.5K is left. The test version still borrows space from the stack only if needed.

**M6 (API and running programs):**
- **API:** a jump table at `#0108` with 31 calls: system, graphics, text, menus and dialogs, files. It is described in `src/api/vos_api.inc`, the only file a program needs. The kernel checks at build time that its table agrees with it.
- **Program format:** a binary with an AMSDOS header, for `#4000`, up to 16K. It starts with `jp init`, `jp event`, `jp redraw` and `"VA"` together with the API version. It runs in bank 5 like the views, and the kernel sends it the events. With `VOS_TICKS` it also gets one event per frame, for motion.
- **Program texts:** the numbers from `#C0` upwards are texts of the program (`VOS_TEXTS`), with an English and a Greek version. Menus, dialogs and printing use them, and they follow the language switch.
- **Starting:** ENTER in the Launcher, or FILE → RUN in the Desktop and in the Commander, from any drive. If the file is not a V-OS program, an error is shown. `VOS_EXIT` returns to the view that started the program.
- **DEMO.BIN** (`apps/demo`, 495 bytes): mode 0, a square that moves by itself and bounces. The arrows drive it, SPACE changes colour. It has its own menu next to the common VIEW and HELP, and texts in two languages. It is compiled separately, with only the include of the API.
- **Memory:** with M6 the kernel became full (`#3D11` from `#3E00`). M6b freed space.
- **Left from §7:** relocation (came in M14), icon in the header, banks for programs (`MEM`), sound (`SND`), reading files as a stream.

**M5c (Setup, format, finishing the shell):**
- **Settings (F4, Setup view):** start view, language, delay and speed of key repeat, AMX Mouse (yes/no and way of reading), background colour in mode 1. The changes apply at once. ^S or RETURN saves them to `A:SETUP.CFG`, which the kernel reads at start (`src/kernel/setup.asm`).
- **Format (Commander, FILE → FORMAT DISC):** 40 tracks in DATA format with the interleave of AMSDOS, after asking for confirmation. AMSDOS reads the disc as empty, with 178K.
- **Overwrite:** the copy asks before it writes over a file with the same name.
- **Wait window:** "PLEASE WAIT" while the copy and the format last.
- **The choice stays:** the file and the drive you chose in one view are chosen in the next one too.
- **Fixes:**
  - The dialogs took their width from the last line of the text, not from the longest (a bug from M3).
  - The exit to BASIC switched on the lower ROM while running code at `#0000–#3FFF`, and worked only by luck. Now the last commands run from RAM.
- **Memory:** the kernel reached 15K; about 500 bytes are left. Most of it is the English texts, which live inside the kernel. If space is needed, they can become a pack too.

**M5b (views, rename, large files):**
- **Three views as overlays:** `DESKTOP.OVL`, `LAUNCHER.OVL` and `COMMANDR.OVL` on disc A:. The kernel loads them into bank 5 (`#4000`) and they switch with F1/F2/F3 or from the VIEW menu. Each new view is first loaded into bank 4 and checked, so a disc error does not damage the one that is running. When the kernel changes bank, it always returns to the bank of the view (`ram_home`). The views read and write other banks only through the kernel (`bank_put`, `bank_get`).
- **Desktop (A), the start view:** a window with the files of the drive as icons (the type inside the icon, the name below), 4 per row with scrolling, and drive icons A:/B: on the right. Arrows to choose, TAB or a click on the drive to change drive, ENTER for details, ^C copy to the other drive, ^D delete, ^N rename, ^R read again.
- **Launcher (B), mode 0:** the programs (.BIN, .BAS) of A: in a 3×3 grid with coloured tiles and pages. Starting programs comes with the loader of M6; for now ENTER shows a message about it.
- **Rename (^N):** a new text input dialog (`src/ui/input.asm`) and `fs_rename`. The name is checked and converted to AMSDOS capitals. An error is shown if the name already exists or is not valid.
- **Files over 16K:** the copy (`fs_copy`) is done sector by sector, per 16K through bank 4, with the header as it is. It has no size limit. AMSDOS loads a 20K file copied this way, and the bytes before and after the 16K limit are correct.
- **Shared code:** the file commands (`src/kernel/files.asm`), the VIEW/HELP menus and the exit (`src/kernel/view.asm`) are in the kernel. So is the dialog window (`ui_window`), shared by the dialogs, the file list and the text input. The kernel is 14.2K and each view about 1.3K.
- **Tests:** `cap32_shot.sh` now also takes several delays (`120,200,…`). After a write to the disc, Caprice32 does not close with CAP32_EXIT, so the run ends with a timeout (40 seconds).
- **Left:** format, confirmation before writing over a file with the same name, starting programs (M6), Setup and `SETUP.CFG`, joystick in the Launcher (the AMX Mouse uses the same port).

**M5a (Commander):**
- **Two panels**, A: and B:, in mode 1. Each panel shows the format, the number of files, the files with size and the free space. The active panel has a dark title and a selection. If a drive cannot be read, the panel writes the error.
- **Keys:** UP/DOWN to choose (with SHIFT per page), TAB or LEFT/RIGHT for the other panel, ENTER for file details, ^C copy across, ^D delete with confirmation, ^R read the discs again. With the mouse, one click chooses and a second click shows details.
- **Copy:** keeps the AMSDOS header or its absence (text files), up to 16K. AMSDOS reads both kinds of copies (`make test-amsdos`).
- **Memory:** the lists of the panels are in bank 5, so switching panels does not read the disc. The test application of M3/M4 was removed; the kernel is 14.2K.
- **Tests:** the screenshots now go to `build/shots`, because other projects write at the same time to the shared snap folder. `mklng` rejects messages over 127 characters.
- **Left for M5:** rename (needs a text input dialog), files over 16K, format, the Desktop (A) and the Launcher (B) as overlays.

**M4 (disc):**
- **FDC driver** (`src/drivers/fdc.asm`): sector read and write with polling, retries, error messages, automatic motor off. Like the driver of TerraCPC, which was tested on a real CPC, it never waits without a limit: every wait has a timeout, the result is read while the FDC is busy (bit CB) and before each new attempt the controller is set up from the start.
- **Extended DSK disc** with all 42 tracks formatted (`tools/dsk_ext.py`), because some emulators (e.g. WinAPE) damage images with empty tracks when they write to them.
- **Compatibility:** AMSDOS (in BASIC, in the same run of Caprice32) does `CAT` and `LOAD` on the file that V-OS wrote. The SYSTEM format was tested with `tools/dsk_system.py` and `make test-system`.
- **AMSDOS filesystem** (`src/kernel/fs.asm`): DATA and SYSTEM formats, directory, load into a bank, save with an AMSDOS header, delete, free space.
- **No AMSDOS after start:** the loader only moves the kernel. `GREEK.LNG` is now loaded with our own driver.
- **Memory:** tables and buffers moved to the gaps of screen memory (`GAP0–GAP7`, `memmap.inc`), so the kernel fits.
- **Test application:** the FILE menu has Open (file list, then name, size, type, address and the first bytes), Save test (`VOSTEST.TXT`), Delete with confirmation and Disc info.
- **Keyboard fix:** CONTROL+A to G are no longer dead keys, and the CONTROL shortcuts work with the Greek keyboard too.
- **Not tested on a real CPC** (only in Caprice32). Formatting the disc is left for later.

**M3 (UI):**
- **UI toolkit** (`src/ui/`): menu bar, drop-down menus, buttons with focus and TAB, CONTROL+letter shortcuts, modal dialogs. All work with the mouse and with keys, in mode 0 and mode 1, Greek or English.
- **Background:** menus and dialogs keep what they cover in bank 6.
- **Pointer:** it is hidden only when drawing falls on it.
- **Test application:** FILE / VIEW / HELP, three buttons, a status line, the dialogs About, Keys and Exit (restart into BASIC).
- **Greek font:** the ά έ ή ί now have the same accent as ό ύ ώ.

**M2b (languages):**
- **Language packs (`.LNG`):** produced from the text files in `lang/` with `tools/mklng.py`. `GREEK.LNG` is written to the disc together with `VOS.BIN`.
- **Loading:** the loader loads the pack through AMSDOS. The kernel keeps the font and the keyboard in its memory and the whole pack in bank 7.
- **Greek on screen:** UI texts through `lang_msg`, ISO 8859-7 font. F3 in the test screen switches the language of the labels.
- **Greek typing:** switching EN/EL with CONTROL+SHIFT, dead keys for the accent and the diaeresis, CAPS LOCK for Greek.
- **One example:** if you want another language, you add a folder to `lang/`, with no changes to the kernel.
- **Fix of an M2 bug:** the English map is now produced from `lang/en/keymap.txt`. This fixed the M2 bug where keys 35–39 (I L K M ,) gave the wrong character.

**M2 (input):**
- Keyboard scan 50 times per second, with an English map, SHIFT, CONTROL, CAPS LOCK and auto-repeat. Greek comes with the language pack in M2b.
- `txt_char` is unrolled, with a table aligned to a 256-byte page, so it writes faster.
- A queue of 32 events for keys and pointer.
- Pointer from cursor keys (COPY = click) and AMX Mouse (300 Hz, not tested on hardware).
- Software pointer with save-under in mode 0 and mode 1.
- The graphics coordinates now cover only the useful area 384×259 / 192×259 (physical lines 6–264).
- Test screen: last events, keyboard table in real time, text field, pointer position, a box for clicks. F1/F2 change mode.
- `make test-input` builds a version that "presses" cursor keys, COPY, H, I and F2 from a script (`src/kernel/test_script.asm`), because Caprice32 cannot type these keys.

**M1 (screen):** 32K overscan at `#8000–#FFFF` (384×272 in mode 1, 192×272 in mode 0). There is an address table for the 272 lines and the routines `gfx_plot`, `gfx_fill_rect`, `gfx_cls`, `txt_char` and `txt_print`, which work in both modes. The 8×8 ASCII font is font8x8, public domain. The test screen alternates mode 1 and mode 0 every 3 seconds and shows in the title how many frames the drawing took: 34 in mode 1, 39 in mode 0, with no optimisations yet.

**M0 (infrastructure):** AMSDOS loads `VOS.BIN` at `#4000`. The loader switches off the ROMs and moves the kernel to `#0000`. The kernel installs its own IM 1 handler, synchronised with VSYNC. The test screen of M0 (before the one from M1 replaced it) showed:
- 4 vertical bands with pens 0–3,
- 6 coloured stripes on the border, one for each interrupt slice,
- pen 3, which changes colour every second.
