; =====================================================================
; crtc.asm - CRTC 6845 register programming
; =====================================================================

; ---------------------------------------------------------------------
; crtc_load - HL = table of (register, value) pairs ending with #FF
; Destroys: A, BC, HL
; ---------------------------------------------------------------------
crtc_load:
        ld a,(hl)
        cp #FF
        ret z
        inc hl
        ld bc,CRTC_SELECT
        out (c),a
        ld a,(hl)
        inc hl
        ld b,CRTC_WRITE >> 8
        out (c),a
        jr crtc_load

; Standard 40x25 (mode 1) screen at #C000, 16K. Replaced by overscan in M1.
crtc_standard:
        db 0,63, 1,40, 2,46, 3,#8E, 4,38, 5,0, 6,25, 7,30, 8,0, 9,7
        db 12,#30, 13,#00
        db #FF
