; =====================================================================
; desktop.asm - the Desktop view (A), the first view at boot
;
; Mode 1. A window shows the files of one drive as icons (the type in
; the icon, a play sign beside a .VBN, the name below), four to a row;
; the drive icons on the right choose which drive. The selected file is
; dark.
;   cursor keys      select (UP/DOWN a row)
;   TAB              other drive
;   RETURN/ENTER     file info
;   ^C copy to the other drive, ^D delete, ^N rename, ^R read again
;   mouse            click a file to select it, again for info; click
;                    a drive to open it
; The file list is FS_CAT itself, read again on every drive change.
; An overlay (kernel/view.asm).
; =====================================================================

DT_X            equ 8               ; the window
DT_Y            equ 18
DT_W            equ 304
DT_H            equ 222
DT_COLS         equ 4
DT_ROWS         equ 5
DT_CELL_W       equ 72
DT_CELL_H       equ 38
DT_CELLS_X      equ DT_X + 8
DT_CELLS_Y      equ DT_Y + 16
DT_FREE_Y       equ DT_Y + DT_H - 12
DT_DRIVE_X      equ 328             ; drive icons
DT_DRIVE_Y      equ 28
DT_DRIVE_W      equ 48
DT_DRIVE_H      equ 36
DT_DRIVE_STEP   equ 52
DT_KEYS_Y       equ GFX_H - 10

        jp dt_init
        jp dt_event
        jp dt_redraw
        db "VV", VIEW_DESKTOP

dt_init:
        ld hl,dt_bar
        call ui_set_bar
        ld hl,ui_no_widgets
        call ui_set_widgets
        xor a
        ld (ptr_keys_on),a
        ld a,1
        call ui_set_mode
        ld hl,palette_mode1
        call ga_set_palette
        ld a,2
        ld (ptr_pen_out),a
        call ptr_clamp
        ld a,(sys_drive)            ; the file selected in the last view
        ld (dt_drive),a
        call dt_draw_screen
        jp dt_load

; everything (also after a language change)
dt_redraw:
        call dt_draw_screen
        jp dt_draw_window

dt_draw_screen:
        call ptr_hide
        ld a,UIP_DESK
        call ui_pen
        call gfx_cls
        call ui_draw_bar
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld a,MSG_DT_KEYS
        call lang_msg
        ld b,h
        ld c,l
        ld hl,0
        ld de,DT_KEYS_Y
        call txt_print
        xor a
        call dt_draw_drive
        ld a,1
        ; fall through

; A = drive: its icon, dark when it is the open one
dt_draw_drive:
        ld (dt_d),a
        ld l,a                      ; y = DT_DRIVE_Y + drive * step
        ld h,0
        ld de,DT_DRIVE_STEP
        call dt_mul
        ld de,DT_DRIVE_Y
        add hl,de
        ld (dt_cy),hl
        ld bc,UIP_TEXT * 256 + UIP_HEAD
        ld a,(dt_drive)
        ld hl,dt_d
        cp (hl)
        jr nz,.colours
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        ld (dt_colours),bc
        ld a,c
        ld (ui_fill_pen),a
        ld hl,DT_DRIVE_X
        ld de,(dt_cy)
        ld bc,DT_DRIVE_W
        ld a,DT_DRIVE_H
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,DT_DRIVE_X
        ld de,(dt_cy)
        ld bc,DT_DRIVE_W
        ld a,DT_DRIVE_H
        call ui_frame
        ld a,UIP_BAR                ; the disc's label
        ld (ui_fill_pen),a
        ld hl,DT_DRIVE_X + 12
        ld de,(dt_cy)
        inc de
        inc de
        inc de
        inc de
        ld bc,DT_DRIVE_W - 24
        ld a,10
        call ui_rect
        ld a,(dt_colours + 1)
        ld bc,(dt_colours)
        call ui_colours
        ld a,(dt_d)
        add a,"A"
        ld (dt_line),a
        ld a,":"
        ld (dt_line + 1),a
        xor a
        ld (dt_line + 2),a
        ld hl,DT_DRIVE_X + 16
        ld de,(dt_cy)
        ld a,22
        add a,e
        ld e,a
        ld bc,dt_line
        jp txt_print

; HL * DE -> HL (small numbers)
dt_mul:
        ld b,l
        ld hl,0
        inc b
        jr .first
.add:
        add hl,de
.first:
        djnz .add
        ret

; read the open drive, then draw the window
dt_load:
        ld a,(dt_drive)
        call fdc_select
        call fs_catalog
        ld c,0
        jr nc,.read
        ld c,a                      ; the error is shown in the window
        xor a
.read:
        ld (dt_count),a
        ld a,c
        ld (dt_err),a
        call fs_free_k
        ld (dt_free),a
        ld a,(fs_reserved)
        ld (dt_fmt),a
        call file_find              ; the selected file, if it is here
        jr c,.clamp
        ld (dt_sel),a
.clamp:
        ld a,(dt_sel)               ; selection still inside the list
        ld hl,dt_count
        cp (hl)
        jr c,.sel_ok
        ld a,(hl)
        or a
        jr z,.sel
        dec a
.sel:
        ld (dt_sel),a
.sel_ok:
        xor a
        ld (dt_top),a
        call dt_remember
        call dt_scroll
        ; fall through

dt_draw_window:
        ld a,UIP_BAR
        ld (ui_fill_pen),a
        ld hl,DT_X
        ld de,DT_Y
        ld bc,DT_W
        ld a,DT_H
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,DT_X
        ld de,DT_Y
        ld bc,DT_W
        ld a,DT_H
        call ui_frame
        ld a,UIP_SEL                ; title: "A: DATA  3 FILES"
        ld (ui_fill_pen),a
        ld hl,DT_X
        ld de,DT_Y
        ld bc,DT_W
        ld a,12
        call ui_rect
        ld de,dt_line
        ld a,(dt_drive)
        add a,"A"
        call util_char
        ld a,":"
        call util_char
        ld a,(dt_err)
        or a
        jr nz,.title
        ld a," "
        call util_char
        ld a,(dt_fmt)
        or a
        ld a,MSG_FMT_DATA
        jr z,.format
        ld a,MSG_FMT_SYSTEM
.format:
        call util_msg
        ld a," "
        call util_char
        call util_char
        ld a,(dt_count)
        ld l,a
        ld h,0
        call util_dec
        ld a," "
        call util_char
        ld a,MSG_FILES
        call util_msg
.title:
        xor a
        ld (de),a
        ld a,UIP_SELTEXT
        ld c,UIP_SEL
        call ui_colours
        ld hl,DT_X + 8
        ld de,DT_Y + 2
        ld bc,dt_line
        call txt_print
        call dt_draw_cells
        ld a,(dt_err)               ; free space, or the error
        or a
        jr nz,.error
        ld a,(dt_count)
        or a
        ld a,MSG_NO_FILES
        jr z,.message
        ld de,dt_line
        ld a,MSG_FREE
        call util_msg
        ld a," "
        call util_char
        ld a,(dt_free)
        ld l,a
        ld h,0
        call util_dec
        ld a,"K"
        call util_char
        xor a
        ld (de),a
        jr .print
.error:
        add a,MSG_ERR_1 - 1
.message:
        ld de,dt_line
        call util_msg
        xor a
        ld (de),a
.print:
        ld a,UIP_TEXT
        ld c,UIP_BAR
        call ui_colours
        ld hl,DT_X + 8
        ld de,DT_FREE_Y
        ld bc,dt_line
        jp txt_print

dt_draw_cells:
        xor a
.cell:
        push af
        call dt_draw_cell
        pop af
        inc a
        cp DT_COLS * DT_ROWS
        jr c,.cell
        ret

; A = cell on screen: the file there, if any
dt_draw_cell:
        ld (dt_k),a
        ld c,0                      ; column, row
.row:
        sub DT_COLS
        jr c,.col
        inc c
        jr .row
.col:
        add a,DT_COLS
        ld l,a
        ld h,0
        ld de,DT_CELL_W
        push bc
        call dt_mul
        pop bc
        ld de,DT_CELLS_X
        add hl,de
        ld (dt_cx),hl
        ld l,c
        ld h,0
        ld de,DT_CELL_H
        call dt_mul
        ld de,DT_CELLS_Y
        add hl,de
        ld (dt_cy),hl
        ld a,UIP_BAR                ; clear the cell
        ld (ui_fill_pen),a
        ld hl,(dt_cx)
        ld de,(dt_cy)
        ld bc,DT_CELL_W
        ld a,DT_CELL_H
        call ui_rect
        ld a,(dt_top)               ; file = top row * 4 + cell
        add a,a
        add a,a
        ld hl,dt_k
        add a,(hl)
        ld (dt_i),a
        ld hl,dt_count
        cp (hl)
        ret nc
        ld bc,UIP_TEXT * 256 + UIP_HEAD
        ld de,UIP_TEXT * 256 + UIP_BAR
        ld hl,dt_sel
        cp (hl)
        jr nz,.colours
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
        ld d,UIP_SELTEXT
        ld e,UIP_SEL
.colours:
        ld (dt_colours),bc          ; icon
        ld (dt_name_colours),de     ; name
        ld a,c                      ; the icon: a page with the type
        ld (ui_fill_pen),a
        ld hl,(dt_cx)
        ld de,22
        add hl,de
        ld de,(dt_cy)
        inc de
        inc de
        ld bc,28
        ld a,22
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,(dt_cx)
        ld de,22
        add hl,de
        ld de,(dt_cy)
        inc de
        inc de
        ld bc,28
        ld a,22
        call ui_frame
        ld a,(dt_i)                 ; HL -> FS_CAT entry
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        ld (dt_ent),hl
        ld de,8                     ; type: the extension
        add hl,de
        ld de,dt_line
        ld bc,3
        ldir
        xor a
        ld (de),a
        ld a,(dt_colours + 1)
        ld bc,(dt_colours)
        call ui_colours
        ld hl,(dt_cx)
        ld de,24
        add hl,de
        ld de,(dt_cy)
        ld a,9
        add a,e
        ld e,a
        ld bc,dt_line
        call txt_print
        call dt_play
        ld hl,(dt_ent)              ; name, without the padding, centred
        ld de,dt_line
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
        ld a,c                      ; x = cell + 36 - 4 * length
        add a,a
        add a,a
        neg
        add a,DT_CELL_W / 2
        ld e,a
        ld d,0
        ld hl,(dt_cx)
        add hl,de
        push hl
        ld a,(dt_name_colours + 1)
        ld bc,(dt_name_colours)
        call ui_colours
        pop hl
        ld de,(dt_cy)
        ld a,27
        add a,e
        ld e,a
        ld bc,dt_line
        jp txt_print

; dt_line = the type: a .VBN (a program made with blocks) gets a play
; sign beside its page, in the page's pen
dt_play:
        ld hl,dt_line
        ld de,dt_vbn
        ld b,3
.same:
        ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .same
        ld a,(dt_colours)
        ld (ui_fill_pen),a
        ld hl,(dt_cx)
        ld de,53
        add hl,de
        ld de,(dt_cy)
        ld a,7
        add a,e
        ld e,a
        ld b,6                      ; columns 11, 9 ... 1 high
        ld a,11
.column:
        push af
        push bc
        push de
        push hl
        ld bc,1
        call ui_rect
        pop hl
        pop de
        pop bc
        pop af
        inc hl
        inc de
        sub 2
        djnz .column
        ret

; dt_top so that the selection is on the screen -> carry if it moved
dt_scroll:
        ld a,(dt_sel)               ; row of the selection
        srl a
        srl a
        ld b,a
        ld a,(dt_top)
        cp b
        jr z,.done
        jr c,.below
        ld a,b                      ; above the screen
        jr .set
.below:
        add a,DT_ROWS - 1
        cp b
        jr nc,.done
        ld a,b
        sub DT_ROWS - 1
.set:
        ld (dt_top),a
        scf
        ret
.done:
        or a
        ret

; A = file to select
dt_select:
        ld hl,dt_sel
        ld b,(hl)
        ld (hl),a
        push bc
        call dt_remember
        call dt_scroll
        pop bc
        jp c,dt_draw_cells
        ld a,(dt_top)               ; same screen: old and new cell
        add a,a
        add a,a
        ld c,a
        ld a,b
        sub c
        call dt_draw_cell
        ld a,(dt_top)
        add a,a
        add a,a
        ld c,a
        ld a,(dt_sel)
        sub c
        jp dt_draw_cell

; the selection, for the next view
dt_remember:
        ld a,(dt_count)
        or a
        ret z
        ld a,(dt_sel)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        ld a,(dt_drive)
        jp file_select

; A = drive to open
dt_open_drive:
        ld hl,dt_drive
        cp (hl)
        ret z
        ld (hl),a
        xor a
        ld (dt_sel),a
        ld a,(dt_drive)
        call dt_draw_drive
        ld a,(dt_drive)
        xor 1
        call dt_draw_drive
        jp dt_load

; ---------------------------------------------------------------------
dt_event:
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
        jp dt_command
.key:
        ld a,(ev_cur + 1)
        ld d,1
        cp KEY_RIGHT
        jr z,.move
        ld d,-1
        cp KEY_LEFT
        jr z,.move
        ld d,DT_COLS
        cp KEY_DOWN
        jr z,.move
        ld d,-DT_COLS
        cp KEY_UP
        jr z,.move
        cp KEY_TAB
        jr nz,.not_tab
        ld a,(dt_drive)
        xor 1
        jr dt_open_drive
.not_tab:
        cp KEY_RETURN
        jp z,dt_info
        cp KEY_ENTER
        jp z,dt_info
        jr .ui
.move:
        ld a,(dt_count)
        or a
        ret z
        ld c,a
        ld a,(dt_sel)
        add a,d
        bit 7,d
        jr nz,.back
        cp c
        ret nc                      ; past the last file: stay
        jp dt_select
.back:
        ret nc                      ; before the first file: stay
        jp dt_select
.click:
        ld hl,(ev_cur + 6)
        ld de,UI_BAR_H
        or a
        sbc hl,de
        jr c,.ui
        ld hl,(ev_cur + 4)          ; a drive icon?
        ld de,DT_DRIVE_X
        or a
        sbc hl,de
        jr c,.window
        ld hl,(ev_cur + 6)
        ld de,DT_DRIVE_Y
        or a
        sbc hl,de
        ret c
        ld de,DT_DRIVE_H
        ld a,0
        or a
        sbc hl,de
        jr c,dt_open_drive_a
        ld de,DT_DRIVE_STEP - DT_DRIVE_H
        sbc hl,de
        ret c
        ld de,DT_DRIVE_H
        sbc hl,de
        ret nc
        ld a,1
        jr dt_open_drive_a
.window:
        ld hl,(ev_cur + 4)          ; a cell?
        ld de,DT_CELLS_X
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        ld c,0
.cx:
        sub DT_CELL_W
        jr c,.cx_done
        inc c
        jr .cx
.cx_done:
        ld a,c
        cp DT_COLS
        ret nc
        ld (dt_k),a
        ld hl,(ev_cur + 6)
        ld de,DT_CELLS_Y
        or a
        sbc hl,de
        ret c
        ld a,l
        ld c,0
.cy:
        sub DT_CELL_H
        jr c,.cy_done
        inc c
        jr .cy
.cy_done:
        ld a,c
        cp DT_ROWS
        ret nc
        ld hl,dt_top                ; file = (top + row) * 4 + column
        add a,(hl)
        add a,a
        add a,a
        ld hl,dt_k
        add a,(hl)
        ld hl,dt_count
        cp (hl)
        ret nc
        ld hl,dt_sel
        cp (hl)
        jp nz,dt_select
        jr dt_info                  ; again on the selected file
dt_open_drive_a:
        jp dt_open_drive

; A = CMD_*
dt_command:
        cp CMD_REFRESH
        jp z,dt_load
        cp CMD_INFO
        jr z,dt_info
        cp CMD_COPY
        jr z,dt_copy
        cp CMD_DELETE
        jr z,dt_delete
        cp CMD_RENAME
        jr z,dt_rename
        cp CMD_RUN
        jr z,dt_run
        jp view_command

; selected file -> file_name, A = drive; carry if there is none
dt_selected:
        ld a,(dt_count)
        or a
        scf
        ret z
        ld a,(dt_sel)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        ld de,file_name
        ld bc,11
        ldir
        ld a,(dt_drive)
        or a
        ret

dt_info:
        call dt_selected
        ret c
        jp file_info

dt_run:
        call dt_selected
        ret c
        jp app_request

; the target is the other drive, which is not on the screen
dt_copy:
        call dt_selected
        ret c
        jp file_copy

dt_delete:
        call dt_selected
        ret c
        call file_delete
        ret c
        jp dt_load

dt_rename:
        call dt_selected
        ret c
        call file_rename
        ret c
        jp dt_load

; ---- menus ----------------------------------------------------------
dt_bar:
        db 3
        dw dt_menu_file, menu_view, menu_help
dt_menu_file:
        db MSG_MENU_FILE, 9
        db MSG_ITEM_RUN, CMD_RUN, 0, 0
        db MSG_ITEM_INFO, CMD_INFO, 0, 0
        db MSG_ITEM_COPY_DRIVE, CMD_COPY, "C", 0
        db MSG_ITEM_DELETE, CMD_DELETE, "D", 0
        db MSG_ITEM_RENAME, CMD_RENAME, "N", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_REFRESH, CMD_REFRESH, "R", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_QUIT, CMD_QUIT, "Q", 0

; ---- state ----------------------------------------------------------
dt_drive:       db 0                ; the open drive
dt_count:       db 0
dt_sel:         db 0
dt_top:         db 0                ; first row on the screen
dt_err:         db 0
dt_free:        db 0
dt_fmt:         db 0
dt_d:           db 0
dt_k:           db 0
dt_i:           db 0
dt_cx:          dw 0
dt_cy:          dw 0
dt_ent:         dw 0
dt_colours:     dw 0
dt_name_colours: dw 0
dt_line:        ds 40
dt_vbn:         db "VBN"
