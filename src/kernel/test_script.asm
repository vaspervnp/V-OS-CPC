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
; test_inject_x - interrupt context, right after the matrix is read,
; through test_inject (src/vos.asm): this file is in the second
; extension (kernel/ext2.asm), so it takes no room in the kernel.
; Destroys: AF, BC, DE, HL, IX
; ---------------------------------------------------------------------
test_inject_x:
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
        sbc hl,de                   ; frames since its first
        ld a,h
        or a
        ld a,l
        pop hl
        jr nz,.next                 ; before it, or long after
        cp (ix+2)
        jr nc,.next                 ; past its last
        ld a,(ix+3)
        cp #80                      ; not a key: cursor keys move the
        jr c,.key                   ; pointer (1) or not (0)
        jr nz,.ptr_x
        ld a,(ix+4)
        ld (ptr_keys_on),a
        jr .next
.ptr_x:
        cp #81                      ; the pointer to x = bits * 2
        jr nz,.ptr_y
        ld a,(ix+4)
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        ld (ptr_x),hl
        ex de,hl
        jr .next
.ptr_y:
        ld a,(ix+4)                 ; #82: to y = bits
        ld (ptr_y),a
        xor a
        ld (ptr_y + 1),a
        jr .next
.key:
        push hl
        ld a,(ix+3)
        ld hl,kbd_now
        ld e,a
        ld d,0
        add hl,de
        ld a,(ix+4)
        or (hl)
        ld (hl),a
        pop hl
.next:
        ld de,5
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
test_ring_x:
        ld b,PPI_B >> 8
        in a,(c)
        rrca
        and #80
        ld hl,int_slice
        or (hl)
        ld e,a
        ld hl,14                    ; the interrupted PC: past this call,
        add hl,sp                   ; test_x's and int_handler's 5 pushes
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

; dw first frame; db frames held (1..255), matrix line, bits
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
;   frame 3250  CONTROL+T    -> the texts in English: WINDOW
;                               "CALCULATOR", "ΗΙ" (none: its own);
;                               the panel says CALC EN
;   frame 3600, 3700 CONTROL+T -> EL (its own), then FR: "CALCULATRICE"
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  470 : db   4, 0, %00000100   ; DOWN
        dw  510 : db   4, 0, %00000010   ; RIGHT
        dw  535 : db   4, 0, %00000010   ; RIGHT
        dw  560 : db   4, 2, %00000100   ; RETURN
        dw  900 : db   1, #80, 1         ; COPY is the left button
        dw  900 : db 100, #81, 56        ; 1 (x = 112 in mode 1)
        dw  900 : db 100, #82, 161
        dw  950 : db   4, 1, %00000010   ; COPY
        dw 1000 : db 100, #81, 80        ; 2
        dw 1000 : db 100, #82, 161
        dw 1050 : db   4, 1, %00000010
        dw 1100 : db 100, #81, 128       ; +
        dw 1100 : db 100, #82, 181
        dw 1150 : db   4, 1, %00000010
        dw 1200 : db 100, #81, 104       ; 3
        dw 1200 : db 100, #82, 161
        dw 1250 : db   4, 1, %00000010
        dw 1300 : db 100, #81, 104       ; =
        dw 1300 : db 100, #82, 181
        dw 1350 : db   4, 1, %00000010
        dw 1450 : db   1, #80, 0
        dw 1495 : db  15, 2, %10000000   ; CONTROL
        dw 1500 : db   4, 8, %00001000   ; Q
        dw 1700 : db   4, 0, %00000001   ; UP
        dw 1750 : db   4, 0, %00000001   ; UP
        dw 1900 : db   4, 2, %00000100   ; RETURN
        dw 2095 : db  15, 2, %10000000   ; CONTROL
        dw 2100 : db   4, 4, %00000100   ; O
        dw 2150 : db   4, 0, %00000001   ; UP: the last file (BRICKS.VBN)
        dw 2178 : db   4, 0, %00000001   ; UP: MINES.VBS
        dw 2206 : db   4, 0, %00000001   ; UP: MINES.VBN
        dw 2234 : db   4, 0, %00000001   ; UP: VBRUN.SYS
        dw 2262 : db   4, 0, %00000001   ; UP: TICKER.VBS
        dw 2290 : db   4, 0, %00000001   ; UP: TICKER.VBN
        dw 2318 : db   4, 0, %00000001   ; UP: CLOCK.BIN
        dw 2346 : db   4, 0, %00000001   ; UP: CALC.VBS
        dw 2400 : db   4, 2, %00000100   ; RETURN
        dw 2600 : db   4, 8, %00010000   ; TAB
        dw 2650 : db   4, 1, %00000001   ; LEFT
        dw 2800 : db   4, 2, %00000100   ; RETURN
        dw 2900 : db   4, 5, %00010000   ; H
        dw 2950 : db   4, 4, %00001000   ; I
        dw 3050 : db   4, 2, %00000100   ; RETURN
        dw 3245 : db  15, 2, %10000000   ; CONTROL
        dw 3250 : db   4, 6, %00001000   ; T
        dw 3595 : db  15, 2, %10000000   ; CONTROL
        dw 3600 : db   4, 6, %00001000   ; T
        dw 3695 : db  15, 2, %10000000   ; CONTROL
        dw 3700 : db   4, 6, %00001000   ; T
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 33
; make test-paint-big (-DTEST_SCRIPT=33, 576K): PAINT on the whole
; screen, 160 x 200, its window moved by the scroll bars. Expected:
;   frame  300  F2, 420-480 DOWN x3, 520-610 RIGHT x4, 660 RETURN ->
;                               PAINT: NONAME.SCR, the bars' yellow
;                               parts at the top and the left
;   frame  800-860 TAB x3    -> red
;   (the pointer is placed and COPY clicks)
;   frame  910-990 COPY held, RIGHT held from 20,40 -> a red line,
;                               picture row 24
;   frame 1100  click on the right bar near its bottom -> VIEW 000,072:
;                               the line gone up out of the window
;   frame 1300  click on the bar below at its right -> VIEW 032,072
;   frame 1460-1540 COPY held, UP held from 60,100 -> a red line up
;                               from 92,156
;   frame 1610-1730 COPY held on the right bar, UP held -> dragged up:
;                               VIEW 032,000, the first line again
;   frame 1750  the pointer at 60,50, 1760 RIGHT -> its place, 09x,034
;   frame 1900  ESC, 1940-2180 DOWN x7, 2250 RETURN -> OTHER DRIVE (B:)
;   frame 2400  CONTROL+S, 2550 RETURN -> B:NONAME.SCR saved
;   frame 2750  CONTROL+O, 2900 RETURN -> NONAME.SCR opened again: the
;                               window at the top left, the first line
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  480 : db   4, 0, %00000100   ; DOWN
        dw  520 : db   4, 0, %00000010   ; RIGHT
        dw  550 : db   4, 0, %00000010   ; RIGHT
        dw  580 : db   4, 0, %00000010   ; RIGHT
        dw  610 : db   4, 0, %00000010   ; RIGHT
        dw  660 : db   4, 2, %00000100   ; RETURN: PAINT
        dw  800 : db   4, 8, %00010000   ; TAB
        dw  830 : db   4, 8, %00010000   ; TAB
        dw  860 : db   4, 8, %00010000   ; TAB: red
        dw  900 : db   1, #80, 1         ; COPY is the left button
        dw  900 : db   5, #81, 10        ; x 20, y 40
        dw  900 : db   5, #82, 40
        dw  910 : db  80, 1, %00000010   ; COPY held
        dw  920 : db  50, 0, %00000010   ; RIGHT held: a red line
        dw 1050 : db 100, #81, 65        ; the bar on the right (x 130)
        dw 1050 : db 100, #82, 140       ; near its bottom
        dw 1100 : db   4, 1, %00000010   ; COPY
        dw 1250 : db 100, #81, 60        ; the bar below (y 147), at x 120
        dw 1250 : db 100, #82, 147
        dw 1300 : db   4, 1, %00000010   ; COPY
        dw 1450 : db   5, #81, 30        ; x 60, y 100
        dw 1450 : db   5, #82, 100
        dw 1460 : db  80, 1, %00000010   ; COPY held
        dw 1470 : db  40, 0, %00000001   ; UP held: a red line up
        dw 1600 : db   5, #81, 65        ; the bar on the right again
        dw 1600 : db   5, #82, 140
        dw 1610 : db 120, 1, %00000010   ; COPY held on it
        dw 1620 : db 100, 0, %00000001   ; UP held: dragged up
        dw 1750 : db   5, #81, 30        ; the pointer at 60, 50
        dw 1750 : db   5, #82, 50
        dw 1760 : db   4, 0, %00000010   ; RIGHT: it moves, its place shown
        dw 1900 : db   4, 8, %00000100   ; ESC: the menu
        dw 1940 : db   4, 0, %00000100   ; DOWN
        dw 1980 : db   4, 0, %00000100   ; DOWN
        dw 2020 : db   4, 0, %00000100   ; DOWN
        dw 2060 : db   4, 0, %00000100   ; DOWN
        dw 2100 : db   4, 0, %00000100   ; DOWN
        dw 2140 : db   4, 0, %00000100   ; DOWN
        dw 2180 : db   4, 0, %00000100   ; DOWN
        dw 2250 : db   4, 2, %00000100   ; RETURN: OTHER DRIVE (B:)
        dw 2395 : db  15, 2, %10000000   ; CONTROL
        dw 2400 : db   4, 7, %00010000   ; S: the name, NONAME
        dw 2550 : db   4, 2, %00000100   ; RETURN: B:NONAME.SCR
        dw 2745 : db  15, 2, %10000000   ; CONTROL
        dw 2750 : db   4, 4, %00000100   ; O: the .SCR files of B:
        dw 2900 : db   4, 2, %00000100   ; RETURN: NONAME.SCR
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 32
; make test-sheet (-DTEST_SCRIPT=32): SHEET (myapps/sheet), last on the
; test disc, CALC.SYS on A:, the sheet saved on B:. Expected:
;   frame  300  F2, 570-630 DOWN x3, 670-760 RIGHT x4, 810 RETURN ->
;                               SHEET: an empty sheet, the cursor at A1
;   frame 1050  1 2 RETURN    -> A1 12 (CALC.SYS loaded), the cursor A2
;   frame 1650  3 0 RETURN    -> A2 30
;   frame 2250  =a1+a2 RETURN -> A3 42 (3050)
;   frame 3150  UP            -> A3, its formula on the first line
;   frame 3300  CONTROL+W     -> drive B: (A: has no room)
;   frame 3450  CONTROL+S, t RETURN -> B:T.VSH, SAVED (4150)
;   frame 4400  CONTROL+M    -> the page (mode 2): 10 columns A-J, black
;                               on white, grid lines, A1-A3 12 30 42
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  570 : db   4, 0, %00000100   ; DOWN
        dw  600 : db   4, 0, %00000100   ; DOWN
        dw  630 : db   4, 0, %00000100   ; DOWN
        dw  670 : db   4, 0, %00000010   ; RIGHT
        dw  700 : db   4, 0, %00000010   ; RIGHT
        dw  730 : db   4, 0, %00000010   ; RIGHT
        dw  760 : db   4, 0, %00000010   ; RIGHT
        dw  810 : db   4, 2, %00000100   ; RETURN: SHEET
        dw 1050 : db   4, 8, %00000001   ; 1: the input, "1"
        dw 1250 : db   4, 8, %00000010   ; 2
        dw 1290 : db   4, 2, %00000100   ; RETURN: A1 12
        dw 1650 : db   4, 7, %00000010   ; 3
        dw 1850 : db   4, 4, %00000001   ; 0
        dw 1890 : db   4, 2, %00000100   ; RETURN: A2 30
        dw 2245 : db  15, 2, %00100000   ; SHIFT
        dw 2250 : db   4, 3, %00000010   ; =
        dw 2450 : db   4, 8, %00100000   ; a
        dw 2490 : db   4, 8, %00000001   ; 1
        dw 2525 : db  15, 2, %00100000   ; SHIFT
        dw 2530 : db   4, 3, %00010000   ; +
        dw 2570 : db   4, 8, %00100000   ; a
        dw 2610 : db   4, 8, %00000010   ; 2
        dw 2650 : db   4, 2, %00000100   ; RETURN: A3 =A1+A2
        dw 3150 : db   4, 0, %00000001   ; UP: A3
        dw 3295 : db  15, 2, %10000000   ; CONTROL
        dw 3300 : db   4, 7, %00001000   ; W: drive B: (A: is full)
        dw 3445 : db  15, 2, %10000000   ; CONTROL
        dw 3450 : db   4, 7, %00010000   ; S: SAVE, its name
        dw 3650 : db   4, 6, %00001000   ; t
        dw 3690 : db   4, 2, %00000100   ; RETURN: B:T.VSH
        dw 4395 : db  15, 2, %10000000   ; CONTROL
        dw 4400 : db   4, 4, %01000000   ; M: the page
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 31
; make test-database (-DTEST_SCRIPT=31): DATABASE (myapps/database), last
; on the test disc, its database on B:. Expected:
;   frame  300  F2, 420-480 DOWN x3, 520-610 RIGHT x4, 660 RETURN ->
;                               DATABASE: "NO DATABASE"
;   frame  900  CONTROL+W    -> drive B:
;   frame 1000  CONTROL+N, club RETURN -> B:CLUB.VDB; from 1930 NEW
;                               TABLE: pals, fields name (TEXT, 12), age
;                               (NUMBER), NAME its key -> from 4520 the
;                               list: NO RECORDS
;   frame 4520 on, three times: CONTROL+A, the form, NAME ZOE, anna,
;                               bob, AGE 31, 28, 40, CONTROL+S -> from
;                               10380 the list in key order without
;                               case: anna 28, bob 40, ZOE 31
;   frame 10380 b            -> FIND: b, the list from bob
;   frame 10720 RETURN, AGE 41, CONTROL+S -> bob 41, SAVED (12240)
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  480 : db   4, 0, %00000100   ; DOWN
        dw  520 : db   4, 0, %00000010   ; RIGHT
        dw  550 : db   4, 0, %00000010   ; RIGHT
        dw  580 : db   4, 0, %00000010   ; RIGHT
        dw  610 : db   4, 0, %00000010   ; RIGHT
        dw  660 : db   4, 2, %00000100   ; RETURN: DATABASE
        dw  895 : db  15, 2, %10000000   ; CONTROL
        dw  900 : db   4, 7, %00001000   ; W: drive B:
        dw 1035 : db  15, 2, %10000000   ; CONTROL
        dw 1040 : db   4, 5, %01000000   ; N: NEW DATABASE
        dw 1230 : db   4, 7, %01000000   ; c
        dw 1270 : db   4, 4, %00010000   ; l
        dw 1310 : db   4, 5, %00000100   ; u
        dw 1350 : db   4, 6, %01000000   ; b
        dw 1390 : db   4, 2, %00000100   ; RETURN: CLUB.VDB on B:
        dw 1930 : db   4, 3, %00001000   ; p
        dw 1970 : db   4, 8, %00100000   ; a
        dw 2010 : db   4, 4, %00010000   ; l
        dw 2050 : db   4, 7, %00010000   ; s
        dw 2090 : db   4, 2, %00000100   ; RETURN: table PALS
        dw 2280 : db   4, 5, %01000000   ; n
        dw 2320 : db   4, 8, %00100000   ; a
        dw 2360 : db   4, 4, %01000000   ; m
        dw 2400 : db   4, 7, %00000100   ; e
        dw 2440 : db   4, 2, %00000100   ; RETURN: a field NAME
        dw 2630 : db   4, 2, %00000100   ; RETURN: TEXT
        dw 2820 : db   4, 8, %00000001   ; 1
        dw 2860 : db   4, 8, %00000010   ; 2
        dw 2900 : db   4, 2, %00000100   ; RETURN: 12 long
        dw 3090 : db   4, 8, %00100000   ; a
        dw 3130 : db   4, 6, %00010000   ; g
        dw 3170 : db   4, 7, %00000100   ; e
        dw 3210 : db   4, 2, %00000100   ; RETURN: a field AGE
        dw 3400 : db   4, 0, %00000010   ; RIGHT: NUMBER
        dw 3500 : db   4, 2, %00000100   ; RETURN
        dw 3690 : db   4, 2, %00000100   ; RETURN: no more fields
        dw 3880 : db   4, 2, %00000100   ; RETURN: YES, NAME its key
        dw 4515 : db  15, 2, %10000000   ; CONTROL
        dw 4520 : db   4, 8, %00100000   ; A: ADD A RECORD
        dw 4760 : db   4, 2, %00000100   ; RETURN: NAME
        dw 4945 : db  15, 2, %00100000   ; SHIFT
        dw 4950 : db   4, 8, %10000000   ; Z
        dw 4985 : db  15, 2, %00100000   ; SHIFT
        dw 4990 : db   4, 4, %00000100   ; O
        dw 5025 : db  15, 2, %00100000   ; SHIFT
        dw 5030 : db   4, 7, %00000100   ; E
        dw 5070 : db   4, 2, %00000100   ; RETURN
        dw 5260 : db   4, 0, %00000100   ; DOWN: AGE
        dw 5360 : db   4, 2, %00000100   ; RETURN
        dw 5550 : db   4, 7, %00000010   ; 3
        dw 5590 : db   4, 8, %00000001   ; 1
        dw 5630 : db   4, 2, %00000100   ; RETURN
        dw 5815 : db  15, 2, %10000000   ; CONTROL
        dw 5820 : db   4, 7, %00010000   ; S: SAVE
        dw 6455 : db  15, 2, %10000000   ; CONTROL
        dw 6460 : db   4, 8, %00100000   ; A: ADD A RECORD
        dw 6700 : db   4, 2, %00000100   ; RETURN: NAME
        dw 6890 : db   4, 8, %00100000   ; a
        dw 6930 : db   4, 5, %01000000   ; n
        dw 6970 : db   4, 5, %01000000   ; n
        dw 7010 : db   4, 8, %00100000   ; a
        dw 7050 : db   4, 2, %00000100   ; RETURN
        dw 7240 : db   4, 0, %00000100   ; DOWN: AGE
        dw 7340 : db   4, 2, %00000100   ; RETURN
        dw 7530 : db   4, 8, %00000010   ; 2
        dw 7570 : db   4, 5, %00000001   ; 8
        dw 7610 : db   4, 2, %00000100   ; RETURN
        dw 7795 : db  15, 2, %10000000   ; CONTROL
        dw 7800 : db   4, 7, %00010000   ; S: SAVE
        dw 8435 : db  15, 2, %10000000   ; CONTROL
        dw 8440 : db   4, 8, %00100000   ; A: ADD A RECORD
        dw 8680 : db   4, 2, %00000100   ; RETURN: NAME
        dw 8870 : db   4, 6, %01000000   ; b
        dw 8910 : db   4, 4, %00000100   ; o
        dw 8950 : db   4, 6, %01000000   ; b
        dw 8990 : db   4, 2, %00000100   ; RETURN
        dw 9180 : db   4, 0, %00000100   ; DOWN: AGE
        dw 9280 : db   4, 2, %00000100   ; RETURN
        dw 9470 : db   4, 7, %00000001   ; 4
        dw 9510 : db   4, 4, %00000001   ; 0
        dw 9550 : db   4, 2, %00000100   ; RETURN
        dw 9735 : db  15, 2, %10000000   ; CONTROL
        dw 9740 : db   4, 7, %00010000   ; S: SAVE
        dw 10380 : db   4, 6, %01000000   ; b
        dw 10720 : db   4, 2, %00000100   ; RETURN: bob in the form
        dw 10960 : db   4, 0, %00000100   ; DOWN: AGE
        dw 11060 : db   4, 2, %00000100   ; RETURN
        dw 11250 : db   4, 9, %10000000   ; DEL
        dw 11290 : db   4, 9, %10000000   ; DEL
        dw 11330 : db   4, 7, %00000001   ; 4
        dw 11370 : db   4, 8, %00000001   ; 1
        dw 11410 : db   4, 2, %00000100   ; RETURN
        dw 11595 : db  15, 2, %10000000   ; CONTROL
        dw 11600 : db   4, 7, %00010000   ; S: SAVE
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 30
; make test-kbds (-DTEST_SCRIPT=30): the keyboards of all the packs,
; NOTEPAD last on the test disc, the Greek pack. Expected:
;   frame  300  F4, 400-580 DOWN x7 -> Setup, KEYBOARDS: EN + PACK
;   frame  650  RIGHT        -> KEYBOARDS: ALL SIX
;   frame  750  F2, 870-930 DOWN x3, 970-1060 RIGHT x4, 1110 RETURN ->
;                               NOTEPAD
;   frame 1300 on: the : and Z keys, RETURN, then CONTROL+SHIFT, seven
;                               times: the lines ":z" (EN), ":ζ" (ΕΛ),
;                               "mw" (FR), "ñz" (ES), "öy" (DE), "òz"
;                               (IT), ":z" (EN again)
test_keys:
        dw  300 : db   4, 2, %00010000   ; F4
        dw  400 : db   4, 0, %00000100   ; DOWN
        dw  430 : db   4, 0, %00000100   ; DOWN
        dw  460 : db   4, 0, %00000100   ; DOWN
        dw  490 : db   4, 0, %00000100   ; DOWN
        dw  520 : db   4, 0, %00000100   ; DOWN
        dw  550 : db   4, 0, %00000100   ; DOWN
        dw  580 : db   4, 0, %00000100   ; DOWN: KEYBOARDS
        dw  650 : db   4, 0, %00000010   ; RIGHT: ALL SIX
        dw  750 : db   4, 1, %01000000   ; F2
        dw  870 : db   4, 0, %00000100   ; DOWN
        dw  900 : db   4, 0, %00000100   ; DOWN
        dw  930 : db   4, 0, %00000100   ; DOWN
        dw  970 : db   4, 0, %00000010   ; RIGHT
        dw 1000 : db   4, 0, %00000010   ; RIGHT
        dw 1030 : db   4, 0, %00000010   ; RIGHT
        dw 1060 : db   4, 0, %00000010   ; RIGHT
        dw 1110 : db   4, 2, %00000100   ; RETURN: NOTEPAD
        dw 1300 : db   4, 3, %00100000   ; : key (EN)
        dw 1330 : db   4, 8, %10000000   ; Z key
        dw 1360 : db   4, 2, %00000100   ; RETURN
        dw 1395 : db  15, 2, %10000000   ; CONTROL, then
        dw 1400 : db   4, 2, %00100000   ; SHIFT: the next keyboard
        dw 1450 : db   4, 3, %00100000   ; : key (ΕΛ)
        dw 1480 : db   4, 8, %10000000   ; Z key
        dw 1510 : db   4, 2, %00000100   ; RETURN
        dw 1545 : db  15, 2, %10000000   ; CONTROL, then
        dw 1550 : db   4, 2, %00100000   ; SHIFT: the next keyboard
        dw 1600 : db   4, 3, %00100000   ; : key (FR)
        dw 1630 : db   4, 8, %10000000   ; Z key
        dw 1660 : db   4, 2, %00000100   ; RETURN
        dw 1695 : db  15, 2, %10000000   ; CONTROL, then
        dw 1700 : db   4, 2, %00100000   ; SHIFT: the next keyboard
        dw 1750 : db   4, 3, %00100000   ; : key (ES)
        dw 1780 : db   4, 8, %10000000   ; Z key
        dw 1810 : db   4, 2, %00000100   ; RETURN
        dw 1845 : db  15, 2, %10000000   ; CONTROL, then
        dw 1850 : db   4, 2, %00100000   ; SHIFT: the next keyboard
        dw 1900 : db   4, 3, %00100000   ; : key (DE)
        dw 1930 : db   4, 8, %10000000   ; Z key
        dw 1960 : db   4, 2, %00000100   ; RETURN
        dw 1995 : db  15, 2, %10000000   ; CONTROL, then
        dw 2000 : db   4, 2, %00100000   ; SHIFT: the next keyboard
        dw 2050 : db   4, 3, %00100000   ; : key (IT)
        dw 2080 : db   4, 8, %10000000   ; Z key
        dw 2110 : db   4, 2, %00000100   ; RETURN
        dw 2145 : db  15, 2, %10000000   ; CONTROL, then
        dw 2150 : db   4, 2, %00100000   ; SHIFT: the next keyboard
        dw 2200 : db   4, 3, %00100000   ; : key (EN)
        dw 2230 : db   4, 8, %10000000   ; Z key
        dw 2260 : db   4, 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 29
; make test-streets (-DTEST_SCRIPT=29): STREETS (myapps/streets) from its
; disc, build/streets.dsk, in B:; DB.SYS on A:. Expected:
;   frame  300  F2, 450 TAB, 600 RETURN -> STREETS: no STREETS.VDB yet,
;                               so it makes one, with 24 streets: all of
;                               them from ADRIANOU, "A NEW INDEX"
;   frame 2000  A, 2050 G    -> FIND: AG, the three AGIOU ... streets
;   frame 2200  DEL          -> FIND: A, those from ADRIANOU to ATHINAS
;   frame 2350  CONTROL+A    -> THE STREET: M A I, RETURN; ITS AREA:
;                               P L A K A, RETURN; ITS POST CODE: 1 0 5
;                               5 1, RETURN -> FIND: MAI, MAI PLAKA 10551,
;                               STREETS IN ALL: 25
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  450 : db   4, 8, %00010000   ; TAB: drive B:
        dw  600 : db   4, 2, %00000100   ; RETURN: STREETS
        dw 2000 : db   4, 8, %00100000   ; A
        dw 2050 : db   4, 6, %00010000   ; G
        dw 2200 : db   4, 9, %10000000   ; DEL
        dw 2345 : db  15, 2, %10000000   ; CONTROL
        dw 2350 : db   4, 8, %00100000   ; A: ADD A STREET
        dw 2450 : db   4, 4, %01000000   ; M
        dw 2480 : db   4, 8, %00100000   ; A
        dw 2510 : db   4, 4, %00001000   ; I
        dw 2560 : db   4, 2, %00000100   ; RETURN
        dw 2650 : db   4, 3, %00001000   ; P
        dw 2680 : db   4, 4, %00010000   ; L
        dw 2710 : db   4, 8, %00100000   ; A
        dw 2740 : db   4, 4, %00100000   ; K
        dw 2770 : db   4, 8, %00100000   ; A
        dw 2820 : db   4, 2, %00000100   ; RETURN
        dw 2900 : db   4, 8, %00000001   ; 1
        dw 2930 : db   4, 4, %00000001   ; 0
        dw 2960 : db   4, 6, %00000010   ; 5
        dw 2990 : db   4, 6, %00000010   ; 5
        dw 3020 : db   4, 8, %00000001   ; 1
        dw 3070 : db   4, 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 28
; make test-data (-DTEST_SCRIPT=28, 576K): data banks of their own. A:
; the test disc with NOTEPAD.BIN, B: markdown.dsk with BIG.TXT (300
; lines, 15K). NOTEPAD keeps about 50 lines in memory, the rest in its
; data bank; near line 31 its window moves, and the first lines go
; there. Expected:
;   frame  300  F3, 400 TAB, 450 500 DOWN, 600 RETURN -> NOTEPAD with
;                               BIG.TXT: LINE 0000 at the top
;   frame  900-2100 DOWN held -> down to about LINE 33 (the key repeats
;                               slowly, each line scrolls the screen):
;                               the window moved, LINE 0000-0005 in the
;                               data bank
;   frame 2200  F3           -> the Commander; NOTEPAD stays
;   frame 2300  UP, 2400 RETURN -> MARKDOWN with README.MD (loaded
;                               through bank 4, into its own data bank)
;   frame 2800  F6, 2900 RETURN -> NOTEPAD again, the same lines
;   frame 3100-4300 UP held  -> back up to LINE 0000: the first lines
;                               come from NOTEPAD's data bank, in order
;                               (in bank 4 MARKDOWN would have taken
;                               their place)
test_keys:
        dw  300 : db   4, 0, %00100000   ; F3
        dw  400 : db   4, 8, %00010000   ; TAB: the B: panel
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  500 : db   4, 0, %00000100   ; DOWN: BIG.TXT
        dw  600 : db   4, 2, %00000100   ; RETURN: NOTEPAD
        dw  900 : db 240, 0, %00000100   ; DOWN, held
        dw 1140 : db 240, 0, %00000100
        dw 1380 : db 240, 0, %00000100
        dw 1620 : db 240, 0, %00000100
        dw 1860 : db 240, 0, %00000100
        dw 2200 : db   4, 0, %00100000   ; F3: the Commander
        dw 2300 : db   4, 0, %00000001   ; UP: README.MD
        dw 2400 : db   4, 2, %00000100   ; RETURN: MARKDOWN
        dw 2800 : db   4, 0, %00010000   ; F6: NOTEPAD selected
        dw 2900 : db   4, 2, %00000100   ; RETURN: NOTEPAD
        dw 3100 : db 240, 0, %00000001   ; UP, held
        dw 3340 : db 240, 0, %00000001
        dw 3580 : db 240, 0, %00000001
        dw 3820 : db 240, 0, %00000001
        dw 4060 : db 240, 0, %00000001
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 27
; make test-music-block (-DTEST_SCRIPT=27, 576K): Studio's MUSIC block.
; A: the test disc with AGANAMEM.MUS and TUNE.VBN last, B: music.dsk
; (MUSIC.BIN). Expected:
;   frame  300  F3           -> the Commander
;   frame  400-850 DOWN held -> the last file, TUNE.VBN
;   frame  900  RETURN       -> TUNE: MUSIC BEHIND; MUSIC starts behind
;                               it with AGANAMEM.MUS (the disc turns)
;   frame 1500  F6           -> the programs: "> TUNE", MUSIC selected
;   frame 1700  RETURN       -> MUSIC in front: A:AGANAMEM PLAYING
test_keys:
        dw  300 : db   4, 0, %00100000   ; F3
        dw  400 : db 255, 0, %00000100   ; DOWN, held
        dw  655 : db 195, 0, %00000100
        dw  900 : db   4, 2, %00000100   ; RETURN: TUNE
        dw 1500 : db   4, 0, %00010000   ; F6: MUSIC selected
        dw 1700 : db   4, 2, %00000100   ; RETURN: MUSIC
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 26
; make test-reader (-DTEST_SCRIPT=26): READER (myapps/reader) from its
; disc, build/reader.dsk, in B:. Expected:
;   frame  300  F2, 450 TAB, 600 RETURN -> READER with INDEX.MD
;   frame  900  TAB          -> the first link, About READER, inverted
;   frame 1000  RETURN       -> ABOUT.MD
;   frame 1300  DEL          -> INDEX.MD again
;   frame 1500-1650 TAB x4   -> the fourth link, the secure page
;   frame 1750  RETURN       -> "ONLY HTTP ADDRESSES CAN BE OPENED"
;   frame 1900  RETURN       -> the dialog closed
;   frame 2000  CONTROL+M    -> the page (mode 2): INDEX.MD in 80
;                               columns between the page's edges
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  450 : db   4, 8, %00010000   ; TAB: drive B:
        dw  600 : db   4, 2, %00000100   ; RETURN: READER
        dw  900 : db   4, 8, %00010000   ; TAB: a link
        dw 1000 : db   4, 2, %00000100   ; RETURN: follow it
        dw 1300 : db   4, 9, %10000000   ; DEL: back
        dw 1500 : db   4, 8, %00010000   ; TAB
        dw 1550 : db   4, 8, %00010000   ; TAB
        dw 1600 : db   4, 8, %00010000   ; TAB
        dw 1650 : db   4, 8, %00010000   ; TAB
        dw 1750 : db   4, 2, %00000100   ; RETURN: the secure page
        dw 1900 : db   4, 2, %00000100   ; RETURN: OK
        dw 1995 : db  15, 2, %10000000   ; CONTROL
        dw 2000 : db   4, 4, %01000000   ; M: the page
        dw #FFFF
        ELSE
        IF TEST_SCRIPT == 25
; make test-webget (-DTEST_SCRIPT=25): WEBGET (myapps/webget) with the
; M4 board, in CPCEMU (tools/linux/), WEBGET.BIN last on A:. Expected:
;   frame  300  F3, 400-850 DOWN held, 900 RETURN -> WEBGET: the network
;   frame 1100  CONTROL+G    -> the address, example.com/index.html
;   frame 1200  RETURN       -> the name, INDEX.HTML
;   frame 1300  RETURN       -> GETTING IT..., then SAVED, BYTES: n, and
;                               A:INDEX.HTM on the disc
test_keys:
        dw  300 : db   4, 0, %00100000   ; F3
        dw  400 : db 255, 0, %00000100   ; DOWN, held
        dw  655 : db 195, 0, %00000100
        dw  900 : db   4, 2, %00000100   ; RETURN: WEBGET
        dw 1095 : db  15, 2, %10000000   ; CONTROL
        dw 1100 : db   4, 6, %00010000   ; G
        dw 1200 : db   4, 2, %00000100   ; RETURN: the address
        dw 1300 : db   4, 2, %00000100   ; RETURN: the name
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
        dw  300 : db   4, 0, %00100000   ; F3
        dw  400 : db   4, 8, %00010000   ; TAB: the B: panel
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  500 : db   4, 0, %00000100   ; DOWN: HELLO.TXT
        dw  600 : db   4, 2, %00000100   ; RETURN: NOTEPAD
        dw  800 : db 200, 2, %00100000   ; SHIFT, held
        dw  820 : db   4, 0, %00000010   ; RIGHT
        dw  840 : db   4, 0, %00000010
        dw  860 : db   4, 0, %00000010
        dw  880 : db   4, 0, %00000010
        dw  900 : db   4, 0, %00000010
        dw  920 : db   4, 0, %00000010
        dw 1045 : db  15, 2, %10000000   ; CONTROL
        dw 1050 : db   4, 7, %01000000   ; C
        dw 1100 : db   4, 0, %00000100   ; DOWN
        dw 1145 : db  15, 2, %10000000   ; CONTROL
        dw 1150 : db   4, 6, %10000000   ; V
        dw 1295 : db  15, 2, %10000000   ; CONTROL
        dw 1300 : db   4, 8, %00100000   ; A
        dw 1395 : db  15, 2, %10000000   ; CONTROL
        dw 1400 : db   4, 7, %10000000   ; X
        dw 1495 : db  15, 2, %10000000   ; CONTROL
        dw 1500 : db   4, 6, %10000000   ; V
        dw 1595 : db  15, 2, %10000000   ; CONTROL
        dw 1600 : db   4, 8, %00001000   ; Q
        dw 1700 : db   4, 2, %00000100   ; RETURN: YES, leave it
        dw 1800 : db   4, 0, %00000001   ; UP: README.MD
        dw 1850 : db   4, 2, %00000100   ; RETURN: MARKDOWN
        dw 2045 : db  15, 2, %10000000   ; CONTROL
        dw 2050 : db   4, 6, %10000000   ; V
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
        dw  300 : db   4, 0, %00100000   ; F3
        dw  400 : db 255, 0, %00000100   ; DOWN, held
        dw  655 : db 195, 0, %00000100
        dw  900 : db   4, 2, %00000100   ; RETURN: SYSINFO
        dw 1095 : db  15, 2, %10000000   ; CONTROL
        dw 1100 : db   4, 6, %00000100   ; R
        dw 1245 : db  15, 2, %10000000   ; CONTROL
        dw 1250 : db   4, 8, %00001000   ; Q
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
        dw  300 : db   4, 0, %00100000   ; F3
        dw  400 : db   4, 8, %00010000   ; TAB: the B: panel
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  550 : db   4, 2, %00000100   ; RETURN: open README.MD
        dw  795 : db  15, 2, %10000000   ; CONTROL
        dw  800 : db   4, 8, %00001000   ; Q
        dw  950 : db   4, 0, %00000100   ; DOWN
        dw 1000 : db   4, 0, %00000100   ; DOWN
        dw 1100 : db   4, 2, %00000100   ; RETURN: open HELLO.TXT
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
;                               lists, a quote, a line, a code block;
;                               lines that follow each other joined
;   frame 1600  RIGHT        -> the page a screen on
;   frame 2200  RETURN       -> the text again
;   frame 2400  CONTROL+M    -> the editor on the page (mode 2), PAGE 1
;   frame 2700  CONTROL+P    -> the preview in 80 columns, mode 2
; (wide gaps: the shots, counted in typed keys, cannot aim closely)
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  450 : db   4, 8, %00010000   ; TAB: drive B:
        dw  600 : db   4, 2, %00000100   ; RETURN: MARKDOWN
        dw  745 : db  15, 2, %10000000   ; CONTROL
        dw  750 : db   4, 4, %00000100   ; O
        dw  850 : db   4, 2, %00000100   ; RETURN: README.MD
        dw  995 : db  15, 2, %10000000   ; CONTROL
        dw 1000 : db   4, 3, %00001000   ; P
        dw 1600 : db   4, 0, %00000010   ; RIGHT
        dw 2200 : db   4, 2, %00000100   ; RETURN: the text
        dw 2395 : db  15, 2, %10000000   ; CONTROL
        dw 2400 : db   4, 4, %01000000   ; M: the page
        dw 2695 : db  15, 2, %10000000   ; CONTROL
        dw 2700 : db   4, 3, %00001000   ; P: its preview
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  450 : db   4, 8, %00010000   ; TAB: drive B:
        dw  600 : db   4, 2, %00000100   ; RETURN: MUSIC
        dw  745 : db  15, 2, %10000000   ; CONTROL
        dw  750 : db   4, 4, %00000100   ; O
        dw  850 : db   4, 2, %00000100   ; RETURN: the first song
        dw 1200 : db   4, 1, %01000000   ; F2
        dw 1400 : db   4, 2, %00000100   ; RETURN: MUSIC again
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  400 : db   4, 8, %00000100   ; ESC: the menus
        dw  450 : db   4, 0, %00000010   ; RIGHT
        dw  480 : db   4, 0, %00000010   ; RIGHT: HELP
        dw  520 : db   4, 0, %00000100   ; DOWN: ABOUT V-OS
        dw  600 : db   4, 2, %00000100   ; RETURN
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
;   frame 2700  h            -> shown again
;   frame 2800  ESC, 2840-3080 DOWN x7, 3150 RETURN -> OTHER DRIVE: B:
;                               (A: has no room for 16K)
;   frame 3250  ESC, 3300-3500 DOWN x6, 3600 RETURN -> EXPORT .SCR:
;                               B:NONAME.SCR, then "SAVED AS .SCR"
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  480 : db   4, 0, %00000100   ; DOWN
        dw  520 : db   4, 0, %00000010   ; RIGHT
        dw  550 : db   4, 0, %00000010   ; RIGHT
        dw  580 : db   4, 0, %00000010   ; RIGHT
        dw  610 : db   4, 0, %00000010   ; RIGHT
        dw  660 : db   4, 2, %00000100   ; RETURN: PAINT
        dw  800 : db   4, 8, %00010000   ; TAB
        dw  830 : db   4, 8, %00010000   ; TAB
        dw  860 : db   4, 8, %00010000   ; TAB: red
        dw  900 : db 100, 1, %00000010   ; COPY held
        dw  920 : db  30, 0, %00000001   ; UP held
        dw 1050 : db   4, 7, %10000000   ; x: BOX
        dw 1070 : db   4, 8, %00010000   ; TAB: green
        dw 1100 : db 100, 1, %00000010   ; COPY held
        dw 1110 : db  35, 1, %00000001   ; LEFT held
        dw 1250 : db   4, 6, %00100000   ; f: FILL
        dw 1270 : db   4, 8, %00010000   ; TAB: yellow
        dw 1300 : db   4, 1, %00000010   ; COPY: fill
        dw 1500 : db   4, 8, %00000100   ; ESC: the menu
        dw 1550 : db   4, 0, %00000100   ; DOWN
        dw 1600 : db   4, 2, %00000100   ; RETURN: NEW LAYERS
        dw 1650 : db   4, 2, %00000100   ; RETURN: YES, not saved
        dw 1700 : db   4, 8, %00000001   ; 1: layer 1
        dw 1720 : db   4, 6, %00100000   ; f: FILL
        dw 1750 : db   4, 1, %00000010   ; COPY: fill
        dw 2300 : db   4, 7, %00000010   ; 3: layer 3
        dw 2320 : db   4, 7, %10000000   ; x: BOX
        dw 2350 : db   4, 8, %00010000   ; TAB: cyan
        dw 2400 : db 100, 1, %00000010   ; COPY held
        dw 2410 : db  40, 0, %00000001   ; UP held
        dw 2600 : db   4, 5, %00010000   ; h: hide
        dw 2700 : db   4, 5, %00010000   ; h: show
        dw 2800 : db   4, 8, %00000100   ; ESC: the menu
        dw 2840 : db   4, 0, %00000100   ; DOWN
        dw 2880 : db   4, 0, %00000100   ; DOWN
        dw 2920 : db   4, 0, %00000100   ; DOWN
        dw 2960 : db   4, 0, %00000100   ; DOWN
        dw 3000 : db   4, 0, %00000100   ; DOWN
        dw 3040 : db   4, 0, %00000100   ; DOWN
        dw 3080 : db   4, 0, %00000100   ; DOWN
        dw 3150 : db   4, 2, %00000100   ; RETURN: OTHER DRIVE (B:)
        dw 3250 : db   4, 8, %00000100   ; ESC: the menu
        dw 3300 : db   4, 0, %00000100   ; DOWN
        dw 3340 : db   4, 0, %00000100   ; DOWN
        dw 3380 : db   4, 0, %00000100   ; DOWN
        dw 3420 : db   4, 0, %00000100   ; DOWN
        dw 3460 : db   4, 0, %00000100   ; DOWN
        dw 3500 : db   4, 0, %00000100   ; DOWN
        dw 3600 : db   4, 2, %00000100   ; RETURN: EXPORT .SCR
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
;   frame 1950  CONTROL+M    -> the page (mode 2): black on white, 80
;                               columns between two edges, PAGE 1
;   frame 2050  h i          -> "hi" on the page
;   frame 2150-3400 RETURN held -> many lines: past line 60, a line
;                               over the row of line 61, PAGE 2
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  480 : db   4, 0, %00000100   ; DOWN
        dw  520 : db   4, 0, %00000010   ; RIGHT
        dw  550 : db   4, 0, %00000010   ; RIGHT
        dw  580 : db   4, 0, %00000010   ; RIGHT
        dw  610 : db   4, 0, %00000010   ; RIGHT
        dw  660 : db   4, 2, %00000100   ; RETURN: NOTEPAD
        dw  800 : db   4, 5, %00010000   ; h
        dw  830 : db   4, 4, %00001000   ; i
        dw  860 : db   4, 2, %00000100   ; RETURN
        dw  890 : db   4, 6, %10000000   ; v
        dw  920 : db   4, 4, %00000100   ; o
        dw  950 : db   4, 7, %00010000   ; s
        dw 1000 : db   4, 1, %00000001   ; LEFT
        dw 1030 : db   4, 1, %00000001   ; LEFT
        dw 1060 : db   4, 9, %10000000   ; DEL
        dw 1145 : db  15, 2, %10000000   ; CONTROL
        dw 1150 : db   4, 7, %00010000   ; S
        dw 1250 : db   4, 9, %10000000   ; DEL
        dw 1280 : db   4, 9, %10000000   ; DEL
        dw 1310 : db   4, 9, %10000000   ; DEL
        dw 1340 : db   4, 9, %10000000   ; DEL
        dw 1370 : db   4, 9, %10000000   ; DEL
        dw 1400 : db   4, 9, %10000000   ; DEL
        dw 1430 : db   4, 6, %00001000   ; t
        dw 1480 : db   4, 2, %00000100   ; RETURN: save
        dw 1595 : db  15, 2, %10000000   ; CONTROL
        dw 1600 : db   4, 5, %01000000   ; N
        dw 1695 : db  15, 2, %10000000   ; CONTROL
        dw 1700 : db   4, 4, %00000100   ; O
        dw 1850 : db   4, 8, %00000100   ; ESC
        dw 1945 : db  15, 2, %10000000   ; CONTROL
        dw 1950 : db   4, 4, %01000000   ; M: the page
        dw 2050 : db   4, 5, %00010000   ; h
        dw 2080 : db   4, 4, %00001000   ; i
        dw 2150 : db 250, 2, %00000100   ; RETURN held
        dw 2400 : db 250, 2, %00000100   ; RETURN held
        dw 2650 : db 250, 2, %00000100   ; RETURN held
        dw 2900 : db 250, 2, %00000100   ; RETURN held
        dw 3150 : db 250, 2, %00000100   ; RETURN held
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
        dw  300 : db   4, 1, %01000000   ; F2: the Launcher
        dw  450 : db   4, 8, %00010000   ; TAB: drive B:
        dw  600 : db   4, 2, %00000100   ; RETURN: VROUVES
        dw  800 : db   4, 5, %10000000   ; SPACE: a Cretan
        dw  850 : db   4, 0, %00000001   ; UP
        dw  880 : db   4, 7, %00000001   ; 4: Psssst
        dw  910 : db   4, 5, %10000000   ; SPACE
        dw  960 : db   4, 5, %01000000   ; N: the first wave
        dw 1100 : db   4, 8, %00000100   ; ESC: the menu
        dw 1130 : db   4, 0, %00000100   ; DOWN
        dw 1160 : db   4, 0, %00000100   ; DOWN
        dw 1190 : db   4, 0, %00000100   ; DOWN
        dw 1220 : db   4, 0, %00000100   ; DOWN
        dw 1250 : db   4, 2, %00000100   ; RETURN: HIGH SCORES
        dw 1895 : db  15, 2, %10000000   ; CONTROL
        dw 1900 : db   4, 8, %00001000   ; Q
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  480 : db   4, 0, %00000100   ; DOWN
        dw  520 : db   4, 0, %00000010   ; RIGHT
        dw  550 : db   4, 0, %00000010   ; RIGHT
        dw  580 : db   4, 0, %00000010   ; RIGHT
        dw  610 : db   4, 0, %00000010   ; RIGHT
        dw  660 : db   4, 2, %00000100   ; RETURN: TEMPLATE
        dw  800 : db 100, 0, %00000010   ; RIGHT held
        dw  950 : db  50, 0, %00000001   ; UP held
        dw 1100 : db   4, 8, %00010000   ; TAB
        dw 1130 : db   4, 2, %00000100   ; RETURN: BEEP
        dw 1250 : db   4, 8, %00000100   ; ESC: the menu
        dw 1350 : db   4, 2, %00000100   ; RETURN: ABOUT
        dw 1450 : db   4, 2, %00000100   ; RETURN: OK
        dw 1545 : db  15, 2, %10000000   ; CONTROL
        dw 1550 : db   4, 8, %00001000   ; Q
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  480 : db   4, 0, %00000100   ; DOWN
        dw  520 : db   4, 0, %00000010   ; RIGHT
        dw  550 : db   4, 0, %00000010   ; RIGHT
        dw  580 : db   4, 0, %00000010   ; RIGHT
        dw  630 : db   4, 2, %00000100   ; RETURN: BRICKS
        dw  900 : db 100, 0, %00000010   ; RIGHT held
        dw 1200 : db 100, 1, %00000001   ; LEFT held
        dw 3600 : db   4, 5, %10000000   ; SPACE: a new game
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  400 : db   4, 0, %00000010   ; RIGHT
        dw  440 : db   4, 0, %00000010   ; RIGHT
        dw  480 : db   4, 2, %00000100   ; RETURN: STUDIO
        dw  795 : db  15, 2, %10000000   ; CONTROL
        dw  800 : db   4, 4, %00000100   ; O
        dw  860 : db   4, 0, %00000001   ; UP: the last file (VARS.VBS)
        dw  920 : db   4, 2, %00000100   ; RETURN
        dw 1000 : db   4, 0, %00000100   ; DOWN: SET A TO 1
        dw 1030 : db   4, 0, %00000010   ; RIGHT: its variable
        dw 1060 : db   4, 8, %00100000   ; A: A1
        dw 1090 : db   4, 8, %00100000   ; A: A2
        dw 1130 : db   4, 0, %00000100   ; DOWN
        dw 1140 : db   4, 0, %00000100   ; DOWN
        dw 1150 : db   4, 0, %00000100   ; DOWN
        dw 1160 : db   4, 0, %00000100   ; DOWN
        dw 1170 : db   4, 0, %00000100   ; DOWN
        dw 1180 : db   4, 0, %00000100   ; DOWN
        dw 1190 : db   4, 0, %00000100   ; DOWN
        dw 1200 : db   4, 0, %00000100   ; DOWN
        dw 1210 : db   4, 0, %00000100   ; DOWN
        dw 1220 : db   4, 0, %00000100   ; DOWN
        dw 1230 : db   4, 0, %00000100   ; DOWN
        dw 1240 : db   4, 0, %00000100   ; DOWN
        dw 1250 : db   4, 0, %00000100   ; DOWN
        dw 1260 : db   4, 0, %00000100   ; DOWN
        dw 1270 : db   4, 0, %00000100   ; DOWN
        dw 1280 : db   4, 0, %00000100   ; DOWN
        dw 1290 : db   4, 0, %00000100   ; DOWN
        dw 1300 : db   4, 0, %00000100   ; DOWN
        dw 1310 : db   4, 0, %00000100   ; DOWN
        dw 1320 : db   4, 0, %00000100   ; DOWN
        dw 1330 : db   4, 0, %00000100   ; DOWN
        dw 1340 : db   4, 0, %00000100   ; DOWN
        dw 1350 : db   4, 0, %00000100   ; DOWN
        dw 1380 : db   4, 0, %00000010   ; RIGHT, RIGHT: the group of
        dw 1410 : db   4, 0, %00000010   ; LOAD VARS A-H FROM "row1"
        dw 1440 : db   4, 8, %00100000   ; A: A1-H1
        dw 1595 : db  15, 2, %10000000   ; CONTROL
        dw 1600 : db   4, 6, %00000100   ; R
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  480 : db   4, 0, %00000100   ; DOWN
        dw  520 : db   4, 0, %00000010   ; RIGHT
        dw  550 : db   4, 0, %00000010   ; RIGHT
        dw  600 : db   4, 2, %00000100   ; RETURN: MINES
        dw 1180 : db 255, #80, 1         ; COPY is the left button
        dw 1435 : db 255, #80, 1
        dw 1690 : db 255, #80, 1
        dw 1945 : db 255, #80, 1
        dw 2200 : db  60, #80, 1
        dw 1200 : db  60, #81, 46        ; cell 0 (92, 93)
        dw 1200 : db  60, #82, 93
        dw 1230 : db   4, 1, %00000010
        dw 1260 : db  60, #81, 60        ; cell 1
        dw 1260 : db  60, #82, 93
        dw 1290 : db   4, 1, %00000010
        dw 1320 : db  60, #81, 74        ; cell 2
        dw 1320 : db  60, #82, 93
        dw 1350 : db   4, 1, %00000010
        dw 1380 : db  60, #81, 88        ; cell 3
        dw 1380 : db  60, #82, 93
        dw 1410 : db   4, 1, %00000010
        dw 1440 : db  60, #81, 102       ; cell 4
        dw 1440 : db  60, #82, 93
        dw 1470 : db   4, 1, %00000010
        dw 1500 : db  60, #81, 116       ; cell 5
        dw 1500 : db  60, #82, 93
        dw 1530 : db   4, 1, %00000010
        dw 1560 : db  60, #81, 130       ; cell 6
        dw 1560 : db  60, #82, 93
        dw 1590 : db   4, 1, %00000010
        dw 1620 : db  60, #81, 144       ; cell 7
        dw 1620 : db  60, #82, 93
        dw 1650 : db   4, 1, %00000010
        dw 1680 : db  60, #81, 46        ; cell 8
        dw 1680 : db  60, #82, 111
        dw 1710 : db   4, 1, %00000010
        dw 1740 : db  60, #81, 60        ; cell 9
        dw 1740 : db  60, #82, 111
        dw 1770 : db   4, 1, %00000010
        dw 1800 : db  60, #81, 74        ; cell 10
        dw 1800 : db  60, #82, 111
        dw 1830 : db   4, 1, %00000010
        dw 1860 : db  60, #81, 88        ; cell 11
        dw 1860 : db  60, #82, 111
        dw 1890 : db   4, 1, %00000010
        dw 1920 : db  60, #81, 102       ; cell 12
        dw 1920 : db  60, #82, 111
        dw 1950 : db   4, 1, %00000010
        dw 1980 : db  60, #81, 116       ; cell 13
        dw 1980 : db  60, #82, 111
        dw 2010 : db   4, 1, %00000010
        dw 2040 : db  60, #81, 130       ; cell 14
        dw 2040 : db  60, #82, 111
        dw 2070 : db   4, 1, %00000010
        dw 2100 : db  60, #81, 144       ; cell 15
        dw 2100 : db  60, #82, 111
        dw 2130 : db   4, 1, %00000010
        dw 2200 : db  50, #81, 54        ; NEW (108, 203)
        dw 2200 : db  50, #82, 203
        dw 2220 : db   4, 1, %00000010
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
        dw  300 : db   4, 2, %00010000   ; F4
        dw  400 : db   4, 0, %00000100   ; DOWN: LANGUAGE
        dw  450 : db   4, 0, %00000010   ; RIGHT: Greek
        dw  600 : db   4, 0, %00000010   ; RIGHT: French
        dw  750 : db   4, 0, %00000010   ; RIGHT: Spanish
        dw  900 : db   4, 0, %00000010   ; RIGHT: German
        dw 1050 : db   4, 0, %00000010   ; RIGHT: Italian
        dw 1200 : db   4, 1, %00100000   ; F1
        dw 1345 : db  15, 2, %10000000   ; CONTROL
        dw 1350 : db   4, 5, %01000000   ; N
        dw 1445 : db  15, 2, %10000000   ; CONTROL, then
        dw 1450 : db   4, 2, %00100000   ; SHIFT
        dw 1500 : db   4, 3, %00000100   ; @
        dw 1550 : db   4, 3, %00010000   ; ;
        dw 1600 : db   4, 2, %00001000   ; ]
        dw 1650 : db   4, 3, %00100000   ; :
        dw 1800 : db   4, 8, %00000100   ; ESC
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
        dw  300 : db 120, #80, 1         ; COPY and the cursor keys
        dw  300 : db  40, #81, 50        ; FILES's title bar (100, 23)
        dw  300 : db  40, #82, 23
        dw  340 : db  80, 1, %00000010   ; COPY held
        dw  350 : db  30, 0, %00000010   ; RIGHT
        dw  350 : db  15, 0, %00000100   ; DOWN
        dw  495 : db  15, 2, %10000000   ; CONTROL
        dw  500 : db   4, 4, %00100000   ; K: the keys dialog
        dw  600 : db 140, #80, 1
        dw  600 : db  40, #81, 75        ; its title bar (150, 64)
        dw  600 : db  40, #82, 64
        dw  640 : db  80, 1, %00000010   ; COPY held
        dw  650 : db  25, 1, %00000001   ; LEFT
        dw  650 : db  30, 0, %00000100   ; DOWN
        dw  750 : db   1, #80, 0
        dw  800 : db   4, 2, %00000100   ; RETURN: OK
        dw  900 : db   4, 1, %01000000   ; F2
        dw 1020 : db   4, 0, %00000100   ; DOWN
        dw 1050 : db   4, 0, %00000100   ; DOWN
        dw 1080 : db   4, 0, %00000100   ; DOWN
        dw 1115 : db  15, 2, %10000000   ; CONTROL
        dw 1120 : db   4, 8, %00100000   ; A: CLOCK as the accessory
        dw 1200 : db 140, #80, 1
        dw 1200 : db  40, #81, 20        ; its title bar (40, 20, mode 0)
        dw 1200 : db  40, #82, 20
        dw 1240 : db  80, 1, %00000010   ; COPY held
        dw 1250 : db  25, 0, %00000010   ; RIGHT
        dw 1250 : db  40, 0, %00000100   ; DOWN
        dw 1350 : db   1, #80, 0
        dw 1500 : db   4, 1, %00010000   ; F5
        dw 1550 : db   4, 0, %00000001   ; UP
        dw 1580 : db   4, 0, %00000010   ; RIGHT
        dw 1610 : db   4, 0, %00000010   ; RIGHT
        dw 1660 : db   4, 2, %00000100   ; RETURN: CALC
        dw 2000 : db 140, #80, 1
        dw 2000 : db  40, #81, 75        ; its title bar (150, 76)
        dw 2000 : db  40, #82, 76
        dw 2040 : db  80, 1, %00000010   ; COPY held
        dw 2050 : db  25, 0, %00000010   ; RIGHT
        dw 2050 : db  25, 0, %00000100   ; DOWN
        dw 2150 : db 110, #80, 1         ; then its button 1, moved
        dw 2150 : db 110, #81, 76        ; with it (152, 204): 1 shown
        dw 2150 : db 110, #82, 204
        dw 2200 : db   4, 1, %00000010   ; COPY
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  400 : db   4, 0, %00000010   ; RIGHT
        dw  440 : db   4, 0, %00000010   ; RIGHT
        dw  480 : db   4, 2, %00000100   ; RETURN
        dw  800 : db   4, 8, %00000100   ; ESC
        dw  850 : db   4, 0, %00000100   ; DOWN
        dw  880 : db   4, 0, %00000100   ; DOWN
        dw  910 : db   4, 0, %00000100   ; DOWN
        dw  940 : db   4, 0, %00000100   ; DOWN
        dw  970 : db   4, 0, %00000100   ; DOWN
        dw 1010 : db   4, 2, %00000100   ; RETURN
        dw 1100 : db   4, 2, %00000100   ; RETURN
        dw 1150 : db   4, 8, %00000100   ; ESC
        dw 1200 : db   4, 0, %00000100   ; DOWN
        dw 1230 : db   4, 0, %00000100   ; DOWN
        dw 1260 : db   4, 0, %00000100   ; DOWN
        dw 1290 : db   4, 0, %00000100   ; DOWN
        dw 1320 : db   4, 0, %00000100   ; DOWN
        dw 1360 : db   4, 2, %00000100   ; RETURN
        dw 1450 : db   4, 8, %00000100   ; ESC
        dw 1550 : db   4, 1, %01000000   ; F2
        dw 1650 : db   4, 0, %00000100   ; DOWN
        dw 1680 : db   4, 0, %00000100   ; DOWN
        dw 1710 : db   4, 0, %00000010   ; RIGHT
        dw 1740 : db   4, 0, %00000010   ; RIGHT
        dw 1800 : db   4, 2, %00000100   ; RETURN
        dw 2100 : db   4, 1, %01000000   ; F2
        dw 2200 : db   4, 0, %00000001   ; UP
        dw 2230 : db   4, 0, %00000001   ; UP
        dw 2260 : db   4, 0, %00000001   ; UP
        dw 2290 : db   4, 1, %00000001   ; LEFT
        dw 2330 : db   4, 2, %00000100   ; RETURN
        dw 2700 : db   4, 0, %00010000   ; F6
        dw 2750 : db   4, 0, %00000100   ; DOWN
        dw 2800 : db   4, 2, %00000100   ; RETURN
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  400 : db   4, 0, %00000010   ; RIGHT
        dw  440 : db   4, 0, %00000010   ; RIGHT
        dw  480 : db   4, 2, %00000100   ; RETURN
        dw  750 : db   4, 1, %01000000   ; F2
        dw  850 : db   4, 1, %00000001   ; LEFT
        dw  890 : db   4, 1, %00000001   ; LEFT
        dw  930 : db   4, 2, %00000100   ; RETURN
        dw 1100 : db   4, 1, %01000000   ; F2
        dw 1200 : db   4, 0, %00000100   ; DOWN
        dw 1260 : db   4, 2, %00000100   ; RETURN
        dw 1450 : db   4, 1, %01000000   ; F2
        dw 1550 : db   4, 0, %00000010   ; RIGHT
        dw 1590 : db   4, 0, %00000010   ; RIGHT
        dw 1630 : db   4, 0, %00000100   ; DOWN
        dw 1670 : db   4, 2, %00000100   ; RETURN
        dw 1950 : db   4, 0, %00010000   ; F6
        dw 2050 : db   4, 2, %00000100   ; RETURN
        dw 2300 : db   4, 0, %00010000   ; F6
        dw 2350 : db   4, 2, %00000100   ; RETURN
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
        dw  250 : db   4, 0, %00010000   ; F6
        dw  330 : db   4, 2, %00000100   ; RETURN
        dw  400 : db   4, 1, %01000000   ; F2
        dw  500 : db   4, 2, %00000100   ; RETURN
        dw  580 : db   4, 5, %10000000   ; SPACE
        dw  680 : db   4, 1, %01000000   ; F2
        dw  780 : db   4, 0, %00000100   ; DOWN
        dw  840 : db   4, 2, %00000100   ; RETURN
        dw 1000 : db   4, 0, %00010000   ; F6
        dw 1100 : db   4, 2, %00000100   ; RETURN
        dw 1250 : db   4, 0, %00010000   ; F6
        dw 1300 : db   4, 0, %00010000   ; F6
        dw 1450 : db   4, 8, %00000100   ; ESC
        dw 1550 : db   4, 0, %00100000   ; F3
        dw 1700 : db   4, 8, %00000100   ; ESC
        dw 1750 : db   4, 0, %00000010   ; RIGHT
        dw 1800 : db   4, 0, %00000100   ; DOWN
        dw 1840 : db   4, 0, %00000100   ; DOWN
        dw 1880 : db   4, 0, %00000100   ; DOWN
        dw 1920 : db   4, 0, %00000100   ; DOWN
        dw 2050 : db   4, 2, %00000100   ; RETURN
        dw 2250 : db   4, 0, %00000100   ; DOWN
        dw 2350 : db   4, 2, %00000100   ; RETURN
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  400 : db   4, 2, %00000100   ; RETURN
        dw  480 : db   4, 5, %10000000   ; SPACE
        dw  520 : db   4, 5, %10000000   ; SPACE
        dw  600 : db   4, 1, %01000000   ; F2
        dw  700 : db   4, 0, %00000100   ; DOWN
        dw  760 : db   4, 2, %00000100   ; RETURN
        dw  900 : db   4, 1, %01000000   ; F2
        dw 1000 : db   4, 0, %00000001   ; UP
        dw 1060 : db   4, 2, %00000100   ; RETURN
        dw 1195 : db  15, 2, %10000000   ; CONTROL
        dw 1200 : db   4, 8, %00001000   ; Q
        dw 1300 : db   4, 0, %00000100   ; DOWN
        dw 1360 : db   4, 2, %00000100   ; RETURN
        dw 1500 : db   4, 1, %01000000   ; F2
        dw 1600 : db   4, 0, %00000001   ; UP
        dw 1640 : db   4, 0, %00000010   ; RIGHT
        dw 1680 : db   4, 0, %00000010   ; RIGHT
        dw 1720 : db   4, 2, %00000100   ; RETURN
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000100   ; DOWN
        dw  450 : db   4, 0, %00000100   ; DOWN
        dw  480 : db   4, 0, %00000100   ; DOWN
        dw  515 : db  15, 2, %10000000   ; CONTROL
        dw  520 : db   4, 8, %00100000   ; A
        dw  700 : db   4, 1, %00010000   ; F5
        dw  760 : db   4, 0, %00000001   ; UP
        dw  790 : db   4, 0, %00000001   ; UP
        dw  820 : db   4, 0, %00000001   ; UP
        dw  850 : db   4, 0, %00000010   ; RIGHT
        dw  880 : db   4, 0, %00000010   ; RIGHT
        dw  950 : db   4, 2, %00000100   ; RETURN
        dw 1300 : db   4, 1, %00010000   ; F5
        dw 1600 : db   4, 8, %00000100   ; ESC
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
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000010   ; RIGHT
        dw  470 : db   4, 0, %00000010   ; RIGHT
        dw  560 : db   4, 2, %00000100   ; RETURN
        dw  800 : db   4, 8, %00010000   ; TAB
        dw  850 : db   4, 8, %00010000   ; TAB
        dw  900 : db   4, 7, %00000100   ; E
        dw  950 : db   4, 4, %00000010   ; 9
        dw 1000 : db   4, 5, %10000000   ; SPACE
        dw 1030 : db   4, 0, %00000010   ; RIGHT
        dw 1060 : db   4, 5, %10000000   ; SPACE
        dw 1090 : db   4, 0, %00000100   ; DOWN
        dw 1120 : db   4, 5, %10000000   ; SPACE
        dw 1150 : db   4, 8, %00100000   ; A
        dw 1180 : db   4, 0, %00000010   ; RIGHT
        dw 1210 : db   4, 5, %10000000   ; SPACE
        dw 1250 : db   1, #80, 1         ; COPY is the left button
        dw 1250 : db  90, #81, 49        ; cell 10,10: x 49 in mode 0
        dw 1250 : db  90, #82, 89
        dw 1300 : db   4, 1, %00000010   ; COPY
        dw 1340 : db  60, #81, 21        ; pen 3
        dw 1340 : db  60, #82, 133
        dw 1360 : db   4, 1, %00000010
        dw 1400 : db  50, #81, 53        ; cell 11,10
        dw 1400 : db  50, #82, 89
        dw 1420 : db   4, 1, %00000010
        dw 1460 : db   1, #80, 0
        dw 1500 : db   4, 7, %00000100   ; E
        dw 1595 : db  15, 2, %10000000   ; CONTROL
        dw 1600 : db   4, 6, %00000100   ; R
        dw 1700 : db   4, 2, %00000100   ; RETURN: the name NONAME
        dw 2395 : db  15, 2, %10000000   ; CONTROL
        dw 2400 : db   4, 8, %00001000   ; Q
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
        dw  300 : db   4, 2, %00010000   ; F4
        dw  445 : db  15, 2, %10000000   ; CONTROL
        dw  450 : db   4, 4, %00010000   ; L
        dw  550 : db   4, 2, %00000100   ; RETURN
        dw  695 : db  15, 2, %10000000   ; CONTROL
        dw  700 : db   4, 8, %00001000   ; Q
        dw  800 : db   4, 2, %00000100   ; RETURN
        dw #FFFF
        ELSE
test_keys:
        dw  300 : db   4, 1, %01000000   ; F2
        dw  420 : db   4, 0, %00000010   ; RIGHT
        dw  470 : db   4, 0, %00000010   ; RIGHT
        dw  560 : db   4, 2, %00000100   ; RETURN
        dw  800 : db   4, 0, %00000100   ; DOWN
        dw  850 : db   4, 0, %00000010   ; RIGHT
        dw  900 : db   4, 6, %00000010   ; 5
        dw  950 : db   4, 8, %00010000   ; TAB
        dw 1000 : db   4, 0, %00000010   ; RIGHT
        dw 1050 : db   4, 0, %00000100   ; DOWN
        dw 1100 : db   4, 2, %00000100   ; RETURN
        dw 1150 : db   4, 8, %00010000   ; TAB
        dw 1200 : db  40, 0, %00000010   ; RIGHT held
        dw 1280 : db   4, 7, %01000000   ; C
        dw 1330 : db   4, 8, %00010000   ; TAB
        dw 1375 : db  15, 2, %10000000   ; CONTROL
        dw 1380 : db   4, 7, %00010000   ; S
        dw 1450 : db   4, 2, %00000100   ; RETURN
        dw 1595 : db  15, 2, %10000000   ; CONTROL
        dw 1600 : db   4, 5, %01000000   ; N
        dw 1650 : db   4, 2, %00000100   ; RETURN
        dw 1745 : db  15, 2, %10000000   ; CONTROL
        dw 1750 : db   4, 4, %00000100   ; O
        dw 1850 : db   4, 0, %00000001   ; UP
        dw 2050 : db   4, 2, %00000100   ; RETURN
        dw 2150 : db   1, #80, 1         ; COPY is the left button
        dw 2150 : db 255, #81, 20        ; palette, row 3: IF
        dw 2405 : db 255, #81, 20
        dw 2660 : db  40, #81, 20
        dw 2150 : db 150, #82, 172
        dw 2200 : db   4, 1, %00000010   ; COPY
        dw 2300 : db 255, #82, 152       ; script line 2, slot 0
        dw 2555 : db 145, #82, 152
        dw 2300 : db 255, #81, 76
        dw 2555 : db  45, #81, 76
        dw 2350 : db   4, 1, %00000010   ; COPY
        dw 2500 : db   4, 1, %00000010   ; COPY
        dw 2600 : db 100, #81, 20        ; the stage
        dw 2600 : db 100, #82, 40
        dw 2650 : db   4, 1, %00000010   ; COPY
        dw 2745 : db  15, 2, %10000000   ; CONTROL
        dw 2750 : db   4, 6, %00000100   ; R
        dw 3395 : db  15, 2, %10000000   ; CONTROL
        dw 3400 : db   4, 8, %00001000   ; Q
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
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
        ENDIF
