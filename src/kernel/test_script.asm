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
;   frame 220-240  h i space    -> "hi " in TYPED
;   frame 250-262  CONTROL+SHIFT -> typing EL, event "LANG EL"
;   frame 270-371  k a l h m ; e r a space G e i a space ; A
;                               -> "hi καλημέρα Γεια Ά" (; = tonos)
;   frame 600      F3           -> labels in English
;   frame 700      F2           -> mode 0, x clamped to 191
;   frame 720-734  LEFT held    -> x about 170
;   frame 740      COPY click   -> dot in the mode 0 box
;   frame 800      F3           -> labels in Greek again
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
        dw 236, 239 : db 5, %10000000     ; SPACE
        dw 250, 263 : db 2, %10000000     ; CONTROL held ...
        dw 254, 259 : db 2, %00100000     ; ... then SHIFT: typing EL
        dw 270, 273 : db 4, %00100000     ; K  κ
        dw 276, 279 : db 8, %00100000     ; A  α
        dw 282, 285 : db 4, %00010000     ; L  λ
        dw 288, 291 : db 5, %00010000     ; H  η
        dw 294, 297 : db 4, %01000000     ; M  μ
        dw 300, 303 : db 3, %00010000     ; ;  tonos (dead)
        dw 306, 309 : db 7, %00000100     ; E  έ
        dw 312, 315 : db 6, %00000100     ; R  ρ
        dw 318, 321 : db 8, %00100000     ; A  α
        dw 324, 327 : db 5, %10000000     ; SPACE
        dw 329, 335 : db 2, %00100000     ; SHIFT ...
        dw 330, 333 : db 6, %00010000     ; ... G  Γ
        dw 336, 339 : db 7, %00000100     ; E  ε
        dw 342, 345 : db 4, %00001000     ; I  ι
        dw 348, 351 : db 8, %00100000     ; A  α
        dw 354, 357 : db 5, %10000000     ; SPACE
        dw 360, 363 : db 3, %00010000     ; ;  tonos (dead)
        dw 365, 371 : db 2, %00100000     ; SHIFT ...
        dw 366, 369 : db 8, %00100000     ; ... A  Ά
        dw 600, 603 : db 0, %00100000     ; F3: English labels
        dw 700, 703 : db 1, %01000000     ; F2: mode 0
        dw 720, 735 : db 1, %00000001     ; LEFT
        dw 740, 743 : db 1, %00000010     ; COPY
        dw 800, 803 : db 0, %00100000     ; F3: Greek labels
        dw #FFFF
