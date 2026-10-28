; =====================================================================
; launcher.asm - the Launcher view (B)
;
; Mode 0, 16 colours. The programs on drive A: (.BIN and .BAS files,
; not V-OS's own) as a 3 x 3 grid of coloured tiles, more on the next
; pages. The selected tile is white. A program with an icon (VOS_ICON
; in src/api/vos_api.inc) shows it on its tile: the first time a page
; is drawn, the first sector of each .BIN on it is read, and the icon
; kept (ln_icons).
;   cursor keys      move (UP/DOWN a row; past the edge, the next page)
;   RETURN/ENTER     start the program (src/api/vos_api.inc)
;   ^R read the disc again; mouse: click a tile, again to start it
; An overlay (kernel/view.asm).
; =====================================================================

LN_COLS         equ 3
LN_TILES        equ 9
LN_TILE_W       equ 64
LN_TILE_H       equ 56
LN_STEP_Y       equ 64
LN_TOP_Y            equ 18
LN_KEYS_Y       equ GFX_H - 10
LN_MAX          equ FS_CAT_MAX

        jp ln_init
        jp ln_event
        jp ln_redraw
        db "VV", VIEW_LAUNCHER

ln_init:
        ld hl,ln_bar
        call ui_set_bar
        ld hl,ui_no_widgets
        call ui_set_widgets
        xor a
        ld (ptr_keys_on),a
        call ui_set_mode
        ld hl,palette_mode0
        call ga_set_palette
        xor a
        ld (ptr_pen_out),a
        call ptr_clamp
        call ln_draw_screen
        jp ln_load

ln_redraw:
        call ln_draw_screen
        jp ln_draw_tiles

ln_draw_screen:
        call ptr_hide
        ld a,UIP_DESK
        call ui_pen
        call gfx_cls
        call ui_draw_bar
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld a,MSG_LN_KEYS
        call lang_msg
        ld b,h
        ld c,l
        ld hl,0
        ld de,LN_KEYS_Y
        jp txt_print

; the programs of drive A:, from its catalog
ln_load:
        ld hl,ln_icon_st            ; icons: not read yet
        ld de,ln_icon_st + 1
        ld bc,LN_MAX - 1
        ld (hl),0
        ldir
        xor a
        call fdc_select
        call fs_catalog
        ld c,0
        jr nc,.read
        ld c,a
        xor a
.read:
        ld (ln_files),a
        ld a,c
        ld (ln_err),a
        xor a
        ld (ln_count),a
        ld (ln_sel),a
        ld hl,FS_CAT
        ld de,ln_list
        ld a,(ln_files)
        or a
        jr z,.listed
        ld b,a
        ld c,0                      ; file number
.file:
        push bc
        push de
        push hl
        call ln_program
        pop hl
        pop de
        pop bc
        jr nz,.next
        ld a,c
        ld (de),a
        inc de
        ld a,(ln_count)
        inc a
        ld (ln_count),a
.next:
        push bc
        ld bc,16
        add hl,bc
        pop bc
        inc c
        djnz .file
.listed:
        ld a,(sys_drive)            ; the program selected in the last view
        or a
        jr nz,.remember
        call file_find
        jr c,.remember
        ld e,a
        ld hl,ln_list               ; its place among the programs
        ld a,(ln_count)
        or a
        jr z,.remember
        ld b,a
        ld c,0
        ld a,e
.place:
        cp (hl)
        jr z,.found
        inc hl
        inc c
        djnz .place
        jr .remember
.found:
        ld a,c
        ld (ln_sel),a
.remember:
        call ln_remember
        ; fall through

ln_draw_tiles:
        xor a
.tile:
        push af
        call ln_draw_tile
        pop af
        inc a
        cp LN_TILES
        jr c,.tile
        ld a,UIP_DESK               ; clear the message line
        ld (ui_fill_pen),a
        ld hl,0
        ld de,LN_KEYS_Y - 12
        ld bc,192
        ld a,10
        call ui_rect
        ld a,(ln_err)               ; error, no programs, or the page
        or a
        jr z,.no_error
        add a,MSG_ERR_1 - 1
        jr .message
.no_error:
        ld a,(ln_count)
        or a
        ld a,MSG_NO_PROGRAMS
        jr z,.message
        ld de,ln_line               ; "PAGE 1/2"
        ld a,MSG_PAGE
        call util_msg
        ld a," "
        call util_char
        ld a,(ln_sel)
        call ln_page
        inc a
        ld l,a
        ld h,0
        call util_dec
        ld a,"/"
        call util_char
        ld a,(ln_count)
        dec a
        call ln_page
        inc a
        ld l,a
        ld h,0
        call util_dec
        xor a
        ld (de),a
        jr .print
.message:
        ld de,ln_line
        call util_msg
        xor a
        ld (de),a
.print:
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld hl,0
        ld de,LN_KEYS_Y - 12
        ld bc,ln_line
        jp txt_print

; HL -> FS_CAT entry -> Z if it is a program: .BIN or .BAS, not VOS.BIN
ln_program:
        push hl
        ld de,ln_vos
        ld b,11
        call .same
        pop hl
        jr z,.not
        push hl
        ld de,8
        add hl,de
        push hl
        ld de,ln_bin
        ld b,3
        call .same
        pop hl
        jr z,.yes
        ld de,ln_bas
        ld b,3
        call .same
.yes:
        pop hl
        ret
.not:
        or 1
        ret
.same:                              ; B bytes at HL and DE -> Z if equal
        ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .same
        ret

; A = program number -> A = its page
ln_page:
        ld b,-1
.count:
        inc b
        sub LN_TILES
        jr nc,.count
        ld a,b
        ret

; A = tile on the screen: draw it
ln_draw_tile:
        ld (ln_k),a
        ld c,0                      ; row
.row:
        sub LN_COLS
        jr c,.col
        inc c
        jr .row
.col:
        add a,LN_COLS               ; x = column * 64
        rrca
        rrca
        ld l,a
        ld h,0
        ld (ln_x),hl
        ld a,c                      ; y = LN_TOP_Y + row * 64
        rrca
        rrca
        add a,LN_TOP_Y
        ld l,a
        ld (ln_y),hl
        ld a,(ln_sel)               ; program = page * 9 + tile
        call ln_first
        ld hl,ln_k
        add a,(hl)
        ld (ln_i),a
        ld hl,ln_count
        cp (hl)
        jr c,.program
        ld a,(ui_pens + UIP_DESK)   ; empty place
        jp ln_fill
.program:
        ld b,a                      ; colour: one of pens 4..12
        ld a,(ln_sel)
        cp b
        ld a,1                      ; selected: white
        jr z,.colour
        ld a,b
.mod:
        sub 9
        jr nc,.mod
        add a,9 + 4
.colour:
        ld (ln_pen),a
        call ln_fill
        ld a,(ln_i)                 ; HL -> FS_CAT entry
        ld e,a
        ld d,0
        ld hl,ln_list
        add hl,de
        ld l,(hl)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        call ln_icon
        push hl
        ld de,ln_line               ; name, without the padding
        ld b,8
        ld c,0
.name:
        ld a,(hl)
        cp " "
        jr z,.named
        ld (de),a
        inc hl
        inc de
        inc c
        djnz .name
.named:
        xor a
        ld (de),a
        ld a,c
        ld (ln_len),a
        ld a,(ln_pen)               ; black text on the tile
        ld c,a
        xor a
        call txt_set_colours
        ld a,(ln_len)               ; x = tile + 32 - 4 * length
        add a,a
        add a,a
        neg
        add a,LN_TILE_W / 2
        ld e,a
        ld d,0
        ld hl,(ln_x)
        add hl,de
        ld de,(ln_y)
        ld a,24
        add a,e
        ld e,a
        ld bc,ln_line
        call txt_print
        pop hl                      ; the type below
        ld de,8
        add hl,de
        ld de,ln_line
        ld bc,3
        ldir
        xor a
        ld (de),a
        ld hl,(ln_x)
        ld de,LN_TILE_W / 2 - 12
        add hl,de
        ld de,(ln_y)
        ld a,38
        add a,e
        ld e,a
        ld bc,ln_line
        jp txt_print

; HL -> FS_CAT entry of program ln_i: its icon on the tile, if it has
; one (keeps HL)
ln_icon:
        push hl
        ld a,(ln_i)
        ld e,a
        ld d,0
        ld hl,ln_icon_st
        add hl,de
        ld (ln_st_ptr),hl
        ld a,(hl)
        or a
        pop hl
        push hl
        call z,ln_icon_read
        ld hl,(ln_st_ptr)
        ld a,(hl)
        cp 2
        jr nz,.done
        ld a,(ln_i)                 ; source: ln_icons + program * 256
        add a,ln_icons >> 8
        ld (ln_blit + 7),a
        ld hl,(ln_x)                ; centred, near the top
        ld de,LN_TILE_W / 2 - 10
        add hl,de
        ld (ln_blit),hl
        ld hl,(ln_y)
        ld de,4
        add hl,de
        ld (ln_blit + 2),hl
        push ix
        ld ix,ln_blit
        call gfx_blit
        pop ix
.done:
        pop hl
        ret

; HL -> FS_CAT entry: a .BIN with "VA" and "IC" in its first sector ->
; its icon to ln_icons, state 2; else state 1
ln_icon_read:
        ld de,(ln_st_ptr)
        ld a,1
        ld (de),a
        push hl
        ld de,8
        add hl,de
        ld de,ln_bin
        ld b,3
        call ln_program.same
        pop hl
        ret nz
        call fs_set_name            ; the directory is still in memory
        call fs_collect
        ret c
        xor a
        ld (fl_sector),a
        call fl_read_next
        ret c
        call fs_header_ok
        ret nz
        ld hl,(fs_buf + 128 + OV_MAGIC - VIEW_ADDR)
        ld de,"A" * 256 + "V"
        or a
        sbc hl,de
        ret nz
        ld hl,(fs_buf + 128 + VOS_ICON)
        ld de,"C" * 256 + "I"
        or a
        sbc hl,de
        ret nz
        ld a,(ln_i)
        add a,ln_icons >> 8
        ld d,a
        ld e,0
        ld hl,fs_buf + 128 + VOS_ICON + 2
        ld bc,VOS_ICON_SIZE
        ldir
        ld hl,(ln_st_ptr)
        ld (hl),2
        ret

; the tile at ln_x, ln_y in pen A
ln_fill:
        ld (ln_pen),a
        push ix
        ld ix,ui_r
        ld hl,(ln_x)
        ld (ix+0),l
        ld (ix+1),h
        ld hl,(ln_y)
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+4),LN_TILE_W - 2
        ld (ix+5),0
        ld (ix+6),LN_TILE_H
        ld (ix+7),0
        ld (ix+8),a
        call gfx_fill_rect
        pop ix
        ret

; A = program -> A = first program of its page
ln_first:
        ld b,0
.sub:
        sub LN_TILES
        jr c,.done
        ld c,a
        ld a,b
        add a,LN_TILES
        ld b,a
        ld a,c
        jr .sub
.done:
        ld a,b
        ret

; A = program to select
ln_select:
        ld hl,ln_sel
        ld b,(hl)
        ld (hl),a
        push bc
        call ln_remember            ; (destroys B)
        pop de                      ; D = old
        ld a,d
        call ln_first
        ld c,a
        ld a,(ln_sel)
        push de
        call ln_first
        pop de
        cp c
        jp nz,ln_draw_tiles         ; another page
        ld c,a
        ld a,d
        sub c
        call ln_draw_tile
        ld a,(ln_sel)
        call ln_first
        ld c,a
        ld a,(ln_sel)
        sub c
        jp ln_draw_tile

; the selection, for the next view
ln_remember:
        ld a,(ln_count)
        or a
        ret z
        ld a,(ln_sel)
        ld e,a
        ld d,0
        ld hl,ln_list
        add hl,de
        ld l,(hl)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        xor a
        jp file_select

; ---------------------------------------------------------------------
ln_event:
        ld a,(ui_open)
        cp UI_NONE
        jr nz,.ui
        ld a,(ev_cur)
        cp EV_KEY_DOWN
        jr z,.key
        cp EV_KEY_REPEAT
        jr z,.key
        cp EV_PTR_DOWN
        jr z,.click
.ui:
        call ui_event
        or a
        ret z
        jp ln_command
.key:
        ld a,(ev_cur + 1)
        ld d,1
        cp KEY_RIGHT
        jr z,.move
        ld d,-1
        cp KEY_LEFT
        jr z,.move
        ld d,LN_COLS
        cp KEY_DOWN
        jr z,.move
        ld d,-LN_COLS
        cp KEY_UP
        jr z,.move
        cp KEY_RETURN
        jp z,ln_run
        cp KEY_ENTER
        jp z,ln_run
        jr .ui
.move:
        ld a,(ln_count)
        or a
        ret z
        ld c,a
        ld a,(ln_sel)
        add a,d
        bit 7,d
        jr nz,.back
        cp c
        ret nc
        jp ln_select
.back:
        ret nc
        jp ln_select
.click:
        ld hl,(ev_cur + 6)          ; which tile?
        ld de,LN_TOP_Y
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        ld c,0
.ty:
        sub LN_STEP_Y
        jr c,.ty_done
        inc c
        jr .ty
.ty_done:
        add a,LN_STEP_Y
        cp LN_TILE_H
        ret nc                      ; between the rows
        ld a,c
        cp LN_TILES / LN_COLS
        ret nc
        ld b,a
        add a,a
        add a,b                     ; row * 3
        ld b,a
        ld a,(ev_cur + 4)           ; column = x / 64
        rlca
        rlca
        and 3
        add a,b
        ld (ln_k),a
        ld a,(ln_sel)
        call ln_first
        ld hl,ln_k
        add a,(hl)
        ld hl,ln_count
        cp (hl)
        ret nc
        ld hl,ln_sel
        cp (hl)
        jp nz,ln_select
        ; again on the selected tile: start it

; start the selected program (kernel/view.asm: app_request)
ln_run:
        ld a,(ln_count)
        or a
        ret z
        call ln_remember
        xor a
        jp app_request

; FILE > AS ACCESSORY: the program selected becomes the desk accessory
; (src/api/vos_api.inc), if it has a relocation table and is small
; enough: it is read into bank 4, moved to ACC_ADDR (acc_reloc) and
; copied to bank 6, then it opens (kernel/view.asm)
ln_acc:
        ld a,(ln_count)
        or a
        ret z
        call ln_remember
        xor a
        call fdc_select
        ld hl,file_name
        call view_fetch
        jr c,.error
        ld de,"A" * 256 + "V"
        or a
        sbc hl,de
        jr nz,.bad
        ld a,c
        cp VOS_API_VERSION + 1
        jr nc,.bad
        ld hl,(fs_length)           ; its end: dw count, "RL"
        ld de,BUF_ADDR - 4
        add hl,de
        push hl
        ld de,bank_buf
        ld bc,4
        ld a,BUF_CFG
        call bank_get
        pop hl
        ld a,(bank_buf + 2)
        cp "R"
        jr nz,.bad
        ld a,(bank_buf + 3)
        cp "L"
        jr nz,.bad
        ld bc,(bank_buf)            ; the table: 2 bytes an entry
        or a
        sbc hl,bc
        sbc hl,bc
        push hl
        ld de,BUF_ADDR + ACC_MAX + 1
        or a
        sbc hl,de
        pop hl
        jr nc,.bad                  ; more than ACC_MAX
        push hl
        call acc_reloc
        pop hl
        ld bc,-BUF_ADDR             ; the program's bytes
        add hl,bc
        ld b,h
        ld c,l
        ld a,BUF_CFG
        ld (ab_from),a
        ld a,ACC_CFG
        ld (ab_to),a
        ld hl,BUF_ADDR
        ld de,ACC_ADDR
        call bank_copy
        ld a,1
        ld (acc_loaded),a
        ld (acc_req),a              ; it opens after this event
        jp acc_reset
.bad:
        ld a,FS_ERR_NOT_PROGRAM
.error:
        jp sys_error

ln_command:
        cp CMD_INFO
        jp z,ln_run
        cp CMD_ACC
        jp z,ln_acc
        cp CMD_REFRESH
        jp z,ln_load
        jp view_command

; ---- menus ----------------------------------------------------------
ln_bar:
        db 3
        dw ln_menu_file, menu_view, menu_help
ln_menu_file:
        db MSG_MENU_FILE, 5
        db MSG_ITEM_RUN, CMD_INFO, 0, 0
        db MSG_ITEM_ACC, CMD_ACC, "A", 0
        db MSG_ITEM_REFRESH, CMD_REFRESH, "R", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_QUIT, CMD_QUIT, "Q", 0


ln_vos:         db "VOS     BIN"
ln_bin:         db "BIN"
ln_bas:         db "BAS"

; ---- state ----------------------------------------------------------
ln_files:       db 0
ln_err:         db 0
ln_count:       db 0                ; programs
ln_sel:         db 0
ln_k:           db 0
ln_i:           db 0
ln_pen:         db 0
ln_len:         db 0
ln_x:           dw 0
ln_y:           dw 0
ln_line:        ds 26
ln_list:        ds LN_MAX           ; FS_CAT numbers of the programs
ln_st_ptr:      dw 0
ln_blit:        dw 0, 0             ; VOS_BLIT: x, y, bytes, rows,
                db 8, 16            ; source, stride
                dw 0
                db 16
ln_icon_st:     ds LN_MAX           ; 0 not read, 1 none, 2 in ln_icons

; the icons, a page each, after the overlay (not in its file)
ln_icons        equ ($ + 255) & #FF00
        assert ln_icons + LN_MAX * 256 <= VIEW_ADDR + #4000
