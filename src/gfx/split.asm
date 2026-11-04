; =====================================================================
; split.asm - mixed screen: a mode 0 band between two mode 1 bands
;
; The interrupt switches the Gate Array to mode 0 at line split_y1 and
; back to mode 1 at split_y2, and sets pens 0..3 for each band (pens
; 4..15 are seen only in the mode 0 band). The mode is latched at HSYNC,
; so it is written during the line before the boundary.
;
; Interrupt n (1..5) arrives during physical line 27 + 52 * (n - 1),
; interrupt 0 (VSYNC) 55 lines before interrupt 1: the Gate Array
; restarts its count early in VSYNC (measured in Caprice32, as the
; others). A boundary at another
; line waits there, 64 us a line: none at y = 22, 74, 126, 178, 230,
; 45 lines (14% of the time) at y = 12, below a menu bar.
;
; While the split is on the pointer's x is in mode 1 pixels; events
; give it in pixels of the band the pointer is in.
;
; Drawing follows gfx_set_mode (VOS_MODE), which no longer touches the
; Gate Array while the split is on: a program draws each band in its
; mode. The pointer is drawn in the mode of the line it is on.
; =====================================================================

SPLIT_LINE0     equ 28              ; physical line after interrupt 1
SPLIT_LINES     equ 52
SPLIT_LINES0    equ 55                ; interrupt 0 to interrupt 1

; ---------------------------------------------------------------------
; split_off - one mode on the whole screen again (a program ends)
; Destroys: AF, BC
; ---------------------------------------------------------------------
split_off:
        xor a
        ld (int_input),a
        ld hl,split_on
        ld a,(hl)
        ld (hl),0
        or a
        ld a,(gfx_mode)
        jp z,ga_set_mode
        or a                        ; the pointer's x in mode 0 pixels
        jr nz,.mode1
        di
        ld hl,(ptr_x)
        srl h
        rr l
        ld (ptr_x),hl
        ei
.mode1:
        jp ga_set_mode

; the pointer's x from mode 0 to mode 1 pixels, if it is in mode 0
; Destroys: AF, HL
ptr_to_mode1:
        ld a,(gfx_mode)
        or a
        ret nz
        di
        ld hl,(ptr_x)
        add hl,hl
        ld (ptr_x),hl
        ei
        ret

; ---------------------------------------------------------------------
; ptr_ev_x - DE = the pointer's x in pixels of the band it is in
; (events, interrupt context). Destroys: AF
; ---------------------------------------------------------------------
ptr_ev_x:
        ld de,(ptr_x)
        ld a,(split_on)
        or a
        ret z
        push hl
        push de
        ld hl,(ptr_y)
        call split_mode
        pop de
        pop hl
        or a
        ret nz
        srl d
        rr e
        ret

; ---------------------------------------------------------------------
; ptr_width - DE = the width the pointer moves in (interrupt context)
; ---------------------------------------------------------------------
ptr_width:
        ld de,384
        ld a,(split_on)
        or a
        ret nz
        ld de,(gfx_width)
        ret

; ---------------------------------------------------------------------
; split_mode - HL = line -> A = the mode it is shown in
; Destroys: DE, HL
; ---------------------------------------------------------------------
split_mode:
        ld a,(split_on)
        or a
        ld a,(gfx_mode)
        ret z
        ld de,(split_y1)
        or a
        sbc hl,de
        ld a,1
        ret c                       ; above the mode 0 band
        add hl,de
        ld de,(split_y2)
        or a
        sbc hl,de
        ccf
        sbc a,a                     ; 0 in the band, 1 below it
        and 1
        ret

; ---------------------------------------------------------------------
; split_irq - interrupt, first thing once the slice is known: A = slice.
; The boundaries, then: VSYNC now, after another slice? Then the slices
; were counted wrong (a VSYNC interrupt taken late, after a disc
; transfer or a long wait here), and the next interrupt is slice 0.
; Without this a wait of 45 lines in the slice before VSYNC kept every
; VSYNC interrupt late, and the bands wrong for good.
; Destroys: AF, BC, DE, HL
; ---------------------------------------------------------------------
split_irq:
        call split_tick
        ld a,(int_slice)
        or a
        ret z
        ld b,PPI_B >> 8
        in a,(c)
        rra                         ; carry = VSYNC
        ret nc
        ld a,5
        ld (int_slice),a
        ret

; split_tick - A = slice: the mode and pens at the boundaries in it
; Destroys: AF, BC, DE, HL
split_tick:
        ld e,0                      ; lines waited in this slice
        ld hl,split_s1
        cp (hl)
        jr nz,.second
        push af
        inc hl
        ld b,(hl)
        call split_wait
        xor a
        ld hl,split_mid
        call split_out
        pop af
.second:
        ld hl,split_s2
        cp (hl)
        ret nz
        inc hl
        ld a,(hl)
        sub e
        ld b,a
        call split_wait
        ld a,1
        ld hl,split_band
        ; fall through
; A = mode, HL -> Gate Array codes for pens 0..3
split_out:
        or GA_RMR + GA_RMR_LOROM_OFF + GA_RMR_HIROM_OFF
        ld bc,GA_PORT
        out (c),a
        xor a
.pen:
        out (c),a                   ; select the pen
        ld d,(hl)
        out (c),d
        inc hl
        inc a
        cp 4
        jr c,.pen
        ret

; wait B lines (64 us each); E += B
split_wait:
        ld a,b
        or a
        ret z
        add a,e
        ld e,a
.line:
        ld a,14                     ; 2 + 55 + 3 + 4 = 64 us
.delay:
        dec a
        jr nz,.delay
        nop
        nop
        nop
        djnz .line
        ret

; ---- state ----------------------------------------------------------
split_on:       db 0
split_y1:       dw 0
split_y2:       dw 0
split_s1:       db 0                ; interrupt of the first boundary
split_d1:       db 0                ; and the lines after it
split_s2:       db 0
split_d2:       db 0
split_band:     ds 4                ; pens 0..3, mode 1 bands
split_mid:      ds 4                ; pens 0..3, mode 0 band
