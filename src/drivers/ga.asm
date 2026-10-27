; =====================================================================
; ga.asm - Gate Array: screen mode, palette, border
;
; Colours are given as the 27 firmware colour numbers (0 = black,
; 26 = bright white) and translated to Gate Array codes here.
; =====================================================================

; ---------------------------------------------------------------------
; ga_set_mode - A = 0, 1 or 2. Keeps both ROMs off.
; Destroys: A, BC
; ---------------------------------------------------------------------
ga_set_mode:
        and 3
        or GA_RMR + GA_RMR_LOROM_OFF + GA_RMR_HIROM_OFF
        ld bc,GA_PORT
        out (c),a
        ret

; ---------------------------------------------------------------------
; ga_set_ink - C = pen (0..15, or GA_BORDER), A = colour 0..26
; Destroys: A, B, HL
; ---------------------------------------------------------------------
ga_set_ink:
        ld hl,ga_colours
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld b,GA_PORT >> 8
        out (c),c                   ; select pen
        ld a,(hl)
        out (c),a                   ; colour code (already has GA_INK set)
        ret

; ---------------------------------------------------------------------
; ga_set_palette - HL = 17 colours: pens 0..15, then border
; Destroys: A, BC, DE, HL
; ---------------------------------------------------------------------
ga_set_palette:
        ld e,0
.loop:
        ld a,(hl)
        inc hl
        push hl
        ld c,e
        ld d,a
        ld a,e
        cp 16
        ld a,d
        jr c,.pen
        ld c,GA_BORDER
.pen:
        call ga_set_ink
        pop hl
        inc e
        ld a,e
        cp 17
        jr c,.loop
        ret

; firmware colour number -> Gate Array colour code
ga_colours:
        db #54,#44,#55,#5C,#58,#5D,#4C,#45,#4D
        db #56,#46,#57,#5E,#40,#5F,#4E,#47,#4F
        db #52,#42,#53,#5A,#59,#5B,#4A,#43,#4B
