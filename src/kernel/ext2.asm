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

; ---------------------------------------------------------------------
; VX_PRINT (kernel/api.asm: xa_print): HL (xa_hl) -> text, C and D =
; bytes, E = 0 in the program's memory, VOS_DATA in its data bank: to
; the printer port, a piece at a time through u8_buf (u8_in), the codes
; over 127 as ASCII (prt_ascii: the port has 7 bits). Carry, A =
; PRT_ERR: the printer stayed busy for two seconds (there is none, it
; is off line or out of paper).
; Pages: after PRT_LINES lines (LFs) a form feed (12) goes out by
; itself. BC = 0 starts a printout: HL -> its file's name, 11 bytes as
; in a catalog ("NOTES   TXT"); then each page begins with a heading,
; "NOTES.TXT  PAGE 2" and an empty line (HL = 0: none).
; ---------------------------------------------------------------------
PRT_ERR         equ 41              ; THE PRINTER IS NOT READY
PRT_LINES       equ 60              ; on a page of 66, a margin at its end

        IFDEF TEST_SCRIPT           ; the test builds have no room for it
        IF TEST_SCRIPT != 42        ; (the scripts are here), but make
PRT_NONE        equ 1               ; test-print's
        ENDIF
        ENDIF
        IFDEF PRT_NONE
prt_entry:
        ld a,PRT_ERR
        scf
        ret
        ELSE
prt_entry:
        ld b,d
        ld hl,(xa_hl)
        ld a,b                      ; BC = 0: a new printout, its title
        or c
        jr nz,.text
        ld (prt_line),a
        ld (prt_title),a
        ld (prt_head),a
        inc a
        ld (prt_page),a
        ld a,h                      ; HL = 0: no headings
        or l
        ret z
        ld (prt_head),a
        ld a,(vw_cfg)               ; (through bank_buf: this bank is
        ld de,bank_buf              ; not mapped while it copies)
        ld bc,11
        call bank_get
        ld hl,bank_buf
        ld de,prt_title
        call util_fcb_text
        xor a
        ld (de),a
        ret
.text:
        ld (u8_at),hl
        ld (u8_len),bc
        ld a,(vw_cfg)
        bit 7,e
        call nz,data_get
        ld (u8_cfg),a
        call u8_begin
.piece:
        call u8_in                  ; Z (no carry): all sent
        ret z
        push bc
        ld hl,u8_buf
.char:
        ld a,(hl)
        inc hl
        push bc
        call prt_page_char
        pop bc
        jr c,.busy
        dec bc
        ld a,b
        or c
        jr nz,.char
        pop bc
        call u8_on
        jr .piece
.busy:
        pop bc
        ld a,PRT_ERR
        ret

; A -> the printer, a page's heading before it (prt_head) and a form
; feed after its last line. Carry: busy
prt_page_char:
        push hl
        ld c,a
        ld hl,prt_head              ; the heading first?
        ld a,(hl)
        or a
        jr z,.char
        ld a,c
        cp 12
        jr z,.char
        ld (hl),0
        push bc
        ld a,(prt_page)             ; "NOTES.TXT  PAGE 2", an empty line
        ld l,a
        ld h,0
        ld de,prt_num
        ld a," "
        ld (de),a
        inc de
        call util_dec
        ld hl,prt_crlf2
        ld bc,5
        ldir
        ld hl,prt_title
        call prt_text
        jr c,.head_busy
        ld hl,prt_gap
        call prt_text
        jr c,.head_busy
        ld a,MSG_PAGE
        call lang_msg
        call prt_text
        jr c,.head_busy
        ld hl,prt_num
        call prt_text
.head_busy:
        pop bc
        jr c,.done
        ld a,2
        ld (prt_line),a
.char:
        ld a,c
        call prt_char
        jr c,.done
        ld a,c
        ld hl,prt_line
        cp 12                       ; a new page, asked for
        jr z,.page
        cp 10
        jr nz,.done
        inc (hl)
        ld a,(hl)
        cp PRT_LINES
        ccf
        jr nc,.done
        ld a,12
        call prt_char
        jr c,.done
.page:
        ld (hl),0
        ld hl,prt_page
        inc (hl)
        ld a,(prt_title)            ; a heading on it, with a title
        or a
        jr z,.done
        ld a,1
        ld (prt_head),a
.done:
        pop hl
        ret

; HL -> text, a 0 at its end: to the printer. Carry: busy
prt_text:
        ld a,(hl)
        or a
        ret z
        inc hl
        call prt_char
        ret c
        jr prt_text

prt_title:      ds 13               ; (0: none, no headings)
prt_page:       db 1
prt_line:       db 0
prt_head:       db 0
prt_num:        ds 1 + 3 + 5        ; " " and the page's number, prt_crlf2
prt_gap:        db "  ", 0
prt_crlf2:      db 13, 10, 13, 10, 0

; A -> the printer, when its BUSY (PPI port B, bit 6) is off: the byte
; on #EFxx, then STROBE (bit 7) on and off. Carry: busy for 2 s.
prt_char:
        or a
        jp p,.ascii
        push hl
        and #7F
        ld l,a
        ld h,0
        ld de,prt_ascii
        add hl,de
        ld a,(hl)
        pop hl
.ascii:
        ld e,a
        ld d,2                      ; 2 x 65536 x 59 T: 2 s
        push hl
        ld hl,0
.wait:
        ld b,PPI_B >> 8
        in a,(c)
        and #40
        jr z,.ready
        dec hl
        ld a,h
        or l
        jr nz,.wait
        dec d
        jr nz,.wait
        pop hl
        scf
        ret
.ready:
        pop hl
        ld b,PRINTER_PORT >> 8
        out (c),e
        set 7,e
        out (c),e
        res 7,e
        out (c),e
        or a
        ret

        include "ascii.inc"
        ENDIF

; ---------------------------------------------------------------------
; fs_rename (kernel/files_ext.asm: fx_rename): file_name to fi_new on
; the disc in the drive selected, in kernel/fs.asm's directory cache
; (the M4's card: m4_rename, kernel/m4.asm)
; ---------------------------------------------------------------------
fs_rename:
        ld hl,fi_new                ; the new name must be free
        call fs_set_name
        call fs_mount
        ret c
        xor a
        call fs_find
        ld a,FS_ERR_EXISTS
        ccf
        ret c
        ld hl,file_name
        call fs_set_name
        xor a
        ld (fs_count),a
.entry:
        ld (fs_e),a
        call fs_entry
        call fs_match
        jr nz,.next
        inc hl                      ; every extent gets the new name
        ex de,hl
        ld hl,fi_new
        ld bc,11
        ldir
        ld hl,fs_count
        inc (hl)
.next:
        ld a,(fs_e)
        inc a
        cp FS_ENTRIES
        jr c,.entry
        ld a,(fs_count)
        or a
        ld a,FS_ERR_NOT_FOUND
        scf
        ret z
        jp fs_write_dir

; fs_format (fx_format): the disc in the drive selected, 40 tracks in
; DATA format
fs_format:
        xor a
.track:
        ld (fs_e),a
        ld d,a
        ld e,#C1
        call fdc_format
        ret c
        ld a,(fs_e)
        inc a
        cp 40
        jr c,.track
        ret


; VOS_CATALOG (kernel/api.asm: api_catalog): cat_a = drive (+
; VOS_CAT_EXT: only the files with the extension cat_ext, and the SD
; card's folders) -> A = files in FS_CAT, HL = FS_CAT; carry: A = error.
; The file list goes into a folder with it again (fp_folder).
cat_run:
        ld a,(cat_a)
        and #3F
        call fdc_select
        call fs_catalog
        ret c
        ld hl,cat_a
        bit 6,(hl)
        jr z,.end
        ld hl,FS_CAT                ; from
        ld de,FS_CAT                ; to: where the next one kept goes
        ld b,a
        ld c,0
        or a
        jr z,.kept
.file:
        push bc
        push hl
        ld bc,13
        add hl,bc
        ld a,(hl)
        pop hl
        push hl
        or a
        jr nz,.keep                 ; a folder
        ld bc,8
        add hl,bc
        push de
        ld de,cat_ext
        ld b,3
.same:
        ld a,(de)
        cp (hl)
        jr nz,.other
        inc hl
        inc de
        djnz .same
.other:
        pop de
        jr nz,.drop
.keep:
        pop hl
        ld bc,16
        ldir
        pop bc
        inc c
        djnz .file
        jr .kept
.drop:
        pop hl
        ld bc,16
        add hl,bc
        pop bc
        djnz .file
.kept:
        ld a,c
        ld (fc_count),a
        or a
.end:
        ld hl,FS_CAT
        ret

; the file list's choice (ui/filedlg.asm: fp_sel) a folder of the SD
; card: into it, and the catalog again as VOS_CATALOG made it -> NZ;
; Z: not a folder, or nothing there (fp_result 2: cancelled)
fp_folder:
        ld a,(fp_sel)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        push hl
        ld de,13
        add hl,de
        ld a,(hl)
        pop hl
        or a
        ret z
        ld de,file_name
        ld bc,11
        ldir
        ld hl,m4_cd_e
        call ext_call
        jr c,.none
        call cat_run
        jr c,.none
        or a
        ret nz
.none:
        ld a,2
        ld (fp_result),a
        xor a
        ret

; ---------------------------------------------------------------------
; DB.SYS's disc layer (src/db/db.asm): here, in the engine's bank, and
; for the SD card too
; ---------------------------------------------------------------------
; before each call with a database open: its drive, its format
dk_begin:
        ld a,(db_drive)
        call fdc_select
        ld a,(db_drive)
        cp 2
        jr z,.card
        ld hl,db_fmt
        ld de,fs_first_id
        ld bc,3
        ldir
.card:
        or a
        ret

; a new file of one page, page 0 empty but for "VDB1" and 1 page
dk_create:
        ld a,(db_drive)
        call fdc_select
        ld hl,db_name
        call fs_exists
        ld a,FS_ERR_EXISTS
        ccf
        ret c
        ld hl,DB_CACHE              ; (the cache is empty then)
        ld de,DB_CACHE + 1
        ld bc,DB_PAGE - 1
        ld (hl),0
        ldir
        ld hl,db_magic
        ld de,DB_CACHE
        ld bc,4
        ldir
        ld a,1
        ld (de),a
        ld a,#FF                    ; no AMSDOS header
        ld (fs_hdr_type),a
        ld hl,db_name
        ld de,DB_CACHE
        ld bc,DB_PAGE
        ld a,EXT2_CFG
        call fs_save
        ret c
        ; fall through
; the file's blocks -> db_blocks, db_nblocks; its format -> db_fmt
dk_open:
        ld a,(db_drive)
        call fdc_select
        ld a,(db_drive)
        cp 2
        jp z,dm_open_db
        ld hl,db_name
        call fs_set_name
        call fs_mount
        ret c
        call fs_collect
        ret c
        ld hl,fs_first_id
        ld de,db_fmt
        ld bc,3
        ldir
        call fs_free_k              ; the room on the disc
        ld (db_room),a
dk_blocks:
        ld hl,fs_blist
        ld de,db_blocks
        ld bc,180
        ldir
        ld a,(fs_nblocks)
        ld (db_nblocks),a
        or a
        ret

; DE = page -> HL -> 1K: from its block (dk_write: to it)
dk_read:
        ld a,(db_drive)
        cp 2
        ld a,M4_MODE_R
        jp z,dm_page
        call dk_sector
        ret c
        ld b,2
.half:
        push bc
        push hl
        push de
        ex de,hl
        call fs_read_ls
        pop de
        pop hl
        pop bc
        ret c
        push bc
        ex de,hl
        push hl
        ld hl,fs_buf
        ld bc,512
        ldir
        pop hl
        ex de,hl
        inc de
        pop bc
        djnz .half
        or a
        ret
dk_write:
        ld a,(db_drive)
        cp 2
        ld a,M4_MODE_RW
        jp z,dm_page
        call dk_sector
        ret c
        ld b,2
.half:
        push bc
        push de
        ld de,fs_buf
        ld bc,512
        ldir
        pop de
        push hl
        push de
        ex de,hl
        call fs_write_ls
        pop de
        pop hl
        pop bc
        ret c
        inc de
        djnz .half
        or a
        ret
; DE = page -> DE = its first sector in the data area (HL kept)
dk_sector:
        ld a,(db_nblocks)
        dec a
        cp e
        ld a,FS_ERR_NOT_FOUND
        ret c
        push hl
        ld hl,db_blocks
        add hl,de
        ld e,(hl)
        ld d,0
        ex de,hl
        add hl,hl
        ex de,hl
        pop hl
        or a
        ret

; one block more for the file: the directory read again (the file as
; it was?), a free block, the entries written again
dk_append:
        ld a,(db_drive)             ; the SD card: the file a page
        cp 2                        ; longer
        jr nz,.disc
        call dm_grow
        ret c
        ld hl,db_nblocks
        inc (hl)
        xor a
        ret
.disc:
        ld hl,db_name
        call fs_set_name
        call fs_mount
        ret c
        call fs_collect
        ret c
        ld a,(fs_nblocks)
        ld hl,db_nblocks
        cp (hl)
        ld a,FS_ERR_NOT_FOUND       ; another disc?
        scf
        ret nz
        ld a,2                      ; a free block
.block:
        ld hl,fs_blocks
        cp (hl)
        jr nc,.full
        push af
        call fs_used
        jr z,.free
        pop af
        inc a
        jr .block
.full:
        ld a,FS_ERR_FULL
        scf
        ret
.free:
        pop af
        push af
        call fs_mark
        ld a,(fs_nblocks)
        ld e,a
        ld d,0
        ld hl,fs_blist
        add hl,de
        pop af
        ld (hl),a
        ld hl,fs_nblocks
        inc (hl)
        ld a,(hl)
        add a,15                    ; entries = (blocks + 15) / 16
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld (fs_extents),a
        ld a,(hl)                   ; records = blocks * 8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (fs_records),hl
        call fs_unlink
        call fs_free_entries
        ld hl,fs_extents
        cp (hl)
        ld a,FS_ERR_DIR_FULL
        ret c
        call fs_write_entries
        ret c
        jp dk_blocks

M4_MODE_RW      equ #93                 ; FatFS, read and write, open
                                        ; always: a write past its end
                                        ; makes it longer (in 1984 too)
                                        ; (M4_MODE_R: kernel/m4.asm)
; ---- SHEET's test builds have no room for a database on the SD card
        IFDEF TEST_SCRIPT
        IF TEST_SCRIPT == 32 || TEST_SCRIPT == 42
DM_NONE         equ 1
        ENDIF
        ENDIF
        IFDEF DM_NONE
dm_open_db:
dm_page:
dm_grow:
        ld a,35                     ; (no M4 board)
        scf
        ret
        ELSE
; ---- a database on the SD card (db_drive 2): the file opened, a page
; read or written at page * 1024 (C_SEEK), closed; commands and
; responses in fs_buf from +252, as kernel/m4.asm's, through VX_M4
; (xa_m4), straight into the engine's cache in this bank
DM_ZERO         equ 0                   ; dm_page: a page of zeros
DM_BUF          equ fs_buf + 252        ; db size, dw command, data
DM_PIECE        equ 128

; dk_open: -> db_nblocks = pages, db_room = free K on the card
dm_open_db:
        call fs_free_k
        ret c
        ld (db_room),a
        ld a,M4_MODE_R              ; the size -> pages
        call dm_open
        ret c
        ld a,#11                    ; C_FSIZE
        call dm_cmd
        call dm_go
        ld hl,(DM_BUF + 3)
        ld a,(DM_BUF + 5)
        ld de,DB_PAGE - 1
        add hl,de
        adc a,0
        srl a                       ; A:H / 4
        rr h
        srl a
        rr h
        ld a,h
        ld (db_nblocks),a
        jp dm_close

; A = mode (M4_MODE_R, M4_MODE_RW, DM_ZERO), DE = page, HL -> its 1K
; here
dm_page:
        ld (dm_ptr),hl
        ld (dm_mode),a
        or a
        jr nz,.open
        ld a,M4_MODE_RW
.open:
        push de
        call dm_open
        pop hl
        ret c
        push hl
        ld a,#05                    ; C_SEEK: fd, 32-bit offset
        call dm_cmd
        pop hl
        xor a
        ld (de),a
        inc de
        add hl,hl
        add hl,hl
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        call dm_go
        jr nz,.fail
        ld b,DB_PAGE / DM_PIECE
.piece:
        push bc
        ld a,(dm_mode)
        cp M4_MODE_R
        jr nz,.write
        ld a,#02                    ; C_READ: fd, dw bytes
        call dm_cmd
        ld a,DM_PIECE
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        call dm_go
        jr nz,.fail_bc
        ld hl,DM_BUF + 4
        ld de,(dm_ptr)
        ld bc,DM_PIECE
        ldir
        ld (dm_ptr),de
        jr .next
.write:
        ld a,#03                    ; C_WRITE: fd, the bytes
        call dm_cmd
        ld a,(dm_mode)
        or a                        ; (DM_ZERO)
        jr z,.zeros
        ld hl,(dm_ptr)
        ld bc,DM_PIECE
        ldir
        ld (dm_ptr),hl
        jr .send
.zeros:
        ld h,d                      ; (dm_grow) a piece of zeros
        ld l,e
        ld (hl),0
        inc de
        ld bc,DM_PIECE - 1
        ldir
.send:
        call dm_go
        jr nz,.fail_bc
.next:
        pop bc
        djnz .piece
        jr dm_close
.fail_bc:
        pop bc
.fail:
        call dm_close
        ld a,FDC_ERR_DATA
        scf
        ret

; dk_append: the file a page longer, of zeros, at its end
dm_grow:
        ld a,(db_nblocks)
        ld e,a
        ld d,0
        ld a,DM_ZERO
        jp dm_page

; A = mode: db_name opened -> dm_fd; carry: A = error
dm_open:
        ld hl,DM_BUF + 1
        ld (hl),#01                 ; C_OPEN: mode, "NAME.EXT", 0
        inc hl
        ld (hl),#43
        inc hl
        ld (hl),a
        inc hl
        ex de,hl
        ld hl,db_name
        ld b,8
.name:
        ld a,(hl)
        inc hl
        cp " "
        jr z,.skip
        ld (de),a
        inc de
.skip:
        djnz .name
        ld a,"."
        ld (de),a
        inc de
        ld b,3
.ext:
        ld a,(hl)
        inc hl
        and #7F
        ld (de),a
        inc de
        djnz .ext
        xor a
        ld (de),a
        inc de
        call dm_go
        ret c
        ld a,(DM_BUF + 4)           ; data: the descriptor, the result
        or a
        ld a,FS_ERR_NOT_FOUND
        scf
        ret nz
        ld a,(DM_BUF + 3)
        ld (dm_fd),a
        or a
        ret

dm_close:
        ld a,#04                    ; C_CLOSE: fd
        call dm_cmd
        ; fall through
; DE = after the command in DM_BUF: sent, the response there -> A = its
; result (0 when it has no data, as C_SEEK's may not), Z: done; carry:
; no M4 board (A = 35)
dm_go:
        ld a,e
        sub (DM_BUF + 1) & #FF
        ld (DM_BUF),a
        ld hl,DM_BUF
        ld de,DM_BUF
        ld bc,DM_PIECE + 4
        call xa_m4
        ld a,35
        ret c
        ld a,(DM_BUF)
        cp 3
        ld a,0
        jr c,.done
        ld a,(DM_BUF + 3)
.done:
        or a
        ret

; A = command (#43xx) -> its first bytes, dm_fd, in DM_BUF; DE after
dm_cmd:
        ld hl,DM_BUF + 1
        ld (hl),a
        inc hl
        ld (hl),#43
        inc hl
        ld a,(dm_fd)
        ld (hl),a
        inc hl
        ex de,hl
        ret

dm_fd:          db 0
dm_mode:        db 0
dm_ptr:         dw 0

        ENDIF

; the dark theme (Setup's THEME, CFG_THEME 1; ui/ui.asm: ui_set_mode):
; the bars, menus, dialogs and lists in the text's pen and their text in
; theirs, the selection the other way round, the shadow in the bar's
; pen, the frame in the text's
ui_dark:
        assert UIP_TEXT == UIP_BAR + 1 && UIP_SEL == UIP_BAR + 2
        assert UIP_SELTEXT == UIP_BAR + 3 && UIP_SHADOW == UIP_BAR + 4
        assert UIP_FRAME == UIP_BAR + 5
        ld hl,ui_pens + UIP_BAR
        ld a,(hl)                   ; A = bar, B = text
        inc hl
        ld b,(hl)
        ld (hl),a
        dec hl
        ld (hl),b
        inc hl
        inc hl
        ld d,(hl)                   ; selection and its text
        inc hl
        ld e,(hl)
        ld (hl),d
        dec hl
        ld (hl),e
        inc hl
        inc hl
        ld (hl),b                   ; shadow, frame
        inc hl
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; SETUP.CFG (kernel/setup.asm: cfg_load, cfg_save come here)
; ---------------------------------------------------------------------
cfg_load_x:
        xor a
        call fdc_select
        ld hl,cfg_file
        ld de,BUF_ADDR
        ld c,BUF_CFG
        call fs_load
        jr c,.apply                 ; no file: the defaults
        ld hl,BUF_ADDR
        ld de,cfg_head
        ld bc,CFG_SIZE
        ld a,BUF_CFG
        call bank_get
        ld hl,cfg_head
        ld de,cfg_magic
        ld b,4
.magic:
        ld a,(de)
        cp (hl)
        jr nz,.apply
        inc hl
        inc de
        djnz .magic
        ld a,(hl)                   ; the version
        inc hl
        ld bc,CFG_COUNT
        cp 5
        jr z,.copy
        ld c,CFG_WIN_X              ; up to the picture's name
        cp 4
        jr z,.copy
        ld c,CFG_THEME              ; up to CFG_KBDS
        cp 3
        jr z,.copy
        dec c                       ; up to CFG_DESK
        cp 2
        jr nz,.apply
.copy:
        ld de,cfg_data
        ldir
.apply:
        ld a,(cfg_data + CFG_VIEW)
        ld (view_next),a
        jp cfg_apply

; cfg_data -> A:SETUP.CFG. Carry and A = error on failure
cfg_save_x:
        ld hl,cfg_magic
        ld de,cfg_head
        ld bc,5
        ldir
        ld hl,cfg_data
        ld bc,CFG_COUNT
        ldir
        xor a
        call fdc_select
        ld a,2
        ld (fs_hdr_type),a
        ld hl,0
        ld (fs_hdr_load),hl
        ld (fs_hdr_exec),hl
        ld hl,cfg_file
        ld de,cfg_head
        ld bc,CFG_SIZE
        ld a,BUF_CFG                ; (the source is below #4000)
        jp fs_save

cfg_file:       db "SETUP   CFG"
cfg_magic:      db "VCFG", 5

; ---------------------------------------------------------------------
; the clock on the menu bar, with an M4 board: every frame from the main
; loop (kernel/kernel.asm); once a second its time (C_TIME) as "hh:mm",
; left of the keyboard's language, while the bar has room for it
; (ui_ind_room 2, ui/ui.asm; gfx_cls takes it away)
; ---------------------------------------------------------------------
clk_frame:
        ld hl,clk_wait
        dec (hl)
        ret nz
        ld (hl),50
        ld a,(ui_ind_room)
        cp 2
        ret nz
        ld hl,clk_cmd
        ld de,clk_rsp
        ld bc,3 + 5
        call xa_m4
        ret c                       ; no M4 board
        ld a,(clk_rsp)              ; its answer, "hh:mm..."
        cp 3 + 5
        ret c
        ld a,(clk_rsp + 5)
        cp ":"
        ret nz
        xor a
        ld (clk_rsp + 3 + 5),a
        ld b,1                      ; in the bar's band
        ld hl,.body
        jp ui_in_band
.body:
        ld a,UIP_TEXT
        ld c,UIP_BAR
        call ui_colours
        ld hl,(gfx_width)
        ld de,-24 - 48
        add hl,de
        ld de,1
        ld bc,clk_rsp + 3
        jp txt_print

clk_wait:       db 1
clk_cmd:        db 2
                dw #4324            ; C_TIME
clk_rsp:        ds 3 + 6
