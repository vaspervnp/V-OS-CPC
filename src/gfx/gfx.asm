; =====================================================================
; gfx.asm - overscan screen, mode-aware plot / rectangle / text
;
; Coordinates: x in pixels of the current mode (0..383 in mode 1,
; 0..191 in mode 0), y in drawable lines 0..GFX_H-1 (physical line
; GFX_TOP + y, see memmap.inc). Pens are 0..3 (mode 1)
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
        ; gfx_lines_all[line] = address of physical pixel line
        ld ix,gfx_lines_all
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
        ld hl,split_on              ; mixed screen: the interrupt sets it
        inc (hl)
        dec (hl)
        call z,ga_set_mode
        pop af
        call gfx_params_for
        ld a,(txt_bg)
        ld c,a
        ld a,(txt_fg)
        jp txt_set_colours

; gfx_params_for - A = 0 or 1: the pixel tables of that mode, without
; the text colours (pointer.asm). Destroys: BC, DE, HL
gfx_params_for:
        ld hl,gfx_mode0
        or a
        jr z,.copy
        ld hl,gfx_mode1
.copy:
        ld de,gfx_params
        ld bc,GFX_PARAMS_SIZE
        ldir
        ret

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
        push de
        ld bc,1
        ld a,1
        call ptr_guard
        pop de
        ld hl,(gfx_tmp_x)
        ld hl,GFX_H - 1
        or a
        sbc hl,de                   ; carry if y is below the drawable area
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
        ld l,(ix+0)                 ; keep the pointer out of the way
        ld h,(ix+1)
        ld e,(ix+2)
        ld d,(ix+3)
        ld c,(ix+4)
        ld b,(ix+5)
        ld a,(ix+7)
        or a
        ld a,(ix+6)
        jr z,.guard
        ld a,255
.guard:
        call ptr_guard
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
; gfx_blit (VOS_BLIT) - IX = image: dw x, y; db bytes, rows; dw source;
; db source stride. Per row the source has (mask, pixels) byte pairs;
; screen = screen and not mask, or pixels. x is rounded down to a byte.
; The image must be on screen, bytes and rows > 0 (no clipping).
; Destroys: all except IX
; ---------------------------------------------------------------------
gfx_blit:
        ld l,(ix+4)                 ; keep the pointer out of the way
        ld h,0
        ld a,(gfx_shift)
.pixels:
        add hl,hl
        dec a
        jr nz,.pixels
        ld b,h
        ld c,l
        ld l,(ix+0)
        ld h,(ix+1)
        ld e,(ix+2)
        ld d,(ix+3)
        ld a,(ix+5)
        call ptr_guard
        ld l,(ix+0)
        ld h,(ix+1)
        call gfx_x_to_byte
        ld (fr_first),hl
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,hl
        ld de,gfx_lines
        add hl,de                   ; HL -> gfx_lines[y]
        ld e,(ix+6)
        ld d,(ix+7)                 ; DE -> source row
        ld b,(ix+5)
.row:
        push bc
        push de
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld hl,(fr_first)
        add hl,bc
        ld b,(ix+4)
.byte:
        ld a,(de)                   ; mask
        cpl
        and (hl)
        ld c,a
        inc de
        ld a,(de)                   ; pixels
        or c
        ld (hl),a
        inc de
        inc hl
        djnz .byte
        pop hl
        pop de
        ld a,(ix+8)                 ; next source row
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        pop bc
        djnz .row
        ret

; ---------------------------------------------------------------------
; gfx_cls - A = pen. Fills all 272 lines, margins included (not the
; free RAM gaps).
; Destroys: all except IX
; ---------------------------------------------------------------------
gfx_cls:
        push ix
        ld (gfx_cls_rect + 8),a
        ld hl,(gfx_width)
        ld (gfx_cls_rect + 4),hl
        ld ix,gfx_cls_rect
        call gfx_fill_rect
        ld a,(split_on)             ; mixed screen: the unused lines above
        or a                        ; and below are in mode 1, give them
        jr z,.done                  ; pen 0, the same in both modes
        xor a
        ld (ix+8),a                 ; the rectangle: dw x, y, w, h; db pen
        ld (ix+7),a
        ld (ix+6),SCREEN_H - GFX_TOP - GFX_H
        ld (ix+3),a
        ld (ix+2),GFX_H
        call gfx_fill_rect
        ld (ix+6),GFX_TOP
        ld (ix+3),#FF
        ld (ix+2),(-GFX_TOP) & #FF
        call gfx_fill_rect
        ld (ix+7),SCREEN_H >> 8     ; as it was
        ld (ix+6),SCREEN_H & #FF
.done:
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
; 32..127 use the kernel font, 128..255 the language pack's font;
; anything else (or 128..255 without a pack) draws as '?'.
; Destroys: all
; ---------------------------------------------------------------------
txt_char:
        push ix
        push af
        push de
        push hl
        ld bc,8
        ld a,8
        call ptr_guard
        pop hl
        pop de
        pop af
        push de                     ; y
        push hl                     ; x
        call txt_glyph
        ld b,h
        ld c,l                      ; BC = glyph row
        pop hl
        call gfx_x_to_byte
        ld (txt_col),hl
        pop hl
        add hl,hl
        ld de,gfx_lines
        add hl,de
        push hl
        pop ix                      ; IX -> line addresses
        ld a,(gfx_mode)
        or a
        ld a,8
        jr z,.row0
.row1:                              ; mode 1: two nibbles per row
        ld (txt_rows),a
        ld l,(ix+0)
        ld h,(ix+1)
        inc ix
        inc ix
        ld de,(txt_col)
        add hl,de
        ex de,hl                    ; DE = screen
        ld h,txt_expand >> 8        ; txt_expand is page aligned
        ld a,(bc)
        inc bc
        ld (txt_bits),a
        rrca
        rrca
        rrca
        rrca
        and 15
        ld l,a
        ld a,(hl)
        ld (de),a
        inc de
        ld a,(txt_bits)
        and 15
        ld l,a
        ld a,(hl)
        ld (de),a
        ld a,(txt_rows)
        dec a
        jr nz,.row1
        pop ix
        ret
.row0:                              ; mode 0: four pairs per row
        ld (txt_rows),a
        ld l,(ix+0)
        ld h,(ix+1)
        inc ix
        inc ix
        ld de,(txt_col)
        add hl,de
        ex de,hl
        ld h,txt_expand >> 8
        ld a,(bc)
        inc bc
        ld (txt_bits),a
        rlca                        ; bits 7-6
        rlca
        and 3
        ld l,a
        ld a,(hl)
        ld (de),a
        inc de
        ld a,(txt_bits)             ; bits 5-4
        rrca
        rrca
        rrca
        rrca
        and 3
        ld l,a
        ld a,(hl)
        ld (de),a
        inc de
        ld a,(txt_bits)             ; bits 3-2
        rrca
        rrca
        and 3
        ld l,a
        ld a,(hl)
        ld (de),a
        inc de
        ld a,(txt_bits)             ; bits 1-0
        and 3
        ld l,a
        ld a,(hl)
        ld (de),a
        ld a,(txt_rows)
        dec a
        jr nz,.row0
        pop ix
        ret

; ---------------------------------------------------------------------
; txt_glyph - A = character -> HL = its 8 glyph bytes
; Destroys: AF, DE
; ---------------------------------------------------------------------
txt_glyph:
        cp 128
        jr nc,.pack
        sub 32
        jr nc,.kernel
.unknown:
        ld a,'?' - 32
.kernel:
        ld de,font_ascii
        jr .address
.pack:
        ld e,a
        ld a,(lang_loaded)
        or a
        jr z,.unknown
        ld a,e
        sub 128
        ld de,lang_font_lo
        cp 64
        jr c,.address
        sub 64
        ld de,lang_font_hi
.address:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ret

; ---------------------------------------------------------------------
; txt_print - HL = x, DE = y, BC = zero-terminated string. Characters
; that would cross the right edge are not drawn.
; Returns BC -> the terminating zero (or the first undrawn character).
; Destroys: all
; ---------------------------------------------------------------------
txt_print:
        ld a,(bc)
        or a
        ret z
        push hl                     ; stop at the right edge
        push de
        ld de,8
        add hl,de
        ld de,(gfx_width)
        ex de,hl
        or a
        sbc hl,de
        pop de
        pop hl
        ret c
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

gfx_cls_rect: dw 0, -GFX_TOP, 384, SCREEN_H     ; y relative to gfx_lines
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
txt_col:    dw 0
txt_rows:   db 0
txt_bits:   db 0

            align 256
txt_expand: ds 16                   ; page aligned, see txt_char
gfx_lines_all: ds SCREEN_H * 2
gfx_lines   equ gfx_lines_all + GFX_TOP * 2  ; drawable line 0
