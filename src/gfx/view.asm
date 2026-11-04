; =====================================================================
; view.asm - a program's view (VX_VIEW, API 33), in the second extension
; (kernel/ext2.asm): an origin added to what it draws, and a clip
; rectangle nothing is drawn outside of (docs/WINDOWS.md). The kernel's
; api_cls, api_plot, api_rect, api_char, api_print and api_blit (kernel/
; api.asm) come here only while a view is set (vw_on); they copy their
; arguments into vw_a, vw_x, vw_y and vw_buf first, as the program's
; memory is not mapped here.
;   VOS_CLS     fills the clip
;   VOS_PLOT    a point inside it
;   VOS_RECT    cut to it
;   VOS_CHAR    drawn if all its 8 x 8 cell is inside (VOS_PRINT: each)
;   VOS_BLIT    drawn if all of it is inside
; The clip is in pixels of the mode it was set in: set it again after
; VOS_MODE.
; =====================================================================

; VX_VIEW: vw_a = 0: no view; else vw_buf = dw x, y, w, h: the origin at
; (x, y), the clip that rectangle, cut to the screen
vw_set:
        ld a,(vw_a)
        ld (vw_on),a
        or a
        ret z
        ld hl,(vw_buf)
        ld (vw_ox),hl
        ld (vw_x0),hl
        ld de,(vw_buf + 4)
        add hl,de
        ld de,(gfx_width)
        call vw_min
        ld (vw_x1),hl
        ld hl,(vw_buf + 2)
        ld (vw_oy),hl
        ld (vw_y0),hl
        ld de,(vw_buf + 6)
        add hl,de
        ld de,GFX_H
        call vw_min
        ld (vw_y1),hl
        or a
        ret

; HL = the smaller of HL and DE
vw_min:
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

; VOS_CLS: vw_a = pen, the whole clip
vw_cls:
        ld hl,0
        ld (vw_buf),hl
        ld (vw_buf + 2),hl
        ld hl,#4000                 ; (cut to the clip)
        ld (vw_buf + 4),hl
        ld (vw_buf + 6),hl
        ld a,(vw_a)
        ld (vw_buf + 8),a
        ; fall through
; VOS_RECT: vw_buf = dw x, y, w, h; db pen, moved by the origin and cut
; to the clip
vw_rect:
        push ix
        push iy
        ld ix,vw_buf
        ld iy,vw_ox
        call vw_axis
        jr c,.none
        ld ix,vw_buf + 2
        ld iy,vw_oy
        call vw_axis
        jr c,.none
        ld ix,vw_buf
        call gfx_fill_rect
.none:
        pop iy
        pop ix
        ret

; IX -> dw start; 2 bytes on, dw length; IY -> dw origin, low, high (x
; or y): the start moved by the origin, start and length cut to low ..
; high. Carry: nothing is left
vw_axis:
        ld l,(ix + 0)
        ld h,(ix + 1)
        ld e,(iy + 0)
        ld d,(iy + 1)
        add hl,de                   ; HL = start
        ld e,(ix + 4)
        ld d,(ix + 5)
        ex de,hl
        add hl,de                   ; HL = end, DE = start
        ld c,(iy + 4)
        ld b,(iy + 5)
        push hl
        or a
        sbc hl,bc
        pop hl
        jr c,.end
        ld h,b                      ; past high: high
        ld l,c
.end:
        ex de,hl                    ; HL = start, DE = end
        ld c,(iy + 2)
        ld b,(iy + 3)
        push hl
        or a
        sbc hl,bc
        pop hl
        jr nc,.start
        ld h,b                      ; before low: low
        ld l,c
.start:
        ld (ix + 0),l
        ld (ix + 1),h
        ex de,hl
        or a
        sbc hl,de                   ; length = end - start
        jr c,.empty
        jr z,.empty
        ld (ix + 4),l
        ld (ix + 5),h
        or a
        ret
.empty:
        scf
        ret

; VOS_PLOT: vw_x, vw_y, pen vw_a
vw_plot:
        call vw_xy
        ld bc,1
        ld a,c
        call vw_inside
        ret c
        ld a,(vw_a)
        jp gfx_plot

; VOS_CHAR: vw_x, vw_y, character vw_a
vw_char:
        call vw_xy
        ld bc,8
        ld a,c
        call vw_inside
        ret c
        ld a,(vw_a)
        jp txt_char

; VOS_BLIT: vw_buf = dw x, y; db bytes, rows; dw source; db stride ->
; carry: not all inside the clip, else x, y moved by the origin (the
; kernel draws it, from the program's memory)
vw_blit:
        ld hl,(vw_buf)
        ld (vw_x),hl
        ld hl,(vw_buf + 2)
        ld (vw_y),hl
        call vw_xy
        push hl
        ld a,(vw_buf + 4)           ; bytes -> pixels
        ld l,a
        ld h,0
        ld a,(gfx_shift)
.pixels:
        add hl,hl
        dec a
        jr nz,.pixels
        ld b,h
        ld c,l
        pop hl
        ld a,(vw_buf + 5)
        call vw_inside
        ret c
        ld (vw_buf),hl
        ld (vw_buf + 2),de
        ret

; vw_x, vw_y -> HL, DE moved by the origin
vw_xy:
        ld hl,(vw_y)
        ld de,(vw_oy)
        add hl,de
        ex de,hl
        ld hl,(vw_x)
        ld bc,(vw_ox)
        add hl,bc
        ret

; HL = x, DE = y, BC = width, A = height -> carry unless all of it is
; inside the clip. Keeps HL, DE
vw_inside:
        ld (vw_tx),hl
        ld (vw_ty),de
        ld (vw_h),a
        add hl,bc                   ; x1 >= x + width
        ex de,hl
        ld hl,(vw_x1)
        or a
        sbc hl,de
        jr c,.out
        ld hl,(vw_tx)               ; x >= x0
        ld de,(vw_x0)
        sbc hl,de
        jr c,.out
        ld hl,(vw_ty)               ; y >= y0
        ld de,(vw_y0)
        sbc hl,de
        jr c,.out
        ld hl,(vw_ty)               ; y1 >= y + height
        ld a,(vw_h)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld hl,(vw_y1)
        or a
        sbc hl,de
.out:
        ld hl,(vw_tx)
        ld de,(vw_ty)
        ret
