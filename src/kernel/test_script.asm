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
; Pointer starts at (192,120) in mode 1. Expected result:
;   frame 100-129  RIGHT held   -> x about 255
;   frame 135-176  DOWN held    -> y about 231 (inside the click box)
;   frame 185      COPY click   -> dot
;   frame 195-204  RIGHT held   -> x about 266
;   frame 210      COPY click   -> second dot
;   frame 220/228  'h', 'i'     -> "hi" in TYPED
;   frame 400      F2           -> mode 0, x clamped to 191
;   frame 420-434  LEFT held    -> x about 170
;   frame 440      COPY click   -> dot in the mode 0 box
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
        dw 100, 130 : db 0, %00000010     ; RIGHT
        dw 135, 177 : db 0, %00000100     ; DOWN
        dw 185, 188 : db 1, %00000010     ; COPY
        dw 195, 205 : db 0, %00000010     ; RIGHT
        dw 210, 213 : db 1, %00000010     ; COPY
        dw 220, 223 : db 5, %00010000     ; H
        dw 228, 231 : db 4, %00001000     ; I
        dw 400, 403 : db 1, %01000000     ; F2
        dw 420, 435 : db 1, %00000001     ; LEFT
        dw 440, 443 : db 1, %00000010     ; COPY
        dw #FFFF
