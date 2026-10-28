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
; M8b/M8c Studio, Greek UI. Drive A: VOS.BIN, the view overlays,
; GREEK.LNG, DEMO.BIN, MIXED.BIN, STUDIO.BIN, and PONG, CATCH, STARCAT.
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
;   frame 1850-1999 DOWN held -> its last file, NONAME.VBS
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
        ld a,(kbd_now + 8)          ; hide Z: the harness types it as a wait
        and %01111111
        ld (kbd_now + 8),a
        ld a,(kbd_now + 2)          ; hide SHIFT and \, and 8 below: Caprice32
        and %10011111               ; types "\(" just before each screenshot
        ld (kbd_now + 2),a
        ld a,(kbd_now + 5)
        and %11111110
        ld (kbd_now + 5),a
        ld hl,(int_frames)
        ld ix,test_keys
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

; dw first frame, frame after the last; db matrix line, bits
; (line #80: bits = ptr_keys_on; #81: pointer x = bits * 2, in mode 1
; pixels; #82: pointer y = bits)
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
        dw 1850, 2000 : db 0, %00000100   ; DOWN held
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
