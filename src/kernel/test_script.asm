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
; M7b block programs, Greek UI. Drive A: VOS.BIN, the view overlays,
; GREEK.LNG, DEMO.BIN, and PONG, CATCH, STARCAT (blocks/examples).
; Expected result:
;   frame  300  F2           -> Launcher: four tiles
;   frame  450, 480, 510 RIGHT -> STARCAT chosen
;   frame  600  RETURN       -> STARCAT runs: mode 0, the cat and the
;                               star (costumes), a tune, list results
;                               4 9 5 1 / 0 2 7 0
;   frame  700-899  LEFT held  -> the cat walks left (two costumes)
;   frame 1000-1149 RIGHT held -> and right
;   frame 1300  SPACE        -> "when SPACE pressed: stop all": Launcher
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
        dw  450,  454 : db 0, %00000010   ; RIGHT
        dw  480,  484 : db 0, %00000010   ; RIGHT
        dw  510,  514 : db 0, %00000010   ; RIGHT
        dw  600,  604 : db 2, %00000100   ; RETURN
        dw  700,  900 : db 1, %00000001   ; LEFT held
        dw 1000, 1150 : db 0, %00000010   ; RIGHT held
        dw 1300, 1304 : db 5, %10000000   ; SPACE
        dw #FFFF
