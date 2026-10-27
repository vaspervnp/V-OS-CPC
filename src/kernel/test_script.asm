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
; M5 shell, Greek UI. Drive A: VOS.BIN, GREEK.LNG and the three view
; overlays; drive B: HELLO.TXT and BIG.BIN, 20000 bytes (make:
; build/vos_b.dsk). Expected result:
;   frame  300  RIGHT        -> Desktop, A: GREEK.LNG selected
;   frame  350  RETURN       -> its info; 500 RETURN closes it
;   frame  550  TAB          -> the window shows B:
;   frame  700  RIGHT        -> BIG.BIN
;   frame  750  CONTROL+C    -> copied to A:, 20K in two passes
;   frame 2600  RETURN       -> closed
;   frame 2700  F3           -> Commander: A: has BIG.BIN
;   frame 2900  TAB          -> B: panel, HELLO.TXT
;   frame 2950  CONTROL+N    -> rename: "HELLO.TXT"
;   frame 3050  DEL x3, then D O C, 3250 RETURN -> HELLO.DOC
;   frame 3450  F2           -> Launcher, mode 0: BIG.BIN's tile
;   frame 3650  F1           -> Desktop again (A:)
;   frame 3850  CONTROL+Q, 3950 RETURN -> restart into BASIC, where the
;               harness checks both drives with AMSDOS
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
test_keys:
        dw  300,  304 : db 0, %00000010   ; RIGHT
        dw  350,  354 : db 2, %00000100   ; RETURN
        dw  500,  504 : db 2, %00000100   ; RETURN
        dw  550,  554 : db 8, %00010000   ; TAB
        dw  700,  704 : db 0, %00000010   ; RIGHT
        dw  750,  762 : db 2, %10000000   ; CONTROL held ...
        dw  753,  757 : db 7, %01000000   ; ... C
        dw 2600, 2604 : db 2, %00000100   ; RETURN
        dw 2700, 2704 : db 0, %00100000   ; F3
        dw 2900, 2904 : db 8, %00010000   ; TAB
        dw 2950, 2962 : db 2, %10000000   ; CONTROL held ...
        dw 2953, 2957 : db 5, %01000000   ; ... N
        dw 3050, 3054 : db 9, %10000000   ; DEL
        dw 3070, 3074 : db 9, %10000000   ; DEL
        dw 3090, 3094 : db 9, %10000000   ; DEL
        dw 3110, 3114 : db 7, %00100000   ; D
        dw 3130, 3134 : db 4, %00000100   ; O
        dw 3150, 3154 : db 7, %01000000   ; C
        dw 3250, 3254 : db 2, %00000100   ; RETURN
        dw 3450, 3454 : db 1, %01000000   ; F2
        dw 3650, 3654 : db 1, %00100000   ; F1
        dw 3850, 3862 : db 2, %10000000   ; CONTROL held ...
        dw 3853, 3857 : db 8, %00001000   ; ... Q
        dw 3950, 3954 : db 2, %00000100   ; RETURN
        dw #FFFF
