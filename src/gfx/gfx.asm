; =====================================================================
; gfx.asm - overscan screen, mode-aware plot / rectangle / text
;
; Coordinates: x in pixels of the current mode (0..383 in mode 1,
; 0..191 in mode 0), y in pixel lines 0..271. Pens are 0..3 (mode 1)
; or 0..15 (mode 0); higher pens wrap.
;
; Byte layout (bit 7 = left):
;   mode 1, 4 pixels: pixel p has pen bit 0 at bit 7-p, pen bit 1 at 3-p
;   mode 0, 2 pixels: left pixel bits 7,3,5,1 / right pixel 6,2,4,0
;                     for pen bits 0,1,2,3
; =====================================================================

; ---------------------------------------------------------------------
; gfx_init - program the overscan CRTC and build the line table
; Destroys: all
; ---------------------------------------------------------------------
gfx_init:
        ld hl,crtc_overscan
        call crtc_load
        ; gfx_lines[y] = address of pixel line y
        ld ix,gfx_lines
        ld hl,SCREEN_TOP
        ld c,0                      ; char row
.row:
        push hl
        ld b,8
.line:
        ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        ld a,h
        add a,#08                   ; next pixel line: +#800
        ld h,a
        djnz .line
        pop hl
        inc c
        ld a,c
        cp SCREEN_SPLIT
        jr nz,.same_page
        ld hl,SCREEN_LOW
        jr .next
.same_page:
        ld de,SCREEN_BPL
        add hl,de
.next:
        cp SCREEN_ROWS
        jr c,.row
        ret

; ---------------------------------------------------------------------
; gfx_set_mode - A = 0 or 1. Sets the Gate Array mode, the pixel
; tables, and rebuilds the text colour table.
; Destroys: all
; ---------------------------------------------------------------------
gfx_set_mode:
        ld (gfx_mode),a
        push af
        call ga_set_mode
        pop af
        ld hl,gfx_mode0
        or a
        jr z,.copy
        ld hl,gfx_mode1
.copy:
        ld de,gfx_params
        ld bc,GFX_PARAMS_SIZE
        ldir
        ld a,(txt_bg)
        ld c,a
        ld a,(txt_fg)
        jp txt_set_colours

; ---------------------------------------------------------------------
; gfx_pen_byte - A = pen -> A = byte with every pixel set to that pen
; Destroys: HL
; ---------------------------------------------------------------------
gfx_pen_byte:
        ld hl,gfx_penmask
        and (hl)
        ld hl,(gfx_fill)
        ; fall through
; ---------------------------------------------------------------------
; tbl_a - A = (HL + A)
; Destroys: HL
; ---------------------------------------------------------------------
tbl_a:
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ret

; ---------------------------------------------------------------------
; gfx_x_to_byte - HL = x -> HL = byte offset in the line
; Destroys: A
; ---------------------------------------------------------------------
gfx_x_to_byte:
        ld a,(gfx_shift)
.shift:
        srl h
        rr l
        dec a
        jr nz,.shift
        ret

; ---------------------------------------------------------------------
; gfx_plot - HL = x, DE = y, A = pen. Points off screen are ignored.
; Destroys: all
; ---------------------------------------------------------------------
gfx_plot:
        ld (gfx_tmp_pen),a
        ld (gfx_tmp_x),hl
        ld hl,SCREEN_H - 1
        or a
        sbc hl,de                   ; carry if y > 271
        ret c
        ld hl,(gfx_width)
        ld bc,(gfx_tmp_x)
        scf
        sbc hl,bc                   ; carry if x >= width
        ret c
        ex de,hl                    ; line address
        add hl,hl
        ld de,gfx_lines
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(gfx_tmp_x)
        call gfx_x_to_byte
        add hl,de
        push hl
        ld a,(gfx_tmp_x)            ; pixel mask
        ld hl,gfx_pmask
        and (hl)
        ld hl,(gfx_pix)
        call tbl_a
        ld c,a
        ld a,(gfx_tmp_pen)
        call gfx_pen_byte
        and c
        ld b,a                      ; new pixel bits
        ld a,c
        cpl
        ld c,a                      ; bits to keep
        pop hl
        ld a,(hl)
        and c
        or b
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; gfx_fill_rect - IX = rectangle: dw x, y, w, h; db pen
; The rectangle must be on screen with w, h > 0 (no clipping yet).
; Destroys: all except IX
; ---------------------------------------------------------------------
gfx_fill_rect:
        ld a,(ix+8)
        call gfx_pen_byte
        ld (fr_fill),a
        ; left edge: first byte and the mask from the first pixel on
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,l
        push hl
        ld hl,gfx_pmask
        and (hl)
        ld hl,(gfx_lmask)
        call tbl_a
        ld (fr_lmask),a
        pop hl
        call gfx_x_to_byte
        ld (fr_first),hl
        ; right edge: last byte and the mask up to the last pixel
        ld l,(ix+0)
        ld h,(ix+1)
        ld e,(ix+4)
        ld d,(ix+5)
        add hl,de
        dec hl
        ld a,l
        push hl
        ld hl,gfx_pmask
        and (hl)
        ld hl,(gfx_rmask)
        call tbl_a
        ld (fr_rmask),a
        pop hl
        call gfx_x_to_byte
        ld de,(fr_first)
        or a
        sbc hl,de                   ; bytes after the first one
        ld a,l
        ld (fr_span),a
        or a
        jr nz,.rows
        ld a,(fr_lmask)             ; one byte wide: both edges in it
        ld hl,fr_rmask
        and (hl)
        ld (fr_lmask),a
.rows:
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,hl
        ld de,gfx_lines
        add hl,de                   ; HL -> gfx_lines[y]
        ld c,(ix+6)
        ld b,(ix+7)                 ; BC = rows
.row:
        push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(fr_first)
        add hl,de
        ld a,(fr_lmask)
        call .masked
        ld a,(fr_span)
        or a
        jr z,.row_done
        dec a
        jr z,.right
        ld b,a
        ld a,(fr_fill)
.middle:
        inc hl
        ld (hl),a
        djnz .middle
.right:
        inc hl
        ld a,(fr_rmask)
        call .masked
.row_done:
        pop hl
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.row
        ret
; (HL) = (HL) with the pixels in mask A set to the fill pen
.masked:
        ld d,a
        ld a,(fr_fill)
        and d
        ld e,a
        ld a,d
        cpl
        and (hl)
        or e
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; gfx_cls - A = pen. Fills the visible screen (not the free gaps).
; Destroys: all except IX
; ---------------------------------------------------------------------
gfx_cls:
        push ix
        ld (gfx_cls_rect + 8),a
        ld hl,(gfx_width)
        ld (gfx_cls_rect + 4),hl
        ld ix,gfx_cls_rect
        call gfx_fill_rect
        pop ix
        ret

; ---------------------------------------------------------------------
; txt_set_colours - A = foreground pen, C = background pen
; Builds txt_expand: for each 4-bit (mode 1) or 2-bit (mode 0) group of
; font pixels, the screen byte that draws it.
; Destroys: all
; ---------------------------------------------------------------------
txt_set_colours:
        ld (txt_fg),a
        ld a,c
        ld (txt_bg),a
        call gfx_pen_byte
        ld (txt_bg_byte),a
        ld a,(txt_fg)
        call gfx_pen_byte
        ld (txt_fg_byte),a
        ld de,txt_expand
        ld c,0                      ; pixel group value
.entry:
        push de
        ; mask of the pixels whose bit is set; the lowest bit is the
        ; rightmost pixel of the byte
        ld a,(gfx_pmask)
        ld e,a
        ld d,0
        ld hl,(gfx_pix)
        add hl,de                   ; HL -> mask of the rightmost pixel
        ld b,e
        inc b                       ; pixels per byte
        ld e,c
.pixel:
        srl e
        jr nc,.clear
        ld a,d
        or (hl)
        ld d,a
.clear:
        dec hl
        djnz .pixel
        ld a,(txt_fg_byte)
        and d
        ld e,a
        ld a,d
        cpl
        ld d,a
        ld a,(txt_bg_byte)
        and d
        or e
        pop de
        ld (de),a
        inc de
        inc c
        ld a,c
        cp 16
        jr c,.entry
        ret

; ---------------------------------------------------------------------
; txt_char - HL = x (multiple of 4 in mode 1, of 2 in mode 0),
; DE = y, A = character. Draws an opaque 8x8 cell in txt_fg/txt_bg.
; Codes outside 32..127 draw as '?'.
; Destroys: all
; ---------------------------------------------------------------------
txt_char:
        sub 32
        cp 96
        jr c,.code_ok
        ld a,'?' - 32
.code_ok:
        push de
        ex de,hl                    ; DE = x
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,font_ascii
        add hl,bc
        ld (txt_glyph),hl
        ex de,hl                    ; HL = x
        call gfx_x_to_byte
        ld (txt_col),hl
        pop hl                      ; HL = y
        add hl,hl
        ld de,gfx_lines
        add hl,de
        ld b,8
.row:
        push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(txt_col)
        add hl,de
        ex de,hl                    ; DE = screen byte
        ld hl,(txt_glyph)
        ld c,(hl)
        inc hl
        ld (txt_glyph),hl
        ld a,(gfx_mode)
        or a
        jr z,.mode0
        ld a,c                      ; mode 1: two nibbles
        rrca
        rrca
        rrca
        rrca
        and 15
        call .emit
        ld a,c
        and 15
        call .emit
        jr .row_done
.mode0:
        ld b,4                      ; mode 0: four pairs, left first
.pair:
        rlc c
        rlc c
        ld a,c
        and 3
        call .emit
        djnz .pair
.row_done:
        pop hl
        pop bc
        djnz .row
        ret
; (DE++) = txt_expand[A]
.emit:
        ld hl,txt_expand
        call tbl_a
        ld (de),a
        inc de
        ret

; ---------------------------------------------------------------------
; txt_print - HL = x, DE = y, BC = zero-terminated string.
; Returns BC -> the terminating zero.
; Destroys: all
; ---------------------------------------------------------------------
txt_print:
        ld a,(bc)
        or a
        ret z
        push bc
        push de
        push hl
        call txt_char
        pop hl
        pop de
        pop bc
        inc bc
        ld a,8
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        jr txt_print

; ---- per-mode parameters ---------------------------------------------
; copied into gfx_params by gfx_set_mode; field order must match
gfx_mode1:
        db 2, 3, 3                  ; shift, pixel mask, pen mask
        dw 384                      ; width
        dw gfx_pix1, gfx_lmask1, gfx_rmask1, gfx_fill1
gfx_mode0:
        db 1, 1, 15
        dw 192
        dw gfx_pix0, gfx_lmask0, gfx_rmask0, gfx_fill0
GFX_PARAMS_SIZE equ $ - gfx_mode0

gfx_pix1:   db #88, #44, #22, #11   ; one pixel
gfx_lmask1: db #FF, #77, #33, #11   ; this pixel and those to its right
gfx_rmask1: db #88, #CC, #EE, #FF   ; this pixel and those to its left
gfx_fill1:  db #00, #F0, #0F, #FF   ; pen -> all four pixels

gfx_pix0:   db #AA, #55
gfx_lmask0: db #FF, #55
gfx_rmask0: db #AA, #FF
gfx_fill0:  db #00, #C0, #0C, #CC, #30, #F0, #3C, #FC
            db #03, #C3, #0F, #CF, #33, #F3, #3F, #FF

; ---- state ----------------------------------------------------------
gfx_mode:   db 1
gfx_params:
gfx_shift:  db 2
gfx_pmask:  db 3
gfx_penmask: db 3
gfx_width:  dw 384
gfx_pix:    dw gfx_pix1
gfx_lmask:  dw gfx_lmask1
gfx_rmask:  dw gfx_rmask1
gfx_fill:   dw gfx_fill1

gfx_cls_rect: dw 0, 0, 384, SCREEN_H
            db 0

gfx_tmp_x:  dw 0
gfx_tmp_pen: db 0
fr_first:   dw 0
fr_span:    db 0
fr_fill:    db 0
fr_lmask:   db 0
fr_rmask:   db 0

txt_fg:     db 1
txt_bg:     db 0
txt_fg_byte: db 0
txt_bg_byte: db 0
txt_glyph:  dw 0
txt_col:    dw 0
txt_expand: ds 16

gfx_lines:  ds SCREEN_H * 2
