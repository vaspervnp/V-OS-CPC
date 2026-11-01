; =====================================================================
; ext2.asm - the second kernel extension: code that fits neither in the
; kernel nor in bank 7. It is in base RAM bank 1 at EXT2_ADDR (RAM
; config EXT2_CFG), where VOS.BIN was loaded: after boot nothing else
; uses that bank. The loader copies it there; the kernel calls it
; through ext2_call (kernel/view.asm), which makes that bank home while
; it runs. Like ext.asm, it must not touch a program's memory, and a
; program's code runs only from the kernel (bh_init).
; =====================================================================

; ---------------------------------------------------------------------
; VX_BEHIND, from the main loop (kernel/kernel.asm): the program for
; app_open's file (by its type) into a slot, unless it runs already,
; and its init with A = 3 as the kernel's program (bh_init); then the
; one in front as it was. Carry: A = the error, for sys_error.
; ---------------------------------------------------------------------
behind_run:
        xor a
        ld (bh_req),a
        ld hl,bh_begin              ; (kernel/files_ext.asm)
        call ext_call
        jr c,bh_end
        jr z,.start                 ; it runs already: its slot
        ld a,(app_drive)
        call fdc_select
        ld hl,file_name
        call view_fetch
        jr c,bh_end
        ld de,"A" * 256 + "V"
        or a
        sbc hl,de
        ld a,FS_ERR_NOT_PROGRAM
        scf
        jr nz,bh_end
        ld hl,app_place
        call ext_call
        ld a,FS_ERR_NO_ROOM
        jr c,bh_end
        call view_base              ; the program into its place
        ld a,BUF_CFG
        ld (ab_from),a
        ld a,(vw_cfg)
        ld (ab_to),a
        ld hl,BUF_ADDR
        ld bc,(fs_length)
        call bank_copy
        ld hl,slot_own
        call ext_call
.start:
        call bh_init
        or a
        ; fall through

; the one in front again (bh_save, from bh_begin), app_open empty; its
; bank is home again when ext2_call returns. A and carry kept.
bh_end:
        push af
        ld hl,bh_save
        ld de,vw_page               ; vw_page, vw_cfg, data_cfg, app_slot
        ld bc,4
        ldir
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (cur_base),de
        ld a,(hl)
        inc hl
        ld (app_drive),a
        ld de,file_name
        ld c,11
        ldir
        ld de,app_self
        ld c,12
        ldir
        xor a
        ld (app_open),a
        pop af
        ret

; ---------------------------------------------------------------------
; VX_DB (kernel/api.asm: xa_db): the database engine, src/db/db.asm.
; The first time DB.SYS comes from drive A: to DB_ADDR, in this bank;
; then C = its call, DE, and HL from xa_hl go to it.
; ---------------------------------------------------------------------
db_entry:
        ld a,(db_loaded)
        or a
        jr nz,.go
        push bc
        push de
        xor a
        call fdc_select
        ld hl,db_sys
        ld de,DB_ADDR
        ld c,EXT2_CFG
        call fs_load
        pop de
        pop bc
        jr c,.none
        ld a,(DB_ADDR + 3)          ; "DB"
        cp "D"
        jr nz,.none
        ld a,1
        ld (db_loaded),a
.go:
        ld hl,(xa_hl)
        jp DB_ADDR
.none:
        ld a,DB_ERR_NO_SYS
        scf
        ret
db_sys:         db "DB      SYS"
db_loaded:      db 0

; VX_CALC (kernel/api.asm: xa_calc): the formula engine, src/calc/
; calc.asm, from drive A: to CALC_ADDR the first time, as DB.SYS
calc_entry:
        ld a,(calc_loaded)
        or a
        jr nz,.go
        push bc
        push de
        xor a
        call fdc_select
        ld hl,calc_sys
        ld de,CALC_ADDR
        ld c,EXT2_CFG
        call fs_load
        pop de
        pop bc
        jr c,.none
        ld a,(CALC_ADDR + 3)        ; "CA"
        cp "C"
        jr nz,.none
        ld a,1
        ld (calc_loaded),a
.go:
        ld hl,(xa_hl)
        jp CALC_ADDR
.none:
        ld a,CALC_ERR_NO_SYS
        scf
        ret
calc_sys:       db "CALC    SYS"
calc_loaded:    db 0

; ---------------------------------------------------------------------
; Moving windows (VOS_DRAG, VOS_FIT; kernel/api.asm, ui/ui.asm): a
; window is dr_x, dr_y (drag_run takes it in DE), dr_w, dr_h, in pixels
; of the current mode.
; drag_run, dr_drag = 0: it is moved onto the screen. dr_drag = 1: if
; ev_cur is a click on its top 10 rows, it follows the pointer as a
; dashed outline (drawn with XOR, so drawing it again takes it away)
; until the button goes up -> carry if it moved, dr_x, dr_y where it
; is now. Its x is a multiple of 8, and 4 pixels are kept for a shadow.
; ---------------------------------------------------------------------
dr_x            equ #9800           ; 19 bytes (include/memmap.inc)
dr_y            equ #9802
dr_w            equ #9804
dr_h            equ #9806
dr_drag         equ #9807
dr_nx           equ #9808           ; the outline
dr_ny           equ #980A
dr_gx           equ #980C           ; where in the window it was taken
dr_gy           equ #980E
dr_col          equ #9810           ; outline: a byte on the line
acc_moved       equ #9813           ; the accessory moved (kernel/view.asm)

drag_run:
        ld (dr_y),de
        ld a,(dr_drag)
        or a
        jp z,.fit
        ld a,(ev_cur)
        cp EV_PTR_DOWN
        jp nz,.no
        ld hl,(ev_cur + 4)          ; x - dr_x < dr_w ?
        ld de,(dr_x)
        or a
        sbc hl,de
        jr c,.no
        ld (dr_gx),hl               ; where it was taken
        ld de,(dr_w)
        sbc hl,de
        jr nc,.no
        ld hl,(ev_cur + 6)          ; y - dr_y < 10 ?
        ld de,(dr_y)
        or a
        sbc hl,de
        jr c,.no
        ld (dr_gy),hl
        ld de,10
        sbc hl,de
        jr nc,.no
        call .start
        call drag_outline
.frame:
        call ptr_update
        call wait_frame
.event:
        call ev_get
        jr z,.frame
        cp EV_PTR_UP
        jr z,.to
        cp EV_PTR_MOVE
        jr nz,.event
.to:
        push af
        call drag_outline           ; away from where it was
        ld hl,(ev_cur + 4)
        ld de,(dr_gx)
        call .less
        ld (dr_nx),hl
        ld hl,(ev_cur + 6)
        ld de,(dr_gy)
        call .less
        ld (dr_ny),hl
        call drag_clamp
        pop af
        cp EV_PTR_UP
        jr z,.up
        call drag_outline
        jr .event
.up:
        ld hl,(dr_nx)
        ld de,(dr_x)
        or a
        sbc hl,de
        jr nz,.moved
        ld hl,(dr_ny)
        ld de,(dr_y)
        sbc hl,de
        jr nz,.moved
.no:
        or a
        jr .xy
.fit:
        call .start
        call drag_clamp
.moved:
        ld hl,(dr_nx)
        ld (dr_x),hl
        ld hl,(dr_ny)
        ld (dr_y),hl
        scf
.xy:
        ld hl,(dr_x)
        ld de,(dr_y)
        ret
.start:
        ld hl,(dr_x)
        ld (dr_nx),hl
        ld hl,(dr_y)
        ld (dr_ny),hl
        ret
; HL - DE, 0 if below
.less:
        or a
        sbc hl,de
        ret nc
        ld hl,0
        ret

; ui_move: the uw_ window (dialogs) dragged -> carry: it moved, what it
; covered is back and what it covers now is saved (ui/ui.asm)
drag_window:
        ld hl,uw_x                  ; uw_x ... uw_h as dr_x ... dr_h
        ld de,dr_x
        ld bc,7
        ldir
        ld a,1
        ld (dr_drag),a
        ld de,(uw_y)
        call drag_run
        ret nc
        call ui_restore
        ld hl,dr_x
        ld de,uw_x
        ld bc,4
        ldir
        call ui_save_window
        scf
        ret

; dr_nx, dr_ny: the window on the screen (with a mixed screen, in the
; mode 0 band if drawn in mode 0)
drag_clamp:
        ld hl,(gfx_width)           ; x: at most width - w - 4
        ld de,(dr_w)
        or a
        sbc hl,de
        ld de,4
        sbc hl,de
        jr nc,.x
        ld hl,0                     ; (wider than that: at 0)
.x:
        ex de,hl
        ld hl,(dr_nx)
        call .most
        ld a,l
        and %11111000
        ld l,a
        ld (dr_nx),hl
        ld bc,UI_BAR_H              ; y: below the menu bar, or from
                                    ; the top of the band
        ld hl,GFX_H
        ld a,(split_on)
        or a
        jr z,.band
        ld a,(gfx_mode)
        or a
        jr nz,.band
        ld hl,(split_y2)
        ld bc,(split_y1)
.band:
        ld a,(dr_h)                 ; to its bottom - h - 4
        add a,4
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ex de,hl
        ld hl,(dr_ny)
        call .most
        push hl
        or a
        sbc hl,bc
        pop hl
        jr nc,.y
        ld h,b
        ld l,c
.y:
        ld (dr_ny),hl
        ret
; HL = the smaller of HL and DE
.most:
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

; the dashed outline at dr_nx, dr_ny: dashes of 4 pixels
drag_outline:
        call ptr_hide
        ld de,(dr_ny)               ; top and bottom
        call .row                   ; (keeps DE)
        ld a,(dr_h)
        dec a
        ld l,a
        ld h,0
        add hl,de
        ex de,hl
        call .row
        ld hl,(dr_nx)               ; left and right
        call .column
        ld hl,(dr_nx)
        ld bc,(dr_w)
        add hl,bc
        dec hl
.column:
        push hl
        call gfx_x_to_byte
        ld (dr_col),hl
        pop hl
        ld a,l                      ; its pixel
        ld hl,gfx_pmask
        and (hl)
        ld hl,(gfx_pix)
        call tbl_a
        ld c,a
        ld a,(dr_h)                 ; the rows between the corners
        sub 2
        ld b,a
        ld de,(dr_ny)
.c_row:
        inc de
        ld a,e
        and 4
        jr nz,.c_next
        call .line
        ld a,c
        xor (hl)
        ld (hl),a
.c_next:
        djnz .c_row
        ret
; DE = y: the bytes of the window's width, every other 4 pixels
.row:
        push de
        ld hl,(dr_nx)
        call gfx_x_to_byte
        ld (dr_col),hl
        ld hl,(dr_w)
        call gfx_x_to_byte
        ld b,l
        pop de
        call .line
        ld a,(gfx_mode)             ; 4 pixels: 1 byte in mode 1, 2 in
        or a                        ; mode 0
        ld c,1
        jr nz,.r_byte
        inc c
.r_byte:
        ld a,b
        and c
        jr nz,.r_next
        ld a,(hl)
        cpl
        ld (hl),a
.r_next:
        inc hl
        djnz .r_byte
        ret
; DE = y -> HL = the byte at dr_col on that line
.line:
        push de
        ld hl,gfx_lines
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,(dr_col)
        add hl,de
        pop de
        ret

; ---------------------------------------------------------------------
; VX_UTF8 (kernel/api.asm: xa_utf8): HL (xa_hl) -> text, C and D =
; bytes, E = 0 in the program's memory, VOS_DATA in its data bank. All
; of it is looked at, a piece at a time through u8_buf; if it is UTF-8,
; it is made V-OS in place, each piece cut at a whole character -> HL =
; bytes now, A = 1; else A = 0, HL = bytes as before, the text
; untouched.
; ---------------------------------------------------------------------
U8_PIECE        equ 256

u8_entry:
        ld b,d
        ld hl,(xa_hl)
        ld (u8_at),hl
        ld (u8_len),bc
        ld a,(vw_cfg)
        bit 7,e
        call nz,data_get
        ld (u8_cfg),a
        call u8_start
        call u8_begin
.look:
        call u8_in
        jr z,.looked
        push bc
        ld hl,u8_buf
        call u8_check
        pop bc
        call u8_on
        jr .look
.looked:
        call u8_is
        ld hl,(u8_len)
        or a
        ret z
        call u8_begin
.conv:
        call u8_in
        jr z,.done
        ld hl,(u8_rem)
        or a
        sbc hl,bc
        jr z,.whole                 ; the last piece
        ld hl,u8_buf
        call u8_cut
.whole:
        push bc
        call u8_on
        pop bc
        ld hl,u8_buf
        call u8_conv
        push bc
        ld a,EXT2_CFG
        ld (ab_from),a
        ld a,(u8_cfg)
        ld (ab_to),a
        ld hl,u8_buf
        ld de,(u8_wr)
        call bank_copy
        pop bc
        ld hl,(u8_wr)
        add hl,bc
        ld (u8_wr),hl
        jr .conv
.done:
        ld hl,(u8_wr)
        ld de,(u8_at)
        or a
        sbc hl,de
        ld a,1
        or a
        ret
; from the start: u8_rd, u8_wr, u8_rem
u8_begin:
        ld hl,(u8_at)
        ld (u8_rd),hl
        ld (u8_wr),hl
        ld hl,(u8_len)
        ld (u8_rem),hl
        ret
; the next piece from u8_rd into u8_buf -> BC = its bytes; Z: none left
u8_in:
        ld hl,(u8_rem)
        ld a,h
        or l
        ret z
        ld bc,U8_PIECE
        sbc hl,bc                   ; (no carry)
        jr nc,.full
        ld bc,(u8_rem)
.full:
        push bc
        ld a,(u8_cfg)
        ld (ab_from),a
        ld a,EXT2_CFG
        ld (ab_to),a
        ld hl,(u8_rd)
        ld de,u8_buf
        call bank_copy
        pop bc
        or 1
        ret
; BC bytes taken: u8_rd on, u8_rem down
u8_on:
        ld hl,(u8_rd)
        add hl,bc
        ld (u8_rd),hl
        ld hl,(u8_rem)
        or a
        sbc hl,bc
        ld (u8_rem),hl
        ret

        include "utf8.asm"
u8_at:          dw 0
u8_len:         dw 0
u8_rd:          dw 0
u8_wr:          dw 0
u8_rem:         dw 0
u8_cfg:         db 0
u8_buf:         ds U8_PIECE
