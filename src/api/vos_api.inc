; =====================================================================
; vos_api.inc - the V-OS API for programs
;
; A program is a binary file (AMSDOS header, type 2) assembled for
; VOS_APP_ADDR. The kernel loads it into bank 5 and it starts with
;   +0  jp init     set the mode, palette and menus, draw everything
;   +3  jp event    HL -> the event (VOS_EV_SIZE bytes, below)
;   +6  jp redraw   draw everything again (the language changed)
;   +9  db "VA", VOS_API_VERSION
; Each entry returns to the kernel, which calls event once per event:
; a program never waits for input itself. With VOS_TICKS on it also gets
; a VE_FRAME event 50 times a second, for animation.
;
;
; Desk accessory (version 7): a small program (up to ACC_MAX bytes)
; with a relocation table can also run over any other program or view.
; The Launcher's FILE > AS ACCESSORY loads it into bank 6 at ACC_ADDR;
; F5 then opens and closes it. Init gets A = 1 there (0 as a program):
; it draws a window of its own over the screen as it is, in the mode
; selected, and sets no mode, palette or menu bar. While it is open it
; gets every event, the program none; VOS_EXIT closes it, and the
; program draws everything again (redraw). It must not use the data
; bank. Its texts, buttons and VOS_TICKS are its own.
;
; Several programs (version 8): one with a relocation table (below)
; runs in bank 5 above PROG_ADDR (#5000), as many as fit in those 12K;
; a view (Launcher, ...) below it does not end it. Going to a view, it
; stops getting events; the Launcher's RUN on it takes it up again:
; init gets A = 2. It sets the mode, palette, menus, buttons and
; VOS_TICKS again and draws everything, keeping its state (an older
; program that ignores A starts again). VOS_EXIT ends it. With a RAM
; expansion (found at boot) programs also go into its banks, from
; #4000: one without a table then has a bank of its own (up to 16K,
; code and data) and runs beside the others too. Without one, it has
; the whole of bank 5, alone: it does not start while another runs
; ("CLOSE ANOTHER PROGRAM FIRST"), and a view ends it. The data bank
; (bank 4) is shared: views and other programs use it too, so it keeps
; its contents only while the program runs (set it again in init).
;
; The background (version 9): a program behind another one or a view
; is paused. After VOS_BACKGROUND with A = 1 (in init) it goes on there
; instead: it gets a VE_FRAME event every frame, whatever VOS_TICKS
; says, and no other. There the screen, the keyboard, the sound, the
; disc and the data bank are not its own: every call but VOS_FRAMES,
; VOS_RANDOM, VOS_KEEP and VOS_BACKGROUND does nothing and returns
; A = 0 with Z set (no key is held). When it comes to the front again,
; init with A = 2 draws everything, as it was then.
; Started behind another program (VX_BEHIND, version 19), init gets
; A = 3 and VOS_OPEN says the file: it must draw nothing and ask
; nothing, only take the file and call VOS_BACKGROUND (A = 1). If it
; runs already, it gets A = 3 again with the new file. The data bank
; is the front program's: VX_BEHIND loads the program through it, so
; what the caller kept there is lost. MUSIC knows A = 3 (myapps/music);
; with a RAM expansion there is room for it beside most programs.
;
; Windows that move (version 10): on a VE_PTR_DOWN, VOS_DRAG with the
; window (HL = x, DE = y, BC = width, A = height) takes it, if the
; click is on its top 10 rows: until the button goes up, a dashed
; outline follows the pointer; nothing else happens meanwhile. Carry:
; it moved, HL, DE = where it is now (x a multiple of 8, room for a
; 4-pixel shadow kept); erase it and draw it there. No carry: the
; click is the program's, as before. The accessory does not draw: the
; kernel draws what was under it, then calls its redraw. VOS_FIT moves
; a window onto the screen the same way (the accessory runs over
; views of both modes: fit its window before drawing it).
;
; Relocation table: after the program's bytes, dw offsets (from the
; start) of the high bytes of its own addresses, then dw count, "RL".
; tools/mkreloc.py makes it from two builds, at #4000 and #4100
; (-DVOS_RELOC_PASS=1 sets VOS_APP_ADDR to #4100). The kernel moves a
; program by whole pages, adding to those bytes, so a program with a
; table may run from any page of its bank: it must keep its data among
; its own bytes (labels, ds), not at fixed addresses. A program without
; one (Studio, VBRUN and what it runs: they use the whole bank) always
; runs at #4000, alone.
;
; Calls: CALL VOS_xxx. Arguments in A, BC, DE, HL (IX for VOS_RECT);
; results in A or HL, carry set on failure with A = error number
; (VOS_ERROR shows it). All registers but IX may be destroyed. Screen
; coordinates: x in pixels of the current mode, y 0..258.
; Do not map another bank at #4000: the program would be unmapped.
; =====================================================================

VOS_API_VERSION equ 23              ; 2: KEY_HELD, 3: BLIT, SOUND, 4: SPLIT,
                                    ; 5: RUN, KEEP, 6: the data bank,
                                    ; 7: accessories, relocation,
                                    ; 8: several programs (init A = 2),
                                    ; 9: BACKGROUND, 10: DRAG, FIT,
                                    ; 11: the language of VOS_TEXTS,
                                    ; 12: VOS_CAT_EXT, VOS_SELF,
                                    ; VOS_PTR_KEYS, 13: text styles,
                                    ; 14: VOS_OPEN, 15: VOS_EXT,
                                    ; 16: the clipboard, 17: VX_M4,
                                    ; 18: VX_MEM, 19: VX_BEHIND, init A = 3,
                                    ; 20: VOS_LOAD_IX, 21: VX_DATA,
                                    ; 22: VX_DB, databases, 23: VX_UTF8
        IFDEF VOS_RELOC_PASS
VOS_APP_ADDR    equ #4100           ; the second build for mkreloc.py
        ELSE
VOS_APP_ADDR    equ #4000
        ENDIF
ACC_ADDR        equ #7000           ; an accessory, in bank 6
ACC_MAX         equ #1000
VOS_API         equ #0108           ; the jump table (after "VOS",0, versions)

; ---- system ---------------------------------------------------------
VOS_EXIT        equ VOS_API + 0 * 3     ; back to the view that started it
VOS_TICKS       equ VOS_API + 1 * 3     ; A = 1: VE_FRAME events, 0: none;
                                        ; + VOS_PTR_KEYS: the cursor keys
                                        ; and COPY drive the pointer too
VOS_PTR_KEYS    equ 2                   ; (version 12)
VOS_FRAMES      equ VOS_API + 2 * 3     ; -> HL = frames since boot (50 Hz),
                                        ; A = bits 16..23 (version 7)
VOS_RANDOM      equ VOS_API + 3 * 3     ; -> A = 0..255
VOS_COMMAND     equ VOS_API + 4 * 3     ; A = VC_*: a shared menu command
VOS_ERROR       equ VOS_API + 5 * 3     ; A = error number: error dialog
; ---- graphics -------------------------------------------------------
VOS_MODE        equ VOS_API + 6 * 3     ; A = 0 or 1, with the UI pens
VOS_PALETTE     equ VOS_API + 7 * 3     ; HL -> 17 firmware colours
VOS_CLS         equ VOS_API + 8 * 3     ; A = pen
VOS_PLOT        equ VOS_API + 9 * 3     ; HL = x, DE = y, A = pen
VOS_RECT        equ VOS_API + 10 * 3    ; IX -> dw x, y, w, h; db pen
VOS_COLOURS     equ VOS_API + 11 * 3    ; A = text pen, C = background pen
                                        ; A bits 4-6: VOS_BOLD, VOS_ITALIC, VOS_UNDERLINE
VOS_BOLD        equ #10                 ; VOS_COLOURS A = pen + styles
VOS_ITALIC      equ #20                 ; (version 13): slanted
VOS_UNDERLINE   equ #40                 ; the bottom row of the cell
VOS_PRINT       equ VOS_API + 12 * 3    ; HL = x, DE = y, BC -> text, 0
VOS_CHAR        equ VOS_API + 13 * 3    ; HL = x, DE = y, A = character
; ---- texts and UI ---------------------------------------------------
VOS_MSG         equ VOS_API + 14 * 3    ; A = system text number -> HL
VOS_SET_BAR     equ VOS_API + 15 * 3    ; HL -> menu bar (as ui/ui.asm)
VOS_DRAW_BAR    equ VOS_API + 16 * 3
VOS_UI_EVENT    equ VOS_API + 17 * 3    ; the current event -> A = command
VOS_DIALOG      equ VOS_API + 18 * 3    ; HL -> dialog -> A = button
VOS_INPUT       equ VOS_API + 19 * 3    ; A = title, HL -> text, C = max
VOS_SET_WIDGETS equ VOS_API + 20 * 3    ; HL -> buttons
VOS_DRAW_WIDGETS equ VOS_API + 21 * 3
VOS_MENU_VIEW   equ VOS_API + 22 * 3    ; -> HL = the shared VIEW menu
VOS_MENU_HELP   equ VOS_API + 23 * 3    ; -> HL = the shared HELP menu
; ---- files ----------------------------------------------------------
VOS_CATALOG     equ VOS_API + 24 * 3    ; A = drive -> A = files, HL -> list
                                        ; (+ VOS_CAT_EXT, HL -> "EXT": only
                                        ; those files, version 12)
VOS_LOAD        equ VOS_API + 25 * 3    ; A = drive, HL = name, DE = to
VOS_SAVE        equ VOS_API + 26 * 3    ; A = drive, HL = name, DE, BC
VOS_DELETE      equ VOS_API + 27 * 3    ; A = drive, HL = name
VOS_FILE_PICK   equ VOS_API + 28 * 3    ; after VOS_CATALOG: A = title
VOS_TEXTS       equ VOS_API + 29 * 3    ; HL -> the program's texts
VOS_MENU_OPEN   equ VOS_API + 30 * 3    ; -> NZ while a menu is open (its
                                        ; keys are not the program's)
VOS_KEY_HELD    equ VOS_API + 31 * 3    ; A = key number -> NZ while held
; ---- images and sound (version 3) -----------------------------------
VOS_BLIT        equ VOS_API + 32 * 3    ; IX -> dw x, y; db bytes, rows;
                                        ; dw source; db source stride
VOS_SOUND       equ VOS_API + 33 * 3    ; A = channel 0..2, HL = period
                                        ; (bit 15: noise), C = volume
                                        ; 0..15 (0: stop), B = frames
; ---- mixed screen (version 4) ---------------------------------------
VOS_SPLIT       equ VOS_API + 34 * 3    ; HL -> dw y1, y2; db 4 + 4 colours
                                        ; (HL = 0: off)
; ---- programs that run programs (version 5) ------------------------
VOS_RUN         equ VOS_API + 35 * 3    ; A = drive, HL -> 11-byte name
                                        ; ("NAME    BIN"): run it after
                                        ; this event; when it exits,
                                        ; this program starts again
VOS_KEEP        equ VOS_API + 36 * 3    ; -> HL -> 16 bytes the kernel
                                        ; keeps between programs (0 at
                                        ; boot; any program may use them)
; ---- the data bank (version 6) --------------------------------------
VOS_BANK_GET    equ VOS_API + 37 * 3    ; HL = source in the data bank,
                                        ; DE = destination, BC = bytes
VOS_BANK_PUT    equ VOS_API + 38 * 3    ; HL = source, DE = destination
                                        ; in the data bank, BC = bytes
VOS_CAT_EXT     equ #40                 ; drive + VOS_CAT_EXT: VOS_CATALOG
                                        ; keeps one extension
VOS_DATA        equ #80                 ; drive + VOS_DATA: VOS_LOAD and
                                        ; VOS_SAVE use the data bank
VOS_LOAD_IX     equ #40                 ; (20) drive + VOS_LOAD_IX: the
                                        ; file VOS_SAVE writes says it
                                        ; loads at IX, not DE (a .SCR:
                                        ; #C000)
VOS_SELF        equ #8800               ; the program running: db drive,
                                        ; then its 11-byte name (read it)
VOS_OPEN        equ #B000               ; (version 14) the file the program
                                        ; was opened for: db 1, drive, 11-byte
                                        ; name (0: none). In init (A = 0 or
                                        ; 2) read it, then write 0 there
; ---- the background (version 9) -------------------------------------
VOS_BACKGROUND  equ VOS_API + 39 * 3    ; A = 1: go on in the background,
                                        ; 0: pause there (as at the start)
; ---- windows that move (version 10) ---------------------------------
VOS_DRAG        equ VOS_API + 40 * 3    ; HL = x, DE = y, BC = w, A = h
                                        ; -> carry: moved to HL, DE
VOS_FIT         equ VOS_API + 41 * 3    ; HL = x, DE = y, BC = w, A = h
                                        ; -> HL, DE on the screen
; ---- more calls (version 15) ----------------------------------------
VOS_EXT         equ VOS_API + 42 * 3    ; A = VX_* call, BC, DE, HL as it
                                        ; wants; unknown: carry, A = 0.
                                        ; Results in A, HL, C, DE, carry
VOS_API_COUNT   equ 43
VX_VERSION      equ 0                   ; -> A = API version, HL = V-OS
                                        ; version (BCD: #0010 is 0.10)
VX_FREE         equ 1                   ; C = drive -> A = free K on it;
                                        ; carry and A = error
VX_CLIP_PUT     equ 2                   ; (16) HL = text, BC = bytes ->
                                        ; the clipboard (1K at most); HL =
                                        ; bytes kept
VX_CLIP_GET     equ 3                   ; (16) DE = where, BC = room -> as
                                        ; much as fits; HL = clipboard size
                                        ; (BC = 0: only the size)
VX_M4           equ 4                   ; (17) HL -> a command for the M4
                                        ; board (db size, dw command, data),
                                        ; DE -> its response (db size, dw
                                        ; command, data), BC = its bytes;
                                        ; carry: no M4 board
VX_MEM          equ 5                   ; (18) -> HL = the RAM in K, DE =
                                        ; K free for programs
VX_BEHIND       equ 6                   ; (19) DE -> db drive, 11-byte name
                                        ; of a file: its program (by type,
                                        ; as the Desktop opens it) starts
                                        ; behind this one, soon after
VX_DATA         equ 7                   ; (21) -> A = 1: the data bank is
                                        ; the program's own; 0: bank 4
VX_DB           equ 8                   ; (22) C = DB_* call (below), DE,
                                        ; HL -> A, DE, HL; carry, A = error
VX_UTF8         equ 9                   ; (23) HL -> text, BC = bytes, E =
                                        ; 0 in the program, VOS_DATA in its
                                        ; data bank: if it is UTF-8, into
                                        ; the V-OS character set there ->
                                        ; BC = bytes now, A = 1; A = 0: not
                                        ; UTF-8, as it was
VX_COUNT        equ 10

; Databases (version 22): VOS_EXT with A = VX_DB, C = one of these. One
; database is open at a time, for the program that opened it (another
; one's calls: DB_ERR_IN_USE). It is a file NAME.VDB of 1K pages, up to
; the disc's room: tables (up to DB_TABLES) of records with fields of
; text or a number (2 bytes), each table with an index on its key
; field, if it has one. A record is its fields one after the other (a
; text field padded as the program likes, e.g. with spaces); its rid
; is a 16-bit number. Every call writes its changes before it returns.
; The kernel loads the engine, DB.SYS, from drive A: when it is first
; needed. HL -> buffers in the program's memory.
DB_CREATE       equ 0                   ; DE -> db drive, 11-byte name
                                        ; ("NAME    VDB"): new, open
DB_OPEN         equ 1                   ; DE -> db drive, name: open ->
                                        ; A = 1: its text is Latin-1
                                        ; (made by V-OS 0.15 in FR ES
                                        ; DE IT), not the V-OS character
                                        ; set: say DB_ERR_ALPHABET
DB_CLOSE        equ 2
DB_TABLE        equ 3                   ; DE -> a table: name (8), fields
                                        ; (1..10), the key field (0: none,
                                        ; or 1..10), then each field: name
                                        ; (8), type, length -> A = table,
                                        ; the one in use
DB_USE          equ 4                   ; E = table: the one in use
DB_INFO         equ 5                   ; E = table, HL -> 124 bytes: its
                                        ; DB_T_* there -> A = tables
DB_ADD          equ 6                   ; HL -> record -> DE = its rid
DB_GET          equ 7                   ; DE = rid, HL -> room: it there
DB_PUT          equ 8                   ; DE = rid, HL -> record: changed
DB_DEL          equ 9                   ; DE = rid: deleted
DB_FIND         equ 10                  ; HL -> a key (as in a record), E =
                                        ; its bytes that count (0: all) ->
                                        ; DE = the first record with that
                                        ; key or after it, by key
DB_FIRST        equ 11                  ; -> DE = rid: by key (no key: in
DB_LAST         equ 12                  ; the order they were added, more
DB_NEXT         equ 13                  ; or less); NEXT and PREV from the
DB_PREV         equ 14                  ; table's cursor, which FIND, FIRST
                                        ; ... set. HL -> room for the
                                        ; record too, or 0. Carry, A =
                                        ; DB_ERR_END: no more
DB_COUNT        equ 15                  ; -> HL = records in the table
DB_TEXT         equ 0                   ; field types
DB_NUMBER       equ 1
DB_ALPHA        equ 2                   ; text; as a key, sorted and found
                                        ; without case or accents
DB_TABLES       equ 8
DB_FIELDS       equ 10
DB_KEY_MAX      equ 64                  ; a key field's length at most
DB_T_NAME       equ 0                   ; DB_INFO: a table's descriptor
DB_T_FIELDS     equ 8                   ;   (fields), DB_T_KEY, DB_T_RECLEN
DB_T_KEY        equ 9                   ;   (bytes), DB_T_COUNT (dw), and
DB_T_RECLEN     equ 10                  ;   from DB_T_FIELD 10 bytes a
DB_T_COUNT      equ 20                  ;   field: name, type, length
DB_T_FIELD      equ 24
DB_ERR_NO_FILE  equ 7                   ; errors (VOS_ERROR shows them): the
                                        ; disc's FILE NOT FOUND (DB_OPEN),
DB_ERR_EXISTS   equ 10                  ; NAME ALREADY USED (DB_CREATE)
DB_ERR_NOT_DB   equ 15                  ; not a database
DB_ERR_NONE     equ 16                  ; no database open
DB_ERR_TABLE    equ 17                  ; no such table
DB_ERR_TABLES   equ 18                  ; no room for another table
DB_ERR_DEF      equ 19                  ; a table's fields are wrong
DB_ERR_RID      equ 20                  ; no such record
DB_ERR_END      equ 21                  ; no more records
DB_ERR_IN_USE   equ 22                  ; another program's database
DB_ERR_FULL     equ 23                  ; the database is full (255K)
DB_ERR_NO_KEY   equ 24                  ; FIND: the table has no key
DB_ERR_BROKEN   equ 25                  ; its index is damaged
DB_ERR_BAD      equ 26                  ; no such DB_* call
DB_ERR_NO_SYS   equ 27                  ; DB.SYS is not on drive A:
DB_ERR_ALPHABET equ 28                  ; (a warning: DB_OPEN's A = 1)

; The data bank: 16K more for the program, seen at the same addresses
; #4000-#7FFF but never mapped there: the program copies to and from it
; (VOS_BANK_GET, VOS_BANK_PUT) or loads and saves files in it (drive +
; VOS_DATA). At the start it holds a copy of the program's file. Call
; these on the kernel's stack (in init and event), not on a stack
; inside #4000-#7FFF. On a 6128 it is bank 4, which the kernel uses
; too: what is there is lost when another program or a view is loaded.
; With a RAM expansion (version 21) each program gets a bank of its own
; at its first such call, while two banks are free, with bank 4 copied
; in: it keeps what is there until the program ends, whatever runs
; meanwhile. VX_DATA says which (and takes the bank, if it can).

; VOS_BLIT draws an image, whole bytes of screen memory (2 pixels in
; mode 0, 4 in mode 1; x is rounded down to a byte). The source is, per
; row, pairs of bytes: a mask (1 = the image's pixel) and the pixels.
; Pixels outside the mask keep what is on the screen. The image must be
; on the screen. VOS_SOUND: notes stop by themselves after B frames;
; VOS_EXIT silences everything.
;
; VOS_SPLIT: lines y1..y2-1 are shown in mode 0, the rest in mode 1
; (0 < y1 < y2 <= 259). The colours are firmware colours for pens 0..3,
; first in the mode 1 bands, then in the mode 0 band; pens 4..15 come
; from VOS_PALETTE. VOS_MODE then only picks how the program draws:
; draw each band in its own mode, and leave mode 0 selected for
; dialogs. The kernel draws its menu bar in mode 1 and its menus in
; mode 0; with menus, y1 must be 12. Event x is in pixels of the band
; the pointer is in. A boundary right below line 22, 74, 126, 178 or
; 230 costs nothing; any other line waits for it in the interrupt (at
; y1 = 12: 14% of the time). Disc transfers may disturb the split
; for a moment. VOS_EXIT ends it.

; Icon (optional): "IC" at +12 (VOS_ICON), then 16 rows of 8 (mask,
; pixels) pairs, as VOS_BLIT draws them: 16 x 16 pixels in mode 0, in
; the Launcher's palette. The Launcher shows it on the program's tile.
; tools/mkicon.py makes it from text. Init then starts at +270. The
; Launcher reads it from the disc: while the program runs, its 256
; bytes after "IC" are free for buffers (PAINT's icon_ram).
VOS_ICON        equ 12
VOS_ICON_SIZE   equ 256

; Program texts: numbers VT_FIRST and up, in menus, dialogs, VOS_MSG.
; VOS_TEXTS table: db count, db the other language's code ("EL"), then
; per text dw English, dw other (0 = the English one). The other text
; is shown when the language pack is in that language (version 11).
; Texts end with 0; "|" starts a new line in dialogs.
VT_FIRST        equ #C0

; ---- events (HL -> type, code, char, mods, dw x, dw y) ---------------
VOS_EV_SIZE     equ 8
VE_KEY_DOWN     equ 1               ; code = key number, char = character
VE_KEY_UP       equ 2
VE_KEY_REPEAT   equ 3
VE_PTR_MOVE     equ 4
VE_PTR_DOWN     equ 5
VE_PTR_UP       equ 6
VE_LANG         equ 7               ; the keyboard language changed
VE_FRAME        equ 8               ; with VOS_TICKS on
VMOD_SHIFT      equ %00000001       ; mods: SHIFT, CONTROL held
VMOD_CONTROL    equ %00000010

; key numbers (the CPC keyboard matrix: line * 8 + bit)
VK_UP           equ 0
VK_RIGHT        equ 1
VK_DOWN         equ 2
VK_ENTER        equ 6
VK_LEFT         equ 8
VK_COPY         equ 9
VK_RETURN       equ 18
VK_SPACE        equ 47
VK_ESC          equ 66
VK_TAB          equ 68
VK_DEL          equ 79

; shared commands for VOS_COMMAND and the VIEW / HELP menus
VC_QUIT         equ 6
VC_LANG         equ 7
VC_KEYS         equ 8
VC_ABOUT        equ 9
VC_DESKTOP      equ 16
VC_LAUNCHER     equ 17
VC_COMMANDER    equ 18
VC_SETUP        equ 19
VC_APP          equ 32              ; a program's own commands: VC_APP + n
                                    ; (the VIEW and HELP menus send 6-19)

; menu separators, and system texts a program may use (in dialogs, as
; buttons, or with VOS_MSG)
VOS_SEPARATOR   equ #FF
VM_OK           equ 17              ; = MSG_BTN_OK (kernel/api.asm checks)
VM_YES          equ 18
VM_NO           equ 19
