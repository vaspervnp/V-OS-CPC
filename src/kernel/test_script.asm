; =====================================================================
; test_script.asm - scripted key presses for emulator tests
;
; Built only with -DTEST_SCRIPT=1 (make test-input). Caprice32 can type
; text into the emulated CPC but cannot press cursor keys or COPY, so
; this script ORs key bits into kbd_now after each matrix scan, by frame
; number since boot. Everything after the scan (events, repeat, pointer)
; runs as for real keys. Keys the harness types itself are masked out:
; Z (used to wait, tools/cap32_shot.sh) and SHIFT, \ and 8 (Caprice32
; types "\(" before taking a screenshot). Otherwise their events would
; keep the pointer hidden at the moment of the shot.
;
; M8b/M8c Studio, English UI. Drive A: VOS.BIN, the view overlays,
; GREEK.LNG, DEMO.BIN, MIXED.BIN, STUDIO.BIN, PONG, CATCH, STARCAT, and
; CALC.BIN, CALC.VBS.
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
;   frame 1850-2044 DOWN held -> its last file, NONAME.VBS
;   frame 2050  RETURN       -> opened: SPEED 5 2, REPEAT 10, the
;                               orange sprite at 116 120
;   (test only) the pointer is placed and COPY clicks:
;   frame 2200  click on IF in the palette -> IF KEY SPACE, END below
;                               the first line
;   frame 2350  click on its first slot -> chosen
;   frame 2500  click on it again -> TOUCHING 1
;   frame 2650  click on the stage at 20, 40 -> the sprite at 38 66
;   frame 2750  CONTROL+R    -> NONAME.VBS and NONAME.BIN saved, the
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
; make test-calc (-DTEST_SCRIPT=2): CALC.BIN, a Studio program
; (blocks/examples/calc.vbt), then Studio with CALC.VBS. Expected:
;   frame  300  F2           -> Launcher
;   frame  420, 470 DOWN, 510 RIGHT -> CALC chosen (after COUNTER)
;   frame  560  RETURN       -> the calculator in mode 1: a window,
;                               16 buttons
;   (the pointer is placed and COPY clicks)
;   frame  950, 1050, 1150   -> 1, 2, +: 12 shown
;   frame 1250, 1350         -> 3, =: 15 shown
;   frame 1500  CONTROL+Q    -> the Launcher, CALC still chosen
;   frame 1700, 1750 UP, 1800 RIGHT, 1900 RETURN -> Studio
;   frame 2100  CONTROL+O    -> the file list
;   frame 2160-2394 DOWN held, 2400 RETURN -> CALC.VBS opened
;   frame 2600  TAB, 2650 LEFT -> the palette: WINDOWS
;   frame 2800  RETURN       -> WINDOW added, the dialog asks its text
;   frame 2900, 2950 H, I, 3050 RETURN -> WINDOW "ΗΙ" 120 100
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  420,  424 : db 0, %00000100   ; DOWN
        dw  470,  474 : db 0, %00000100   ; DOWN
        dw  510,  514 : db 0, %00000010   ; RIGHT
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
        dw 1800, 1804 : db 0, %00000010   ; RIGHT
        dw 1900, 1904 : db 2, %00000100   ; RETURN
        dw 2095, 2110 : db 2, %10000000   ; CONTROL
        dw 2100, 2104 : db 4, %00000100   ; O
        dw 2160, 2395 : db 0, %00000100   ; DOWN held
        dw 2400, 2404 : db 2, %00000100   ; RETURN
        dw 2600, 2604 : db 8, %00010000   ; TAB
        dw 2650, 2654 : db 1, %00000001   ; LEFT
        dw 2800, 2804 : db 2, %00000100   ; RETURN
        dw 2900, 2904 : db 5, %00010000   ; H
        dw 2950, 2954 : db 4, %00001000   ; I
        dw 3050, 3054 : db 2, %00000100   ; RETURN
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
        dw 1850, 2045 : db 0, %00000100   ; DOWN held
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
