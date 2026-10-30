; =====================================================================
; test_script.asm - scripted key presses for emulator tests
;
; Built only with -DTEST_SCRIPT=n (make test-input, ...). Caprice32 can type
; text into the emulated CPC but cannot press cursor keys or COPY, so
; this script ORs key bits into kbd_now after each matrix scan, by frame
; number since boot. Everything after the scan (events, repeat, pointer)
; runs as for real keys. Keys the harness types itself are masked out:
; Z (used to wait, tools/cap32_shot.sh) and SHIFT, \ and 8 (Caprice32
; types "\(" before taking a screenshot). Otherwise their events would
; keep the pointer hidden at the moment of the shot.
;
; M8b/M8c Studio, English UI. Drive A: VOS.BIN, the view overlays,
; GREEK.LNG, DEMO.BIN, MIXED.BIN, STUDIO.BIN, PONG, CATCH, STARCAT,
; COUNTER, FLAP.VBN, FLAP.VBS, CALC.VBN, CALC.VBS, CLOCK.BIN, TICKER.VBN,
; TICKER.VBS, VBRUN.SYS, MINES.VBN, MINES.VBS.
; Expected result:
;   frame  300  F2           -> Launcher
;   frame  420, 470 RIGHT    -> STUDIO chosen
;   frame  560  RETURN       -> Studio: stage and sprites in mode 0,
;                               palette, script and status in mode 1
;   frame  800  DOWN         -> line 2 (SPEED 2 2)
;   frame  850  RIGHT        -> its first slot
;   frame  900  5            -> SPEED 5 2
;   frame  950  TAB          -> the palette
;   frame 1000  RIGHT        -> CONTROL
;   frame 1050  DOWN         -> REPEAT
;   frame 1100  RETURN       -> REPEAT 10 and END below SPEED
;   frame 1150  TAB          -> the stage
;   frame 1200-1239 RIGHT held -> the sprite moves right
;   frame 1280  C            -> its next colour
;   frame 1330  TAB          -> the script again
;   frame 1380  CONTROL+S    -> name dialog with NONAME
;   frame 1450  RETURN       -> NONAME.VBS saved
;   frame 1600  CONTROL+N    -> "clear the program?"
;   frame 1650  RETURN       -> yes: the new program
;   frame 1750  CONTROL+O    -> the file list
;   frame 1850  UP           -> from the first file to the last,
;                               NONAME.VBS
;   frame 2050  RETURN       -> opened: SPEED 5 2, REPEAT 10, the
;                               orange sprite at 116 120
;   (test only) the pointer is placed and COPY clicks:
;   frame 2200  click on IF in the palette -> IF KEY SPACE, END below
;                               the first line
;   frame 2350  click on its first slot -> chosen
;   frame 2500  click on it again -> TOUCHING 1
;   frame 2650  click on the stage at 20, 40 -> the sprite at 38 66
;   frame 2750  CONTROL+R    -> NONAME.VBS and NONAME.VBN saved, the
;                               program runs: the sprite bounces
;   frame 3400  CONTROL+Q    -> it stops; Studio starts again with
;                               NONAME.VBS open
; =====================================================================

; ---------------------------------------------------------------------
; test_inject - interrupt context, right after the matrix is read
; Destroys: AF, DE, HL, IX
; ---------------------------------------------------------------------
test_inject:
        IFDEF TEST_DUMP                 ; from frame TEST_DUMP: the stack
        ld a,(int_ticks)                ; on the screen (test_show), now
        and #3F                         ; and then (it takes a while; by
        jr nz,.no_dump                  ; ticks, which never stop)
        ld hl,(int_frames)
        ld de,TEST_DUMP
        or a
        sbc hl,de
        call nc,test_show
.no_dump:
        ENDIF
        ld a,(kbd_now + 8)          ; hide Z: the harness types it as a wait
        and %01111111
        ld (kbd_now + 8),a
        ld a,(kbd_now + 2)          ; hide SHIFT and \, and 8 below: Caprice32
        and %10011111               ; types "\(" just before each screenshot
        ld (kbd_now + 2),a
        ld a,(kbd_now + 5)
        and %11111110
        ld (kbd_now + 5),a
        ld hl,(test_frame)          ; frames as scans of the keyboard (one
        inc hl                      ; a frame): int_frames stops while
        ld (test_frame),hl          ; VSYNC goes unseen (disc transfers),
        ld ix,test_keys             ; and a key would stay held, repeating
.entry:
        ld e,(ix+0)
        ld d,(ix+1)
        ld a,d
        and e
        inc a
        ret z                       ; #FFFF ends the script
        push hl
        or a
        sbc hl,de                   ; before the start?
        pop hl
        jr c,.next
        ld e,(ix+2)
        ld d,(ix+3)
        push hl
        or a
        sbc hl,de                   ; before the end?
        pop hl
        jr nc,.next
        ld a,(ix+4)
        cp #80                      ; not a key: cursor keys move the
        jr c,.key                   ; pointer (1) or not (0)
        jr nz,.ptr_x
        ld a,(ix+5)
        ld (ptr_keys_on),a
        jr .next
.ptr_x:
        cp #81                      ; the pointer to x = bits * 2
        jr nz,.ptr_y
        ld a,(ix+5)
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        ld (ptr_x),hl
        ex de,hl
        jr .next
.ptr_y:
        ld a,(ix+5)                 ; #82: to y = bits
        ld (ptr_y),a
        xor a
        ld (ptr_y + 1),a
        jr .next
.key:
        push hl
        ld a,(ix+4)
        ld hl,kbd_now
        ld e,a
        ld d,0
        add hl,de
        ld a,(ix+5)
        or (hl)
        ld (hl),a
        pop hl
.next:
        ld de,6
        add ix,de
        jr .entry

        IFDEF TEST_TRACE
; -DTEST_TRACE: each interrupt, after the mixed screen's waits, adds 3
; bytes to a ring of TT_SIZE at TT_BUF: the slice it counted as (bits
; 0..2) and bit 7 = VSYNC then, int_frames' low byte, and the high
; byte of the address it interrupted. With -DTEST_DUMP it is shown on
; the screen now and then (test_show_ring).
TT_BUF          equ GAP2 + 700      ; GAP2 is free from fs_blist's end
TT_SIZE         equ 96
TT_POS          equ GAP2 + 698
test_ring:
        ld b,PPI_B >> 8
        in a,(c)
        rrca
        and #80
        ld hl,int_slice
        or (hl)
        ld e,a
        ld hl,12                    ; the interrupted PC: past this call
        add hl,sp                   ; and int_handler's 5 pushes
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (tt_pc),hl
        ld hl,(TT_POS)              ; inside the ring? (not at boot)
        ld bc,TT_BUF
        or a
        sbc hl,bc
        jr c,.start
        ld a,l
        cp TT_SIZE
        jr c,.inside
.start:
        ld hl,0
.inside:
        add hl,bc
        ld (hl),e
        inc hl
        ld a,(int_frames)           ; frames (VSYNC seen), PC high
        ld (hl),a
        inc hl
        ld a,(tt_pc + 1)
        ld (hl),a
        inc hl
        ld (TT_POS),hl
        IFDEF TEST_DUMP                 ; the ring on the screen, now and
        ld a,(int_ticks)                ; then, whatever the frame count
        and #3F
        call z,test_show_ring
        ENDIF
        ret
tt_pc:          dw 0
        ENDIF

        IFDEF TEST_DUMP
; -DTEST_DUMP=frame: 96 bytes from the stack, as bits on the top 8 lines
; of the screen (12 bytes a line, a bit = a screen byte, #C0 or 0: its
; first pixel is pen 1 or 0 in either mode), to read from a screenshot. At SP + 2: test_inject's return, then
; kbd_scan's, IX, HL, DE, BC, AF (int_handler), the interrupted PC.
        IFDEF TEST_TRACE
test_show_ring:
        ld hl,TT_BUF
        jr test_show.at
        ENDIF
test_show:
        IFDEF TEST_DUMP_AT              ; or 96 bytes from there
        ld hl,TEST_DUMP_AT
        ELSE
        ld hl,2
        add hl,sp
        ENDIF
.at:
        ld de,SCREEN_TOP
        ld c,8
.line:
        push de
        ld b,12
.byte:
        push bc
        ld c,(hl)
        inc hl
        ld b,8
.bit:
        sla c
        sbc a,a
        and #C0                     ; pen 1 in mode 0 and in mode 1
        ld (de),a
        inc de
        djnz .bit
        pop bc
        djnz .byte
        pop de
        ld a,d
        add a,8
        ld d,a
        dec c
        jr nz,.line
        ret
        ENDIF

test_frame:     dw 0

; dw first frame, frame after the last; db matrix line, bits
; (line #80: bits = ptr_keys_on; #81: pointer x = bits * 2, in pixels
; of the mode the pointer is in; #82: pointer y = bits)
        IF TEST_SCRIPT == 2
; make test-calc (-DTEST_SCRIPT=2): CALC.VBN, a Studio program
; (blocks/examples/calc.vbt), then Studio with CALC.VBS. Expected:
;   frame  300  F2           -> Launcher
;   frame  420, 470 DOWN, 510, 535 RIGHT -> CALC chosen (after
;                               COUNTER and FLAP)
;   frame  560  RETURN       -> the calculator in mode 1: a window,
;                               16 buttons
;   (the pointer is placed and COPY clicks)
;   frame  950, 1050, 1150   -> 1, 2, +: 12 shown
;   frame 1250, 1350         -> 3, =: 15 shown
;   frame 1500  CONTROL+Q    -> the Launcher, CALC still chosen
;   frame 1700, 1750 UP, 1900 RETURN -> Studio
;   frame 2100  CONTROL+O    -> the file list
;   frame 2150-2346 UP x8, 2400 RETURN -> from the first file to the
;                               last (BRICKS.VBN), then up to CALC.VBS:
;                               opened
;   frame 2600  TAB, 2650 LEFT -> the palette: WINDOWS
;   frame 2800  RETURN       -> WINDOW added, the dialog asks its text
;   frame 2900, 2950 H, I, 3050 RETURN -> WINDOW "ΗΙ" 120 100
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000100   ; DOWN
        dw  470,  474 : db 0, %00000100   ; DOWN
        dw  510,  514 : db 0, %00000010   ; RIGHT
        dw  535,  539 : db 0, %00000010   ; RIGHT
        dw  560,  564 : db 2, %00000100   ; RETURN
        dw  900,  901 : db #80, 1         ; COPY is the left button
        dw  900, 1000 : db #81, 56        ; 1 (x = 112 in mode 1)
        dw  900, 1000 : db #82, 161
        dw  950,  954 : db 1, %00000010   ; COPY
        dw 1000, 1100 : db #81, 80        ; 2
        dw 1000, 1100 : db #82, 161
        dw 1050, 1054 : db 1, %00000010
        dw 1100, 1200 : db #81, 128       ; +
        dw 1100, 1200 : db #82, 181
        dw 1150, 1154 : db 1, %00000010
        dw 1200, 1300 : db #81, 104       ; 3
        dw 1200, 1300 : db #82, 161
        dw 1250, 1254 : db 1, %00000010
        dw 1300, 1400 : db #81, 104       ; =
        dw 1300, 1400 : db #82, 181
        dw 1350, 1354 : db 1, %00000010
        dw 1450, 1451 : db #80, 0
        dw 1495, 1510 : db 2, %10000000   ; CONTROL
        dw 1500, 1504 : db 8, %00001000   ; Q
        dw 1700, 1704 : db 0, %00000001   ; UP
        dw 1750, 1754 : db 0, %00000001   ; UP
        dw 1900, 1904 : db 2, %00000100   ; RETURN
        dw 2095, 2110 : db 2, %10000000   ; CONTROL
        dw 2100, 2104 : db 4, %00000100   ; O
        dw 2150, 2154 : db 0, %00000001   ; UP: the last file (BRICKS.VBN)
        dw 2178, 2182 : db 0, %00000001   ; UP: MINES.VBS
        dw 2206, 2210 : db 0, %00000001   ; UP: MINES.VBN
        dw 2234, 2238 : db 0, %00000001   ; UP: VBRUN.SYS
        dw 2262, 2266 : db 0, %00000001   ; UP: TICKER.VBS
        dw 2290, 2294 : db 0, %00000001   ; UP: TICKER.VBN
        dw 2318, 2322 : db 0, %00000001   ; UP: CLOCK.BIN
        dw 2346, 2350 : db 0, %00000001   ; UP: CALC.VBS
        dw 2400, 2404 : db 2, %00000100   ; RETURN
        dw 2600, 2604 : db 8, %00010000   ; TAB
        dw 2650, 2654 : db 1, %00000001   ; LEFT
        dw 2800, 2804 : db 2, %00000100   ; RETURN
        dw 2900, 2904 : db 5, %00010000   ; H
        dw 2950, 2954 : db 4, %00001000   ; I
        dw 3050, 3054 : db 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 24
; make test-clip (-DTEST_SCRIPT=24): the clipboard. A: the test disc
; with NOTEPAD.BIN, B: markdown.dsk with HELLO.TXT (as test-open).
; Expected:
;   frame  300  F3, 400 TAB, 450 500 DOWN, 600 RETURN -> NOTEPAD with
;                               HELLO.TXT
;   frame  800  SHIFT held, RIGHT x6 -> "HELLO " selected (inverted)
;   frame 1050  CONTROL+C    -> copied
;   frame 1100  DOWN         -> no selection, the second line
;   frame 1150  CONTROL+V    -> "HELLO " at the start of line 2
;   frame 1300  CONTROL+A    -> all selected
;   frame 1400  CONTROL+X    -> an empty text
;   frame 1500  CONTROL+V    -> the two lines back
;   frame 1600  CONTROL+Q, 1700 RETURN (YES) -> the Commander, on
;                               HELLO.TXT again
;   frame 1800  UP, 1850 RETURN -> MARKDOWN with README.MD
;   frame 2050  CONTROL+V    -> the two lines before its first line
test_keys:
        dw  300,  304 : db 0, %00100000   ; F3
        dw  400,  404 : db 8, %00010000   ; TAB: the B: panel
        dw  450,  454 : db 0, %00000100   ; DOWN
        dw  500,  504 : db 0, %00000100   ; DOWN: HELLO.TXT
        dw  600,  604 : db 2, %00000100   ; RETURN: NOTEPAD
        dw  800, 1000 : db 2, %00100000   ; SHIFT, held
        dw  820,  824 : db 0, %00000010   ; RIGHT
        dw  840,  844 : db 0, %00000010
        dw  860,  864 : db 0, %00000010
        dw  880,  884 : db 0, %00000010
        dw  900,  904 : db 0, %00000010
        dw  920,  924 : db 0, %00000010
        dw 1045, 1060 : db 2, %10000000   ; CONTROL
        dw 1050, 1054 : db 7, %01000000   ; C
        dw 1100, 1104 : db 0, %00000100   ; DOWN
        dw 1145, 1160 : db 2, %10000000   ; CONTROL
        dw 1150, 1154 : db 6, %10000000   ; V
        dw 1295, 1310 : db 2, %10000000   ; CONTROL
        dw 1300, 1304 : db 8, %00100000   ; A
        dw 1395, 1410 : db 2, %10000000   ; CONTROL
        dw 1400, 1404 : db 7, %10000000   ; X
        dw 1495, 1510 : db 2, %10000000   ; CONTROL
        dw 1500, 1504 : db 6, %10000000   ; V
        dw 1595, 1610 : db 2, %10000000   ; CONTROL
        dw 1600, 1604 : db 8, %00001000   ; Q
        dw 1700, 1704 : db 2, %00000100   ; RETURN: YES, leave it
        dw 1800, 1804 : db 0, %00000001   ; UP: README.MD
        dw 1850, 1854 : db 2, %00000100   ; RETURN: MARKDOWN
        dw 2045, 2060 : db 2, %10000000   ; CONTROL
        dw 2050, 2054 : db 6, %10000000   ; V
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 23
; make test-sysinfo (-DTEST_SCRIPT=23): SYSINFO (myapps/sysinfo) and
; VOS_EXT. A: the test disc with SYSINFO.BIN last, B: markdown.dsk.
; Expected:
;   frame  300  F3           -> the Commander
;   frame  400-850 DOWN held -> the last file, SYSINFO.BIN
;   frame  900  RETURN       -> SYSINFO: V-OS 0.10, API 15, the free K
;                               on A: and on B:
;   frame 1100  CONTROL+R    -> the same, read again
;   frame 1250  CONTROL+Q    -> the Commander again
test_keys:
        dw  300,  304 : db 0, %00100000   ; F3
        dw  400,  850 : db 0, %00000100   ; DOWN, held
        dw  900,  904 : db 2, %00000100   ; RETURN: SYSINFO
        dw 1095, 1110 : db 2, %10000000   ; CONTROL
        dw 1100, 1104 : db 6, %00000100   ; R
        dw 1245, 1260 : db 2, %10000000   ; CONTROL
        dw 1250, 1254 : db 8, %00001000   ; Q
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 22
; make test-open (-DTEST_SCRIPT=22): files opened by their type. B: is
; build/markdown.dsk with a HELLO.TXT added. Expected:
;   frame  300  F3, 400 TAB  -> the Commander, the B: panel
;   frame  450  DOWN         -> README.MD
;   frame  550  RETURN       -> MARKDOWN (from B:) with README.MD
;   frame  800  CONTROL+Q    -> the Commander again
;   frame  950  DOWN x2      -> HELLO.TXT
;   frame 1100  RETURN       -> NOTEPAD (from A:) with HELLO.TXT
test_keys:
        dw  300,  304 : db 0, %00100000   ; F3
        dw  400,  404 : db 8, %00010000   ; TAB: the B: panel
        dw  450,  454 : db 0, %00000100   ; DOWN
        dw  550,  554 : db 2, %00000100   ; RETURN: open README.MD
        dw  795,  810 : db 2, %10000000   ; CONTROL
        dw  800,  804 : db 8, %00001000   ; Q
        dw  950,  954 : db 0, %00000100   ; DOWN
        dw 1000, 1004 : db 0, %00000100   ; DOWN
        dw 1100, 1104 : db 2, %00000100   ; RETURN: open HELLO.TXT
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 21
; make test-markdown (-DTEST_SCRIPT=21): MARKDOWN (myapps/markdown)
; from its own disc, build/markdown.dsk, in drive B:. Expected:
;   frame  300  F2, 450 TAB  -> the Launcher, drive B: MARKDOWN
;   frame  600  RETURN       -> MARKDOWN, an empty text
;   frame  750  CONTROL+O    -> the .MD files of B: (README.MD)
;   frame  850  RETURN       -> README.MD in the editor, with its marks
;   frame 1000  CONTROL+P    -> the page: headings, bold, italic, code,
;                               lists, a quote, a line, a code block
;   frame 1150  RIGHT        -> the page a screen on
;   frame 1300  RETURN       -> the text again
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  450,  454 : db 8, %00010000   ; TAB: drive B:
        dw  600,  604 : db 2, %00000100   ; RETURN: MARKDOWN
        dw  745,  760 : db 2, %10000000   ; CONTROL
        dw  750,  754 : db 4, %00000100   ; O
        dw  850,  854 : db 2, %00000100   ; RETURN: README.MD
        dw  995, 1010 : db 2, %10000000   ; CONTROL
        dw 1000, 1004 : db 3, %00001000   ; P
        dw 1150, 1154 : db 0, %00000010   ; RIGHT
        dw 1300, 1304 : db 2, %00000100   ; RETURN: the text
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 20
; make test-music (-DTEST_SCRIPT=20): MUSIC (myapps/music) from its own
; disc, build/music.dsk, in drive B:. Expected:
;   frame  300  F2, 450 TAB  -> the Launcher, drive B: MUSIC
;   frame  600  RETURN       -> MUSIC: B:, NO SONG, the buttons
;   frame  750  CONTROL+O    -> the .MUS files of B:
;   frame  850  RETURN       -> the first, AGANAMEM: PLAYING, the bars
;                               move with the channels' volumes
;   frame 1200  F2           -> the Launcher; the song goes on behind it
;   frame 1400  RETURN       -> MUSIC again, still PLAYING
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  450,  454 : db 8, %00010000   ; TAB: drive B:
        dw  600,  604 : db 2, %00000100   ; RETURN: MUSIC
        dw  745,  760 : db 2, %10000000   ; CONTROL
        dw  750,  754 : db 4, %00000100   ; O
        dw  850,  854 : db 2, %00000100   ; RETURN: the first song
        dw 1200, 1204 : db 1, %01000000   ; F2
        dw 1400, 1404 : db 2, %00000100   ; RETURN: MUSIC again
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 19
; make test-about (-DTEST_SCRIPT=19): HELP > ABOUT V-OS. Expected:
;   frame  300  F2           -> the Launcher
;   frame  400  ESC, 450 480 RIGHT x2, 520 DOWN -> the HELP menu,
;                               ABOUT V-OS chosen
;   frame  600  RETURN       -> V-OS 0.1 BETA, the build's date,
;                               AMSTRAD CPC 6128, REVIVE8BIT, 2026,
;                               ARCHITECT: VASPER
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  400,  404 : db 8, %00000100   ; ESC: the menus
        dw  450,  454 : db 0, %00000010   ; RIGHT
        dw  480,  484 : db 0, %00000010   ; RIGHT: HELP
        dw  520,  524 : db 0, %00000100   ; DOWN: ABOUT V-OS
        dw  600,  604 : db 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 18
; make test-paint (-DTEST_SCRIPT=18): PAINT (myapps/paint), last on the
; test disc. The cursor keys move the pointer, COPY is its button.
; Expected:
;   frame  300  F2, 420-480 DOWN x3, 520-610 RIGHT x4 -> PAINT chosen
;   frame  660  RETURN       -> PAINT: a white picture, the tools
;                               (PENCIL on yellow), the 16 colours
;   frame  800-860 TAB x3    -> red chosen
;   frame  900-1000 COPY, 920-950 UP held -> a red line upwards
;   frame 1050  x, TAB       -> BOX, green
;   frame 1100-1200 COPY, 1110-1145 LEFT held -> a green line (a box
;                               one pixel high)
;   frame 1250  f, TAB       -> FILL, yellow
;   frame 1300  COPY         -> the area under the pointer yellow
;   frame 1500  ESC, 1550 DOWN, 1600 RETURN -> NEW LAYERS; 1650
;                               RETURN: YES (not saved) -> 64 x 64, twice
;                               as big, the layers 3 2 1 (2 chosen)
;   frame 1700  1, f         -> layer 1, FILL (yellow still)
;   frame 1750  COPY         -> layer 1 all yellow (a few seconds)
;   frame 2300  3, x, 2350 TAB -> layer 3, BOX, cyan
;   frame 2400-2500 COPY, 2410-2450 UP held -> a cyan line (a box one
;                               pixel wide)
;   frame 2600  h            -> layer 3 hidden: the line goes
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000100   ; DOWN
        dw  450,  454 : db 0, %00000100   ; DOWN
        dw  480,  484 : db 0, %00000100   ; DOWN
        dw  520,  524 : db 0, %00000010   ; RIGHT
        dw  550,  554 : db 0, %00000010   ; RIGHT
        dw  580,  584 : db 0, %00000010   ; RIGHT
        dw  610,  614 : db 0, %00000010   ; RIGHT
        dw  660,  664 : db 2, %00000100   ; RETURN: PAINT
        dw  800,  804 : db 8, %00010000   ; TAB
        dw  830,  834 : db 8, %00010000   ; TAB
        dw  860,  864 : db 8, %00010000   ; TAB: red
        dw  900, 1000 : db 1, %00000010   ; COPY held
        dw  920,  950 : db 0, %00000001   ; UP held
        dw 1050, 1054 : db 7, %10000000   ; x: BOX
        dw 1070, 1074 : db 8, %00010000   ; TAB: green
        dw 1100, 1200 : db 1, %00000010   ; COPY held
        dw 1110, 1145 : db 1, %00000001   ; LEFT held
        dw 1250, 1254 : db 6, %00100000   ; f: FILL
        dw 1270, 1274 : db 8, %00010000   ; TAB: yellow
        dw 1300, 1304 : db 1, %00000010   ; COPY: fill
        dw 1500, 1504 : db 8, %00000100   ; ESC: the menu
        dw 1550, 1554 : db 0, %00000100   ; DOWN
        dw 1600, 1604 : db 2, %00000100   ; RETURN: NEW LAYERS
        dw 1650, 1654 : db 2, %00000100   ; RETURN: YES, not saved
        dw 1700, 1704 : db 8, %00000001   ; 1: layer 1
        dw 1720, 1724 : db 6, %00100000   ; f: FILL
        dw 1750, 1754 : db 1, %00000010   ; COPY: fill
        dw 2300, 2304 : db 7, %00000010   ; 3: layer 3
        dw 2320, 2324 : db 7, %10000000   ; x: BOX
        dw 2350, 2354 : db 8, %00010000   ; TAB: cyan
        dw 2400, 2500 : db 1, %00000010   ; COPY held
        dw 2410, 2450 : db 0, %00000001   ; UP held
        dw 2600, 2604 : db 5, %00010000   ; h: hide
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 17
; make test-notepad (-DTEST_SCRIPT=17): NOTEPAD (myapps/notepad), last on
; the test disc. Expected:
;   frame  300  F2, 420-480 DOWN x3, 520-610 RIGHT x4 -> NOTEPAD chosen
;                               (page 2, after CLOCK ... BRICKS)
;   frame  660  RETURN       -> NOTEPAD: an empty text, the cursor, the
;                               last line "A:NONAME.TXT  LINE 1 COL 1"
;   frame  800  h i RETURN v o s -> "hi" and "vos", LINE 2 COL 4, "*"
;   frame 1000  LEFT x2, 1060 DEL -> "os", the cursor before o
;   frame 1150  CONTROL+S    -> the name dialog with NONAME
;   frame 1250-1400 DEL x6, 1430 t, 1480 RETURN -> saved: "A:T.TXT"
;   frame 1600  CONTROL+N    -> an empty text again
;   frame 1700  CONTROL+O    -> the files of A:, to open one
;   frame 1850  ESC          -> no file: the empty text
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000100   ; DOWN
        dw  450,  454 : db 0, %00000100   ; DOWN
        dw  480,  484 : db 0, %00000100   ; DOWN
        dw  520,  524 : db 0, %00000010   ; RIGHT
        dw  550,  554 : db 0, %00000010   ; RIGHT
        dw  580,  584 : db 0, %00000010   ; RIGHT
        dw  610,  614 : db 0, %00000010   ; RIGHT
        dw  660,  664 : db 2, %00000100   ; RETURN: NOTEPAD
        dw  800,  804 : db 5, %00010000   ; h
        dw  830,  834 : db 4, %00001000   ; i
        dw  860,  864 : db 2, %00000100   ; RETURN
        dw  890,  894 : db 6, %10000000   ; v
        dw  920,  924 : db 4, %00000100   ; o
        dw  950,  954 : db 7, %00010000   ; s
        dw 1000, 1004 : db 1, %00000001   ; LEFT
        dw 1030, 1034 : db 1, %00000001   ; LEFT
        dw 1060, 1064 : db 9, %10000000   ; DEL
        dw 1145, 1160 : db 2, %10000000   ; CONTROL
        dw 1150, 1154 : db 7, %00010000   ; S
        dw 1250, 1254 : db 9, %10000000   ; DEL
        dw 1280, 1284 : db 9, %10000000   ; DEL
        dw 1310, 1314 : db 9, %10000000   ; DEL
        dw 1340, 1344 : db 9, %10000000   ; DEL
        dw 1370, 1374 : db 9, %10000000   ; DEL
        dw 1400, 1404 : db 9, %10000000   ; DEL
        dw 1430, 1434 : db 6, %00001000   ; t
        dw 1480, 1484 : db 2, %00000100   ; RETURN: save
        dw 1595, 1610 : db 2, %10000000   ; CONTROL
        dw 1600, 1604 : db 5, %01000000   ; N
        dw 1695, 1710 : db 2, %10000000   ; CONTROL
        dw 1700, 1704 : db 4, %00000100   ; O
        dw 1850, 1854 : db 8, %00000100   ; ESC
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 16
; make test-vrouves (-DTEST_SCRIPT=16): VROUVES (myapps/vrouves) from
; its own disc, build/vrouves.dsk, in drive B:. Expected:
;   frame  300  F2           -> the Launcher, drive A:
;   frame  450  TAB          -> drive B: "B: PAGE 1/1", VROUVES with its
;                               icon, selected
;   frame  600  RETURN       -> stage 1, from B:, with its name under
;                               the HUD; on the bar only the Cretan and
;                               the Psssst
;   frame  800  SPACE        -> a Cretan on the cursor's cell (10, 6)
;   frame  850  UP, 880 4, 910 SPACE -> Psssst on (10, 5)
;   frame  960  N            -> wave 1: guards come down the road, the
;                               keys replace the stage's name
;   frame 1100  ESC, 1130-1220 DOWN x4, 1250 RETURN -> HIGH SCORES:
;                               the best five over the playfield
;   frame 1900  ^Q           -> back: the Launcher, still on B:
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2: the Launcher
        dw  450,  454 : db 8, %00010000   ; TAB: drive B:
        dw  600,  604 : db 2, %00000100   ; RETURN: VROUVES
        dw  800,  804 : db 5, %10000000   ; SPACE: a Cretan
        dw  850,  854 : db 0, %00000001   ; UP
        dw  880,  884 : db 7, %00000001   ; 4: Psssst
        dw  910,  914 : db 5, %10000000   ; SPACE
        dw  960,  964 : db 5, %01000000   ; N: the first wave
        dw 1100, 1104 : db 8, %00000100   ; ESC: the menu
        dw 1130, 1134 : db 0, %00000100   ; DOWN
        dw 1160, 1164 : db 0, %00000100   ; DOWN
        dw 1190, 1194 : db 0, %00000100   ; DOWN
        dw 1220, 1224 : db 0, %00000100   ; DOWN
        dw 1250, 1254 : db 2, %00000100   ; RETURN: HIGH SCORES
        dw 1895, 1910 : db 2, %10000000   ; CONTROL
        dw 1900, 1904 : db 8, %00001000   ; Q
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 15
; make test-sdk (-DTEST_SCRIPT=15): the SDK's template (sdk/template)
; built as TEMPLATE.BIN, last on the disc. Expected:
;   frame  300  F2, 420-480 DOWN x3, 520-610 RIGHT x4 -> TEMPLATE chosen
;                               (page 2, after CLOCK ... BRICKS)
;   frame  660  RETURN       -> its screen in mode 1: HELLO..., the
;                               seconds counting, BEEP, the box
;   frame  800-900 RIGHT held, 950-1000 UP held -> the box moves
;   frame 1100  TAB, 1130 RETURN -> BEEP focused and pressed
;   frame 1250  ESC          -> its menu: ABOUT, BACK
;   frame 1350  RETURN       -> the ABOUT dialog
;   frame 1450  RETURN       -> closed
;   frame 1550  CONTROL+Q    -> BACK: the Launcher
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000100   ; DOWN
        dw  450,  454 : db 0, %00000100   ; DOWN
        dw  480,  484 : db 0, %00000100   ; DOWN
        dw  520,  524 : db 0, %00000010   ; RIGHT
        dw  550,  554 : db 0, %00000010   ; RIGHT
        dw  580,  584 : db 0, %00000010   ; RIGHT
        dw  610,  614 : db 0, %00000010   ; RIGHT
        dw  660,  664 : db 2, %00000100   ; RETURN: TEMPLATE
        dw  800,  900 : db 0, %00000010   ; RIGHT held
        dw  950, 1000 : db 0, %00000001   ; UP held
        dw 1100, 1104 : db 8, %00010000   ; TAB
        dw 1130, 1134 : db 2, %00000100   ; RETURN: BEEP
        dw 1250, 1254 : db 8, %00000100   ; ESC: the menu
        dw 1350, 1354 : db 2, %00000100   ; RETURN: ABOUT
        dw 1450, 1454 : db 2, %00000100   ; RETURN: OK
        dw 1545, 1560 : db 2, %10000000   ; CONTROL
        dw 1550, 1554 : db 8, %00001000   ; Q
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 14
; make test-bricks (-DTEST_SCRIPT=14): BRICKS, a block game
; (blocks/examples/bricks.vbp). Expected:
;   frame  300  F2, 420-480 DOWN x3, 520-580 RIGHT x3 -> BRICKS chosen
;                               (page 2, after CLOCK, TICKER and MINES)
;   frame  630  RETURN       -> 32 bricks in four colours, the bat, and
;                               the ball served from it after 40 frames
;   frame  900-1000 RIGHT held, 1200-1300 LEFT held -> the bat moves
;   later       bricks hit disappear and SCORE grows; LIVES goes down
;               when the ball is missed, and at 0 GAME OVER
;   frame 3600  SPACE        -> a new game: all bricks, SCORE 0, LIVES 3
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000100   ; DOWN
        dw  450,  454 : db 0, %00000100   ; DOWN
        dw  480,  484 : db 0, %00000100   ; DOWN
        dw  520,  524 : db 0, %00000010   ; RIGHT
        dw  550,  554 : db 0, %00000010   ; RIGHT
        dw  580,  584 : db 0, %00000010   ; RIGHT
        dw  630,  634 : db 2, %00000100   ; RETURN: BRICKS
        dw  900, 1000 : db 0, %00000010   ; RIGHT held
        dw 1200, 1300 : db 1, %00000001   ; LEFT held
        dw 3600, 3604 : db 5, %10000000   ; SPACE: a new game
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 13
; make test-vars (-DTEST_SCRIPT=13): Studio's 128 variables, with
; VARS.VBS (blocks/examples/vars.vbt) last on the disc. Expected:
;   frame  300  F2, 400, 440 RIGHT, 480 RETURN -> STUDIO
;   frame  800  CONTROL+O, 860 UP, 920 RETURN -> VARS.VBS opened: its
;                               lines name A, A1, H15, B2, C12
;   frame 1000  DOWN, 1030 RIGHT, 1060, 1090 A -> SET A TO 1 becomes
;                               SET A1, then SET A2 TO 1
;   frame 1130-1350 DOWN x23 -> LOAD VARS A-H FROM "row1"
;   frame 1380, 1410 RIGHT x2, 1440 A -> LOAD VARS A1-H1 FROM "row1"
;   frame 1600  CONTROL+R    -> saved, VARS.VBN written and run: it
;                               shows 0 5 7 12 10 (A is not set now),
;                               then after SAVE VARS and LOAD VARS
;                               0 9 7 12 10
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  400,  404 : db 0, %00000010   ; RIGHT
        dw  440,  444 : db 0, %00000010   ; RIGHT
        dw  480,  484 : db 2, %00000100   ; RETURN: STUDIO
        dw  795,  810 : db 2, %10000000   ; CONTROL
        dw  800,  804 : db 4, %00000100   ; O
        dw  860,  864 : db 0, %00000001   ; UP: the last file (VARS.VBS)
        dw  920,  924 : db 2, %00000100   ; RETURN
        dw 1000, 1004 : db 0, %00000100   ; DOWN: SET A TO 1
        dw 1030, 1034 : db 0, %00000010   ; RIGHT: its variable
        dw 1060, 1064 : db 8, %00100000   ; A: A1
        dw 1090, 1094 : db 8, %00100000   ; A: A2
        dw 1130, 1134 : db 0, %00000100   ; DOWN
        dw 1140, 1144 : db 0, %00000100   ; DOWN
        dw 1150, 1154 : db 0, %00000100   ; DOWN
        dw 1160, 1164 : db 0, %00000100   ; DOWN
        dw 1170, 1174 : db 0, %00000100   ; DOWN
        dw 1180, 1184 : db 0, %00000100   ; DOWN
        dw 1190, 1194 : db 0, %00000100   ; DOWN
        dw 1200, 1204 : db 0, %00000100   ; DOWN
        dw 1210, 1214 : db 0, %00000100   ; DOWN
        dw 1220, 1224 : db 0, %00000100   ; DOWN
        dw 1230, 1234 : db 0, %00000100   ; DOWN
        dw 1240, 1244 : db 0, %00000100   ; DOWN
        dw 1250, 1254 : db 0, %00000100   ; DOWN
        dw 1260, 1264 : db 0, %00000100   ; DOWN
        dw 1270, 1274 : db 0, %00000100   ; DOWN
        dw 1280, 1284 : db 0, %00000100   ; DOWN
        dw 1290, 1294 : db 0, %00000100   ; DOWN
        dw 1300, 1304 : db 0, %00000100   ; DOWN
        dw 1310, 1314 : db 0, %00000100   ; DOWN
        dw 1320, 1324 : db 0, %00000100   ; DOWN
        dw 1330, 1334 : db 0, %00000100   ; DOWN
        dw 1340, 1344 : db 0, %00000100   ; DOWN
        dw 1350, 1354 : db 0, %00000100   ; DOWN
        dw 1380, 1384 : db 0, %00000010   ; RIGHT, RIGHT: the group of
        dw 1410, 1414 : db 0, %00000010   ; LOAD VARS A-H FROM "row1"
        dw 1440, 1444 : db 8, %00100000   ; A: A1-H1
        dw 1595, 1610 : db 2, %10000000   ; CONTROL
        dw 1600, 1604 : db 6, %00000100   ; R
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 12
; make test-mines (-DTEST_SCRIPT=12): MINES, a Studio program
; (blocks/examples/mines.vbt): 8 x 6 cells, 8 mines. Expected:
;   frame  300  F2, 420-480 DOWN x3, 520, 550 RIGHT -> MINES chosen
;                               (page 2, after CLOCK and TICKER)
;   frame  600  RETURN       -> its window: 48 cells and NEW
;   frame 1200-2130 a click on each cell of rows 0 and 1 in turn (COPY):
;                               each opens and shows its count, until a
;                               mine: all eight mines, BOOM!, and no
;                               more opens
;   frame 2200  NEW          -> a new game, all cells closed
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000100   ; DOWN
        dw  450,  454 : db 0, %00000100   ; DOWN
        dw  480,  484 : db 0, %00000100   ; DOWN
        dw  520,  524 : db 0, %00000010   ; RIGHT
        dw  550,  554 : db 0, %00000010   ; RIGHT
        dw  600,  604 : db 2, %00000100   ; RETURN: MINES
        dw 1180, 2260 : db #80, 1         ; COPY is the left button
        dw 1200, 1260 : db #81, 46        ; cell 0 (92, 93)
        dw 1200, 1260 : db #82, 93
        dw 1230, 1234 : db 1, %00000010
        dw 1260, 1320 : db #81, 60        ; cell 1
        dw 1260, 1320 : db #82, 93
        dw 1290, 1294 : db 1, %00000010
        dw 1320, 1380 : db #81, 74        ; cell 2
        dw 1320, 1380 : db #82, 93
        dw 1350, 1354 : db 1, %00000010
        dw 1380, 1440 : db #81, 88        ; cell 3
        dw 1380, 1440 : db #82, 93
        dw 1410, 1414 : db 1, %00000010
        dw 1440, 1500 : db #81, 102       ; cell 4
        dw 1440, 1500 : db #82, 93
        dw 1470, 1474 : db 1, %00000010
        dw 1500, 1560 : db #81, 116       ; cell 5
        dw 1500, 1560 : db #82, 93
        dw 1530, 1534 : db 1, %00000010
        dw 1560, 1620 : db #81, 130       ; cell 6
        dw 1560, 1620 : db #82, 93
        dw 1590, 1594 : db 1, %00000010
        dw 1620, 1680 : db #81, 144       ; cell 7
        dw 1620, 1680 : db #82, 93
        dw 1650, 1654 : db 1, %00000010
        dw 1680, 1740 : db #81, 46        ; cell 8
        dw 1680, 1740 : db #82, 111
        dw 1710, 1714 : db 1, %00000010
        dw 1740, 1800 : db #81, 60        ; cell 9
        dw 1740, 1800 : db #82, 111
        dw 1770, 1774 : db 1, %00000010
        dw 1800, 1860 : db #81, 74        ; cell 10
        dw 1800, 1860 : db #82, 111
        dw 1830, 1834 : db 1, %00000010
        dw 1860, 1920 : db #81, 88        ; cell 11
        dw 1860, 1920 : db #82, 111
        dw 1890, 1894 : db 1, %00000010
        dw 1920, 1980 : db #81, 102       ; cell 12
        dw 1920, 1980 : db #82, 111
        dw 1950, 1954 : db 1, %00000010
        dw 1980, 2040 : db #81, 116       ; cell 13
        dw 1980, 2040 : db #82, 111
        dw 2010, 2014 : db 1, %00000010
        dw 2040, 2100 : db #81, 130       ; cell 14
        dw 2040, 2100 : db #82, 111
        dw 2070, 2074 : db 1, %00000010
        dw 2100, 2160 : db #81, 144       ; cell 15
        dw 2100, 2160 : db #82, 111
        dw 2130, 2134 : db 1, %00000010
        dw 2200, 2250 : db #81, 54        ; NEW (108, 203)
        dw 2200, 2250 : db #82, 203
        dw 2220, 2224 : db 1, %00000010
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 11
; make test-langs (-DTEST_SCRIPT=11): the language packs. Expected:
;   frame  300  F4, 400 DOWN -> Setup, LANGUAGE: ENGLISH
;   frame  450, 600, 750, 900, 1050 RIGHT -> each pack loaded and shown
;                               in its own name (Greek, FRANCAIS,
;                               ESPANOL, DEUTSCH, ITALIANO), Setup in
;                               that language
;   frame 1200  F1           -> the Desktop in Italian
;   frame 1350  CONTROL+N    -> RINOMINA; 1450 CONTROL+SHIFT: the
;                               Italian keyboard (IT); 1500-1650 the
;                               keys @ ; ] : -> e grave, a grave,
;                               u grave, o grave; 1800 ESC
test_keys:
        dw  300,  304 : db 2, %00010000   ; F4
        dw  400,  404 : db 0, %00000100   ; DOWN: LANGUAGE
        dw  450,  454 : db 0, %00000010   ; RIGHT: Greek
        dw  600,  604 : db 0, %00000010   ; RIGHT: French
        dw  750,  754 : db 0, %00000010   ; RIGHT: Spanish
        dw  900,  904 : db 0, %00000010   ; RIGHT: German
        dw 1050, 1054 : db 0, %00000010   ; RIGHT: Italian
        dw 1200, 1204 : db 1, %00100000   ; F1
        dw 1345, 1360 : db 2, %10000000   ; CONTROL
        dw 1350, 1354 : db 5, %01000000   ; N
        dw 1445, 1460 : db 2, %10000000   ; CONTROL, then
        dw 1450, 1454 : db 2, %00100000   ; SHIFT
        dw 1500, 1504 : db 3, %00000100   ; @
        dw 1550, 1554 : db 3, %00010000   ; ;
        dw 1600, 1604 : db 2, %00001000   ; ]
        dw 1650, 1654 : db 3, %00100000   ; :
        dw 1800, 1804 : db 8, %00000100   ; ESC
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 10
; make test-drag (-DTEST_SCRIPT=10): windows dragged by their title bars
; (COPY held, the cursor keys move the pointer). Expected:
;   frame  340-420 the Desktop's FILES window: a dashed outline while
;                  COPY is down, then the window there
;   frame  500  CONTROL+K    -> the KEYS dialog; 640-720 dragged
;                               left and down; 800 RETURN closes it
;   frame  900  F2, 1020-1080 DOWN x3, 1120 CONTROL+A -> CLOCK as the
;                               accessory over the Launcher; 1240-1320
;                               dragged right and down: the Launcher
;                               drawn again, then the clock there
;   frame 1500  F5 closes it; 1550 UP, 1580, 1610 RIGHT, 1660 RETURN
;                               -> CALC; 2040-2120 its window dragged
;                               right and down, with its buttons; 2200
;                               a click on 1 there: 1 shown
test_keys:
        dw  300,  420 : db #80, 1         ; COPY and the cursor keys
        dw  300,  340 : db #81, 50        ; FILES's title bar (100, 23)
        dw  300,  340 : db #82, 23
        dw  340,  420 : db 1, %00000010   ; COPY held
        dw  350,  380 : db 0, %00000010   ; RIGHT
        dw  350,  365 : db 0, %00000100   ; DOWN
        dw  495,  510 : db 2, %10000000   ; CONTROL
        dw  500,  504 : db 4, %00100000   ; K: the keys dialog
        dw  600,  740 : db #80, 1
        dw  600,  640 : db #81, 75        ; its title bar (150, 64)
        dw  600,  640 : db #82, 64
        dw  640,  720 : db 1, %00000010   ; COPY held
        dw  650,  675 : db 1, %00000001   ; LEFT
        dw  650,  680 : db 0, %00000100   ; DOWN
        dw  750,  751 : db #80, 0
        dw  800,  804 : db 2, %00000100   ; RETURN: OK
        dw  900,  904 : db 1, %01000000   ; F2
        dw 1020, 1024 : db 0, %00000100   ; DOWN
        dw 1050, 1054 : db 0, %00000100   ; DOWN
        dw 1080, 1084 : db 0, %00000100   ; DOWN
        dw 1115, 1130 : db 2, %10000000   ; CONTROL
        dw 1120, 1124 : db 8, %00100000   ; A: CLOCK as the accessory
        dw 1200, 1340 : db #80, 1
        dw 1200, 1240 : db #81, 20        ; its title bar (40, 20, mode 0)
        dw 1200, 1240 : db #82, 20
        dw 1240, 1320 : db 1, %00000010   ; COPY held
        dw 1250, 1275 : db 0, %00000010   ; RIGHT
        dw 1250, 1290 : db 0, %00000100   ; DOWN
        dw 1350, 1351 : db #80, 0
        dw 1500, 1504 : db 1, %00010000   ; F5
        dw 1550, 1554 : db 0, %00000001   ; UP
        dw 1580, 1584 : db 0, %00000010   ; RIGHT
        dw 1610, 1614 : db 0, %00000010   ; RIGHT
        dw 1660, 1664 : db 2, %00000100   ; RETURN: CALC
        dw 2000, 2140 : db #80, 1
        dw 2000, 2040 : db #81, 75        ; its title bar (150, 76)
        dw 2000, 2040 : db #82, 76
        dw 2040, 2120 : db 1, %00000010   ; COPY held
        dw 2050, 2075 : db 0, %00000010   ; RIGHT
        dw 2050, 2075 : db 0, %00000100   ; DOWN
        dw 2150, 2260 : db #80, 1         ; then its button 1, moved
        dw 2150, 2260 : db #81, 76        ; with it (152, 204): 1 shown
        dw 2150, 2260 : db #82, 204
        dw 2200, 2204 : db 1, %00000010   ; COPY
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 9
; make test-behind (-DTEST_SCRIPT=9, 576K): a program in the background.
; Expected:
;   frame  300  F2, 400, 440 RIGHT, 480 RETURN -> STUDIO
;   frame  800  ESC, 850-970 DOWN x5, 1010 RETURN -> STUDIO > IN
;                               BACKGROUND: "THE PROGRAM PAUSES THERE"
;   frame 1100  RETURN (YES) -> it goes on there now
;   frame 1150  ESC, 1200-1320 DOWN x5, 1360 RETURN -> "THE PROGRAM KEEPS
;                               RUNNING THERE"; 1450 ESC (NO)
;   frame 1550  F2, 1650, 1680 DOWN, 1710, 1740 RIGHT, 1800 RETURN ->
;                               TICKER (BEHIND RUN): seconds, a ball
;   frame 2100  F2           -> the Launcher, clean; TICKER goes on
;   frame 2200-2290 UP x3, LEFT, 2330 RETURN -> DEMO in front
;   frame 2700  F6, 2750 DOWN, 2800 RETURN -> TICKER again: it counted
;                               the time behind, the ball moved on
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  400,  404 : db 0, %00000010   ; RIGHT
        dw  440,  444 : db 0, %00000010   ; RIGHT
        dw  480,  484 : db 2, %00000100   ; RETURN
        dw  800,  804 : db 8, %00000100   ; ESC
        dw  850,  854 : db 0, %00000100   ; DOWN
        dw  880,  884 : db 0, %00000100   ; DOWN
        dw  910,  914 : db 0, %00000100   ; DOWN
        dw  940,  944 : db 0, %00000100   ; DOWN
        dw  970,  974 : db 0, %00000100   ; DOWN
        dw 1010, 1014 : db 2, %00000100   ; RETURN
        dw 1100, 1104 : db 2, %00000100   ; RETURN
        dw 1150, 1154 : db 8, %00000100   ; ESC
        dw 1200, 1204 : db 0, %00000100   ; DOWN
        dw 1230, 1234 : db 0, %00000100   ; DOWN
        dw 1260, 1264 : db 0, %00000100   ; DOWN
        dw 1290, 1294 : db 0, %00000100   ; DOWN
        dw 1320, 1324 : db 0, %00000100   ; DOWN
        dw 1360, 1364 : db 2, %00000100   ; RETURN
        dw 1450, 1454 : db 8, %00000100   ; ESC
        dw 1550, 1554 : db 1, %01000000   ; F2
        dw 1650, 1654 : db 0, %00000100   ; DOWN
        dw 1680, 1684 : db 0, %00000100   ; DOWN
        dw 1710, 1714 : db 0, %00000010   ; RIGHT
        dw 1740, 1744 : db 0, %00000010   ; RIGHT
        dw 1800, 1804 : db 2, %00000100   ; RETURN
        dw 2100, 2104 : db 1, %01000000   ; F2
        dw 2200, 2204 : db 0, %00000001   ; UP
        dw 2230, 2234 : db 0, %00000001   ; UP
        dw 2260, 2264 : db 0, %00000001   ; UP
        dw 2290, 2294 : db 1, %00000001   ; LEFT
        dw 2330, 2334 : db 2, %00000100   ; RETURN
        dw 2700, 2704 : db 0, %00010000   ; F6
        dw 2750, 2754 : db 0, %00000100   ; DOWN
        dw 2800, 2804 : db 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 8
; make test-expand (-DTEST_SCRIPT=8, 576K: a 512K RAM expansion).
; Expected:
;   frame  300  F2, 400, 440 RIGHT, 480 RETURN -> STUDIO, in a bank of
;                               the expansion
;   frame  750  F2, 850, 890 LEFT, 930 RETURN -> DEMO, in bank 5
;   frame 1100  F2, 1200 DOWN, 1260 RETURN -> PONG, in bank 5
;   frame 1450  F2, 1550, 1590 RIGHT, 1630 DOWN, 1670 RETURN -> CALC,
;                               another bank of the expansion
;   frame 1950  F6           -> STUDIO, DEMO, PONG, "> CALC"; STUDIO
;                               selected
;   frame 2050  RETURN       -> STUDIO again
;   frame 2300  F6, 2350 RETURN -> DEMO goes on
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  400,  404 : db 0, %00000010   ; RIGHT
        dw  440,  444 : db 0, %00000010   ; RIGHT
        dw  480,  484 : db 2, %00000100   ; RETURN
        dw  750,  754 : db 1, %01000000   ; F2
        dw  850,  854 : db 1, %00000001   ; LEFT
        dw  890,  894 : db 1, %00000001   ; LEFT
        dw  930,  934 : db 2, %00000100   ; RETURN
        dw 1100, 1104 : db 1, %01000000   ; F2
        dw 1200, 1204 : db 0, %00000100   ; DOWN
        dw 1260, 1264 : db 2, %00000100   ; RETURN
        dw 1450, 1454 : db 1, %01000000   ; F2
        dw 1550, 1554 : db 0, %00000010   ; RIGHT
        dw 1590, 1594 : db 0, %00000010   ; RIGHT
        dw 1630, 1634 : db 0, %00000100   ; DOWN
        dw 1670, 1674 : db 2, %00000100   ; RETURN
        dw 1950, 1954 : db 0, %00010000   ; F6
        dw 2050, 2054 : db 2, %00000100   ; RETURN
        dw 2300, 2304 : db 0, %00010000   ; F6
        dw 2350, 2354 : db 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 7
; make test-switch (-DTEST_SCRIPT=7): the program switcher (F6).
; Expected:
;   frame  250  F6           -> "NO PROGRAM IS RUNNING", 330 RETURN
;   frame  400  F2, 500 RETURN -> DEMO runs, 580 SPACE: another colour
;   frame  680  F2, 780 DOWN, 840 RETURN -> PONG runs
;   frame 1000  F6           -> PROGRAMS: DEMO selected, "> PONG"
;   frame 1100  RETURN       -> DEMO goes on, the same colour
;   frame 1250  F6, 1300 F6  -> "> DEMO", PONG then DEMO selected
;   frame 1450  ESC          -> closed, DEMO goes on
;   frame 1550  F3           -> the Commander
;   frame 1700  ESC, 1750 RIGHT, 1800-1920 DOWN x4 -> VIEW, PROGRAMS
;   frame 2050  RETURN       -> PROGRAMS: DEMO selected, none marked
;   frame 2250  DOWN, 2350 RETURN -> PONG goes on
test_keys:
        dw  250,  254 : db 0, %00010000   ; F6
        dw  330,  334 : db 2, %00000100   ; RETURN
        dw  400,  404 : db 1, %01000000   ; F2
        dw  500,  504 : db 2, %00000100   ; RETURN
        dw  580,  584 : db 5, %10000000   ; SPACE
        dw  680,  684 : db 1, %01000000   ; F2
        dw  780,  784 : db 0, %00000100   ; DOWN
        dw  840,  844 : db 2, %00000100   ; RETURN
        dw 1000, 1004 : db 0, %00010000   ; F6
        dw 1100, 1104 : db 2, %00000100   ; RETURN
        dw 1250, 1254 : db 0, %00010000   ; F6
        dw 1300, 1304 : db 0, %00010000   ; F6
        dw 1450, 1454 : db 8, %00000100   ; ESC
        dw 1550, 1554 : db 0, %00100000   ; F3
        dw 1700, 1704 : db 8, %00000100   ; ESC
        dw 1750, 1754 : db 0, %00000010   ; RIGHT
        dw 1800, 1804 : db 0, %00000100   ; DOWN
        dw 1840, 1844 : db 0, %00000100   ; DOWN
        dw 1880, 1884 : db 0, %00000100   ; DOWN
        dw 1920, 1924 : db 0, %00000100   ; DOWN
        dw 2050, 2054 : db 2, %00000100   ; RETURN
        dw 2250, 2254 : db 0, %00000100   ; DOWN
        dw 2350, 2354 : db 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 6
; make test-multi (-DTEST_SCRIPT=6): programs side by side in bank 5.
; Expected:
;   frame  300  F2           -> Launcher, DEMO chosen
;   frame  400  RETURN       -> DEMO runs (in a slot from #5000)
;   frame  480, 520 SPACE    -> its square changes colour twice
;   frame  600  F2           -> the Launcher; DEMO stays
;   frame  700  DOWN, 760 RETURN -> PONG runs beside it
;   frame  900  F2           -> the Launcher
;   frame 1000  UP, 1060 RETURN -> DEMO goes on: the same colour
;   frame 1200  CONTROL+Q    -> DEMO ends, its slot is free
;   frame 1300  DOWN, 1360 RETURN -> PONG goes on, its score kept
;   frame 1500  F2, 1600 UP, 1640, 1680 RIGHT, 1720 RETURN -> STUDIO,
;                               which needs the whole bank: "CLOSE
;                               ANOTHER PROGRAM FIRST"
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  400,  404 : db 2, %00000100   ; RETURN
        dw  480,  484 : db 5, %10000000   ; SPACE
        dw  520,  524 : db 5, %10000000   ; SPACE
        dw  600,  604 : db 1, %01000000   ; F2
        dw  700,  704 : db 0, %00000100   ; DOWN
        dw  760,  764 : db 2, %00000100   ; RETURN
        dw  900,  904 : db 1, %01000000   ; F2
        dw 1000, 1004 : db 0, %00000001   ; UP
        dw 1060, 1064 : db 2, %00000100   ; RETURN
        dw 1195, 1210 : db 2, %10000000   ; CONTROL
        dw 1200, 1204 : db 8, %00001000   ; Q
        dw 1300, 1304 : db 0, %00000100   ; DOWN
        dw 1360, 1364 : db 2, %00000100   ; RETURN
        dw 1500, 1504 : db 1, %01000000   ; F2
        dw 1600, 1604 : db 0, %00000001   ; UP
        dw 1640, 1644 : db 0, %00000010   ; RIGHT
        dw 1680, 1684 : db 0, %00000010   ; RIGHT
        dw 1720, 1724 : db 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 5
; make test-acc (-DTEST_SCRIPT=5): CLOCK as the desk accessory.
; Expected:
;   frame  300  F2           -> Launcher
;   frame  420-480 DOWN x3   -> page 2: CLOCK
;   frame  520  CONTROL+A    -> FILE > AS ACCESSORY: the clock's window
;                               over the Launcher
;   frame  700  F5           -> closed, the Launcher drawn again
;   frame  760-880 UP x3, RIGHT x2 -> STUDIO; 950 RETURN -> Studio
;   frame 1300  F5           -> the clock over Studio's mixed screen
;   frame 1600  ESC          -> closed (VOS_EXIT), Studio drawn again
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000100   ; DOWN
        dw  450,  454 : db 0, %00000100   ; DOWN
        dw  480,  484 : db 0, %00000100   ; DOWN
        dw  515,  530 : db 2, %10000000   ; CONTROL
        dw  520,  524 : db 8, %00100000   ; A
        dw  700,  704 : db 1, %00010000   ; F5
        dw  760,  764 : db 0, %00000001   ; UP
        dw  790,  794 : db 0, %00000001   ; UP
        dw  820,  824 : db 0, %00000001   ; UP
        dw  850,  854 : db 0, %00000010   ; RIGHT
        dw  880,  884 : db 0, %00000010   ; RIGHT
        dw  950,  954 : db 2, %00000100   ; RETURN
        dw 1300, 1304 : db 1, %00010000   ; F5
        dw 1600, 1604 : db 8, %00000100   ; ESC
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 4
; make test-costume (-DTEST_SCRIPT=4): a costume drawn in Studio.
; Expected:
;   frame  300  F2, 420, 470 RIGHT, 560 RETURN -> Studio, a new program
;   frame  800, 850 TAB      -> the stage
;   frame  900  E            -> the costume editor, costume 1, empty
;   frame  950  9            -> pen 9 (orange)
;   frame 1000-1210 SPACE, RIGHT, SPACE, DOWN, SPACE -> cells 0,0 1,0 1,1
;   frame 1150  A            -> pen 10 (bright red); 1180 RIGHT, 1210
;                               SPACE -> cell 2,1
;   (the pointer is placed and COPY clicks)
;   frame 1300  click on cell 10,10 -> painted red
;   frame 1360  click on pen 3 in the row under the cells
;   frame 1420  click on cell 11,10 -> painted bright blue
;   frame 1500  E            -> the stage, the sprite in its costume
;   frame 1600  CONTROL+R    -> the name dialog: NONAME
;   frame 1700  RETURN       -> NONAME.VBS and .VBN saved, it runs:
;                               the sprite in its costume bounces
;   frame 2400  CONTROL+Q    -> Studio again, NONAME.VBS opened: the
;                               costume is still there
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000010   ; RIGHT
        dw  470,  474 : db 0, %00000010   ; RIGHT
        dw  560,  564 : db 2, %00000100   ; RETURN
        dw  800,  804 : db 8, %00010000   ; TAB
        dw  850,  854 : db 8, %00010000   ; TAB
        dw  900,  904 : db 7, %00000100   ; E
        dw  950,  954 : db 4, %00000010   ; 9
        dw 1000, 1004 : db 5, %10000000   ; SPACE
        dw 1030, 1034 : db 0, %00000010   ; RIGHT
        dw 1060, 1064 : db 5, %10000000   ; SPACE
        dw 1090, 1094 : db 0, %00000100   ; DOWN
        dw 1120, 1124 : db 5, %10000000   ; SPACE
        dw 1150, 1154 : db 8, %00100000   ; A
        dw 1180, 1184 : db 0, %00000010   ; RIGHT
        dw 1210, 1214 : db 5, %10000000   ; SPACE
        dw 1250, 1251 : db #80, 1         ; COPY is the left button
        dw 1250, 1340 : db #81, 49        ; cell 10,10: x 49 in mode 0
        dw 1250, 1340 : db #82, 89
        dw 1300, 1304 : db 1, %00000010   ; COPY
        dw 1340, 1400 : db #81, 21        ; pen 3
        dw 1340, 1400 : db #82, 133
        dw 1360, 1364 : db 1, %00000010
        dw 1400, 1450 : db #81, 53        ; cell 11,10
        dw 1400, 1450 : db #82, 89
        dw 1420, 1424 : db 1, %00000010
        dw 1460, 1461 : db #80, 0
        dw 1500, 1504 : db 7, %00000100   ; E
        dw 1595, 1610 : db 2, %10000000   ; CONTROL
        dw 1600, 1604 : db 6, %00000100   ; R
        dw 1700, 1704 : db 2, %00000100   ; RETURN: the name NONAME
        dw 2395, 2410 : db 2, %10000000   ; CONTROL
        dw 2400, 2404 : db 8, %00001000   ; Q
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 3
; make test-lang (-DTEST_SCRIPT=3): the default language. Expected:
;   frame  200               -> the Desktop in English (no SETUP.CFG)
;   frame  300  F4           -> Setup, LANGUAGE: ENGLISH
;   frame  450  CONTROL+L    -> Greek (VIEW > LANGUAGE), and the setting
;   frame  550  RETURN       -> SETUP.CFG saved
;   frame  700  CONTROL+Q, 800 RETURN -> BASIC; then RUN"VOS
;                               (tools/cap32_reboot_check.sh): Greek
test_keys:
        dw  300,  304 : db 2, %00010000   ; F4
        dw  445,  460 : db 2, %10000000   ; CONTROL
        dw  450,  454 : db 4, %00010000   ; L
        dw  550,  554 : db 2, %00000100   ; RETURN
        dw  695,  710 : db 2, %10000000   ; CONTROL
        dw  700,  704 : db 8, %00001000   ; Q
        dw  800,  804 : db 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000010   ; RIGHT
        dw  470,  474 : db 0, %00000010   ; RIGHT
        dw  560,  564 : db 2, %00000100   ; RETURN
        dw  800,  804 : db 0, %00000100   ; DOWN
        dw  850,  854 : db 0, %00000010   ; RIGHT
        dw  900,  904 : db 6, %00000010   ; 5
        dw  950,  954 : db 8, %00010000   ; TAB
        dw 1000, 1004 : db 0, %00000010   ; RIGHT
        dw 1050, 1054 : db 0, %00000100   ; DOWN
        dw 1100, 1104 : db 2, %00000100   ; RETURN
        dw 1150, 1154 : db 8, %00010000   ; TAB
        dw 1200, 1240 : db 0, %00000010   ; RIGHT held
        dw 1280, 1284 : db 7, %01000000   ; C
        dw 1330, 1334 : db 8, %00010000   ; TAB
        dw 1375, 1390 : db 2, %10000000   ; CONTROL
        dw 1380, 1384 : db 7, %00010000   ; S
        dw 1450, 1454 : db 2, %00000100   ; RETURN
        dw 1595, 1610 : db 2, %10000000   ; CONTROL
        dw 1600, 1604 : db 5, %01000000   ; N
        dw 1650, 1654 : db 2, %00000100   ; RETURN
        dw 1745, 1760 : db 2, %10000000   ; CONTROL
        dw 1750, 1754 : db 4, %00000100   ; O
        dw 1850, 1854 : db 0, %00000001   ; UP
        dw 2050, 2054 : db 2, %00000100   ; RETURN
        dw 2150, 2151 : db #80, 1         ; COPY is the left button
        dw 2150, 2700 : db #81, 20        ; palette, row 3: IF
        dw 2150, 2300 : db #82, 172
        dw 2200, 2204 : db 1, %00000010   ; COPY
        dw 2300, 2700 : db #82, 152       ; script line 2, slot 0
        dw 2300, 2600 : db #81, 76
        dw 2350, 2354 : db 1, %00000010   ; COPY
        dw 2500, 2504 : db 1, %00000010   ; COPY
        dw 2600, 2700 : db #81, 20        ; the stage
        dw 2600, 2700 : db #82, 40
        dw 2650, 2654 : db 1, %00000010   ; COPY
        dw 2745, 2760 : db 2, %10000000   ; CONTROL
        dw 2750, 2754 : db 6, %00000100   ; R
        dw 3395, 3410 : db 2, %10000000   ; CONTROL
        dw 3400, 3404 : db 8, %00001000   ; Q
        dw #FFFF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
