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
; M8a mixed screen, Greek UI. Drive A: VOS.BIN, the view overlays,
; GREEK.LNG, DEMO.BIN, MIXED.BIN, and PONG, CATCH, STARCAT (blocks/).
; Expected result:
;   frame  300  F2           -> Launcher: five tiles
;   frame  450  RIGHT        -> MIXED chosen
;   frame  600  RETURN       -> MIXED runs: menu bar and status line in
;                               mode 1, 16 colours and a square in mode 0
;   frame  680  (test only) cursor keys move the pointer, as in Desktop
;   frame  700-899  UP and LEFT held -> the pointer at the top left
;   frame  920-934  RIGHT held -> on the first title, in the mode 1 band
;   frame 1000  COPY         -> its menu opens, in mode 0, under the bar
;   frame 1100  ESC          -> closed
;   frame 1150-1199 DOWN held -> the pointer in the mode 0 band
;   frame 1250  COPY         -> the status line shows the click's x, y
;                               (x in mode 0 pixels)
;   frame 1400  SPACE        -> back to the Launcher, mode 0 everywhere
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
        jr nz,.key                  ; pointer (1) or not (0)
        ld a,(ix+5)
        ld (ptr_keys_on),a
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
; (line #80: bits = ptr_keys_on)
test_keys:
        dw  300,  304 : db 1, %01000000   ; F2
        dw  450,  454 : db 0, %00000010   ; RIGHT
        dw  600,  604 : db 2, %00000100   ; RETURN
        dw  680,  681 : db #80, 1         ; cursor keys move the pointer
        dw  700,  900 : db 0, %00000001   ; UP held
        dw  700,  900 : db 1, %00000001   ; LEFT held
        dw  920,  935 : db 0, %00000010   ; RIGHT held
        dw 1000, 1004 : db 1, %00000010   ; COPY
        dw 1100, 1104 : db 8, %00000100   ; ESC
        dw 1150, 1200 : db 0, %00000100   ; DOWN held
        dw 1250, 1254 : db 1, %00000010   ; COPY
        dw 1400, 1404 : db 5, %10000000   ; SPACE
        dw #FFFF
