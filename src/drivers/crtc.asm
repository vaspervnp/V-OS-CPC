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

; Overscan 48x34 characters (384x272 in mode 1), 32K screen at #8000.
;
; R12/R13 = #2C10: page bits MA13-12 = %10 (#8000), MA11-10 = %11 so the
; carry out of MA9 ripples into MA12 and the screen continues at #C000.
; The start offset of 16 words makes that carry land exactly between
; character rows 20 and 21, so no pixel line is split across the pages:
;   rows  0..20  #8020 + row*96          (+ line*#800)
;   rows 21..33  #C000 + (row-21)*96     (+ line*#800)
crtc_overscan:
        db 0,63, 1,48, 2,50, 3,#8E, 4,38, 5,0, 6,34, 7,35, 8,0, 9,7
        db 12,#2C, 13,#10
        db #FF
