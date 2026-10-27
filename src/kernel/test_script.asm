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
; M5 Commander, Greek UI. Drive A: VOS.BIN, GREEK.LNG; drive B:
; HELLO.TXT (make: build/vos_b.dsk). Expected result:
;   frame  200  DOWN         -> A: GREEK.LNG selected
;   frame  260  RETURN       -> info: size, binary, load #8000, "VLNG..."
;   frame  450  RETURN       -> closed
;   frame  500  CONTROL+C    -> GREEK.LNG copied to B:, B: panel shows it
;   frame  700  RETURN       -> closed
;   frame  750  TAB          -> B: active, HELLO.TXT selected
;   frame  800  CONTROL+C    -> HELLO.TXT (no header) copied to A:
;   frame 1000  RETURN       -> closed
;   frame 1050  CONTROL+D    -> "DELETE HELLO.TXT?"
;   frame 1150  RETURN       -> YES: B: keeps GREEK.LNG only
;   frame 1300  TAB          -> A: active
;   frame 1350  DOWN         -> A: HELLO.TXT
;   frame 1400  RETURN       -> info: text, "HELLO FROM DRIVE B"
;   frame 1600  RETURN       -> closed
;   frame 1650  CONTROL+L    -> English UI
;   frame 1750  CONTROL+Q, 1850 RETURN -> restart into BASIC, where the
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
        dw  200,  204 : db 0, %00000100   ; DOWN
        dw  260,  264 : db 2, %00000100   ; RETURN
        dw  450,  454 : db 2, %00000100   ; RETURN
        dw  500,  512 : db 2, %10000000   ; CONTROL held ...
        dw  503,  507 : db 7, %01000000   ; ... C
        dw  700,  704 : db 2, %00000100   ; RETURN
        dw  750,  754 : db 8, %00010000   ; TAB
        dw  800,  812 : db 2, %10000000   ; CONTROL held ...
        dw  803,  807 : db 7, %01000000   ; ... C
        dw 1000, 1004 : db 2, %00000100   ; RETURN
        dw 1050, 1062 : db 2, %10000000   ; CONTROL held ...
        dw 1053, 1057 : db 7, %00100000   ; ... D
        dw 1150, 1154 : db 2, %00000100   ; RETURN
        dw 1300, 1304 : db 8, %00010000   ; TAB
        dw 1350, 1354 : db 0, %00000100   ; DOWN
        dw 1400, 1404 : db 2, %00000100   ; RETURN
        dw 1600, 1604 : db 2, %00000100   ; RETURN
        dw 1650, 1662 : db 2, %10000000   ; CONTROL held ...
        dw 1653, 1657 : db 4, %00010000   ; ... L
        dw 1750, 1762 : db 2, %10000000   ; CONTROL held ...
        dw 1753, 1757 : db 8, %00001000   ; ... Q
        dw 1850, 1854 : db 2, %00000100   ; RETURN
        dw #FFFF
