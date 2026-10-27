; =====================================================================
; pointer.asm - software mouse pointer with save-under
;
; Main context only. Anything that draws under the pointer must call
; ptr_hide first and ptr_show after. ptr_update, once per frame, moves
; the pointer when ptr_poll has changed its position. The hot spot is
; the top-left pixel. The 8x13 arrow is clipped at the right and
; bottom edges of the drawable area.
; =====================================================================

PTR_W           equ 8
PTR_H           equ 13

; ---------------------------------------------------------------------
; ptr_show / ptr_hide / ptr_update
; Destroys: all except IX
; ---------------------------------------------------------------------
ptr_show:
        ld a,(ptr_visible)
        or a
        ret nz
        inc a
        ld (ptr_visible),a
        jr ptr_place

ptr_hide:
        ld a,(ptr_visible)
        or a
        ret z
        xor a
        ld (ptr_visible),a
        jp ptr_restore

ptr_update:
        ld a,(ptr_visible)
        or a
        ret z
        ld a,(ptr_moved)
        or a
        ret z
        call ptr_restore
        ; fall through
ptr_place:
        xor a
        ld (ptr_moved),a
        di
        ld hl,(ptr_x)
        ld (pd_x),hl
        ld hl,(ptr_y)
        ld (pd_y),hl
        ei
        call ptr_geometry
        call ptr_save
        jp ptr_draw

; size of the covered area, clipped to the drawable area
ptr_geometry:
        ld hl,(pd_x)
        call gfx_x_to_byte
        ld (pd_col),hl
        ld a,(pd_x)                 ; bytes = ((x & pmask) + 7) >> shift + 1
        ld hl,gfx_pmask
        and (hl)
        add a,PTR_W - 1
        ld l,a
        ld h,0
        call gfx_x_to_byte
        ld a,l
        inc a
        ld b,a
        ld a,(pd_col)
        ld c,a
        ld a,SCREEN_BPL
        sub c                       ; bytes left in the line
        cp b
        jr nc,.bytes_ok
        ld b,a
.bytes_ok:
        ld a,b
        ld (pd_bytes),a
        ld hl,GFX_H                 ; rows = min(PTR_H, GFX_H - y)
        ld de,(pd_y)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.rows_full
        ld a,l
        cp PTR_H
        jr c,.rows_ok
.rows_full:
        ld a,PTR_H
.rows_ok:
        ld (pd_rows),a
        ld hl,(gfx_width)           ; columns = min(PTR_W, width - x)
        ld de,(pd_x)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.cols_full
        ld a,l
        cp PTR_W
        jr c,.cols_ok
.cols_full:
        ld a,PTR_W
.cols_ok:
        ld (pd_cols),a
        ret

; copy the covered bytes screen -> ptr_buf (save) or back (restore)
ptr_save:
        xor a
        jr ptr_copy
ptr_restore:
        ld a,1
ptr_copy:
        ld (pc_dir),a
        ld hl,(pd_y)
        add hl,hl
        ld de,gfx_lines
        add hl,de
        ld (pc_line),hl
        ld hl,ptr_buf
        ld (pc_buf),hl
        ld a,(pd_rows)
        ld b,a
.row:
        push bc
        ld hl,(pc_line)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pc_line),hl
        ld hl,(pd_col)
        add hl,de                   ; HL = screen
        ld de,(pc_buf)
        ld a,(pd_bytes)
        ld c,a
        ld b,0
        ld a,(pc_dir)
        or a
        jr z,.to_buf
        ex de,hl                    ; restore: buffer -> screen
        ldir
        ld (pc_buf),hl
        jr .next
.to_buf:
        ldir
        ld (pc_buf),de
.next:
        pop bc
        djnz .row
        ret

; draw the arrow at pd_x, pd_y
ptr_draw:
        ld a,(ptr_pen_out)
        call gfx_pen_byte
        ld (pd_out),a
        ld a,(ptr_pen_fill)
        call gfx_pen_byte
        ld (pd_fill),a
        ld hl,(pd_y)
        add hl,hl
        ld de,gfx_lines
        add hl,de
        ld (pc_line),hl
        ld hl,ptr_shape
        ld (pc_buf),hl
        ld a,(pd_rows)
.row:
        ld (pc_rows),a
        ld hl,(pc_buf)
        ld d,(hl)                   ; outline bits, bit 7 = column 0
        inc hl
        ld e,(hl)                   ; fill bits
        inc hl
        ld (pc_buf),hl
        ld hl,(pc_line)
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (pc_line),hl
        ld hl,(pd_col)
        add hl,bc                   ; HL = first screen byte
        ld a,(pd_x)
        push hl
        ld hl,gfx_pmask
        and (hl)
        pop hl
        ld c,a                      ; pixel within the byte
        ld a,(pd_cols)
        ld b,a
.col:
        bit 7,d
        jr nz,.outline
        bit 7,e
        jr z,.advance
        ld a,(pd_fill)
        jr .put
.outline:
        ld a,(pd_out)
.put:
        push de
        push hl
        ld d,a
        ld hl,(gfx_pix)
        ld a,c
        call tbl_a                  ; A = pixel mask
        pop hl
        ld e,a
        and d
        ld d,a
        ld a,e
        cpl
        and (hl)
        or d
        ld (hl),a
        pop de
.advance:
        sla d
        sla e
        inc c
        ld a,(gfx_pmask)
        cp c
        jr nc,.same_byte
        ld c,0
        inc hl
.same_byte:
        djnz .col
        ld a,(pc_rows)
        dec a
        jr nz,.row
        ret

; arrow: (outline, fill) per row, bit 7 = leftmost pixel
ptr_shape:
        db #80,#00, #C0,#00, #A0,#40, #90,#60, #88,#70, #84,#78, #82,#7C
        db #81,#7E, #8F,#70, #A8,#50, #D4,#08, #8A,#04, #06,#00

; ---- state ----------------------------------------------------------
ptr_visible:    db 0
ptr_pen_out:    db 2
ptr_pen_fill:   db 1
pd_x:           dw 0
pd_y:           dw 0
pd_col:         dw 0
pd_bytes:       db 0
pd_rows:        db 0
pd_cols:        db 0
pd_out:         db 0
pd_fill:        db 0
pc_dir:         db 0
pc_rows:        db 0
pc_line:        dw 0
pc_buf:         dw 0
ptr_buf:        ds PTR_H * 5           ; up to 5 bytes per row (mode 0)
