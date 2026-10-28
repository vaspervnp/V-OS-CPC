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
; M6 programs, Greek UI. Drive A: VOS.BIN, the view overlays, GREEK.LNG,
; DEMO.BIN (apps/demo). Expected result:
;   frame  300  F2           -> Launcher: the DEMO tile
;   frame  600  RETURN       -> DEMO runs: mode 0, a moving square
;   frame  950  RIGHT, 1000 SPACE -> it turns right, another colour
;   frame 1100  CONTROL+L    -> its texts in English (VOS_TEXTS)
;   frame 1250  ESC          -> its own DEMO menu; 1350 ESC closes it
;   frame 1400  CONTROL+Q    -> back to the Launcher
;   frame 1700  F1           -> Desktop, DEMO.BIN still selected
;   frame 2000  LEFT         -> GREEK.LNG
;   frame 2200  ESC, 2250 RETURN -> FILE / RUN: "NOT A V-OS PROGRAM"
;   frame 2400  RETURN       -> closed
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
        dw  300,  304 : db 1, %01000000   ; F2
        dw  600,  604 : db 2, %00000100   ; RETURN
        dw  950,  954 : db 0, %00000010   ; RIGHT
        dw 1000, 1004 : db 5, %10000000   ; SPACE
        dw 1100, 1112 : db 2, %10000000   ; CONTROL held ...
        dw 1103, 1107 : db 4, %00010000   ; ... L
        dw 1250, 1254 : db 8, %00000100   ; ESC
        dw 1350, 1354 : db 8, %00000100   ; ESC
        dw 1400, 1412 : db 2, %10000000   ; CONTROL held ...
        dw 1403, 1407 : db 8, %00001000   ; ... Q
        dw 1700, 1704 : db 1, %00100000   ; F1
        dw 2000, 2004 : db 1, %00000001   ; LEFT
        dw 2200, 2204 : db 8, %00000100   ; ESC
        dw 2250, 2254 : db 2, %00000100   ; RETURN
        dw 2400, 2404 : db 2, %00000100   ; RETURN
        dw #FFFF
