; =====================================================================
; desktop.asm - the Desktop view (A), the first view at boot
;
; Mode 1. At first no window and no drive: the desk (and its picture).
; A drive opens a window of its files as icons (the type in the icon, a
; play sign beside a .VBN, the name below), as many to a row as the
; window is wide; the drive icons on the right choose which drive: A:,
; B: and, with an M4 board, DISK, its SD card, whose folders show as
; folders (RETURN goes in, ".." up; the title says where). The selected
; file is dark. The window: its title bar moves it, its X closes it,
; the corner below on the right makes it larger or smaller (2-5 columns,
; 1-5 rows), the bar on the right scrolls it a window at a time.
;   cursor keys      select (UP/DOWN a row)
;   TAB              the next drive (no window: A:)
;   RETURN/ENTER     open (a folder: go in)
;   ^C copy to the next drive, ^D delete, ^N rename, ^R read again
;   mouse            click a file to select it, again for info; click
;                    a drive to open it, the open one to close it
; The file list is FS_CAT itself, read again on every drive change.
; An overlay (kernel/view.asm).
; =====================================================================

DT_X            equ 8               ; the window, at first (dt_wx, dt_wy)
DT_Y            equ 18
dt_wx           equ #A000           ; kept between views (memmap.inc)
dt_wy           equ #A002
dt_placed       equ #A004
dt_cols         equ #A005           ; its size in cells
dt_rows         equ #A006
dt_shown        equ #A007           ; 1: open (dt_drive), 0: closed
DT_COLS0        equ 4               ; at first
DT_ROWS0        equ 5
DT_MAX_COLS     equ 5
DT_MAX_ROWS     equ 5
DT_CLOSED       equ #FF             ; dt_drive: no window
DT_BAR_W        equ 8               ; the scroll bar
DT_CELL_W       equ 72
DT_CELL_H       equ 38
DT_DRIVE_X      equ 328             ; drive icons
        IFDEF DEMO                  ; the videos (tools/video): in the 1984
DT_DRIVE_Y      equ 40              ; emulator A:'s icon must not put #FF at
        ELSE                        ; #B1FC (x 368, y 38), where 1984 looks
DT_DRIVE_Y      equ 28              ; for the 464 firmware's inks
        ENDIF
DT_DRIVE_W      equ 48
DT_DRIVE_H      equ 36
DT_DRIVE_STEP   equ 52
        IFDEF TEST_SCRIPT
        IF TEST_SCRIPT == 45
DT_SAVER_FRAMES equ 500             ; (make test-saver)
        ELSE
DT_SAVER_FRAMES equ 3 * 60 * 50
        ENDIF
        ELSE
DT_SAVER_FRAMES equ 3 * 60 * 50     ; the screen saver: 3 minutes
        ENDIF
DT_KEYS_Y       equ GFX_H - 10

        jp dt_init
        jp dt_event
        jp dt_redraw
        db "VV", VIEW_DESKTOP

dt_init:
        ld a,(dt_placed)            ; the window where it was left
        or a
        jr nz,.placed
        inc a
        ld (dt_placed),a
        ld hl,DT_X
        ld (dt_wx),hl
        ld hl,DT_Y
        ld (dt_wy),hl
        ld hl,DT_ROWS0 * 256 + DT_COLS0
        ld (dt_cols),hl
        xor a                       ; at boot: closed
        ld (dt_shown),a
.placed:
        ld a,1                      ; EV_FRAME: the screen saver
        ld (view_ticks),a
        ld hl,0
        ld (dt_idle),hl
        xor a
        ld (dt_saver),a
        call dt_size
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
        ld hl,m4_find               ; an M4 board: a third drive
        call ext_call
        sbc a,a
        inc a
        ld (dt_m4),a
        ld a,(dt_shown)             ; open: the drive of the file
        or a                        ; selected in the last view
        ld a,DT_CLOSED
        jp z,.drive
        ld a,(sys_drive)
.drive:
        ld (dt_drive),a
        xor a
        ld (dt_count),a
        call dt_draw_screen
        jp dt_load

; dt_cols, dt_rows -> dt_w, dt_h, dt_cells
dt_size:
        ld a,(dt_cols)
        ld l,a
        ld de,DT_CELL_W
        call dt_mul
        ld de,24
        add hl,de
        ld (dt_w),hl
        ld a,(dt_rows)
        ld l,a
        ld de,DT_CELL_H
        call dt_mul
        ld a,30
        add a,l
        ld (dt_h),a
        ld a,(dt_rows)
        call dt_row_file
        ld (dt_cells),a
        ret

; A = row -> A = its first file (A * dt_cols). Destroys B, HL
dt_row_file:
        ld b,a
        inc b
        xor a
        ld hl,dt_cols
        jr .first
.add:
        add a,(hl)
.first:
        djnz .add
        ret

; A = file -> A = its row (A / dt_cols). Destroys C, HL
dt_file_row:
        ld c,0
        ld hl,dt_cols
.sub:
        sub (hl)
        jr c,.done
        inc c
        jr .sub
.done:
        ld a,c
        ret

; no window, no drive: the desk
dt_close:
        ld a,DT_CLOSED
        ld (dt_drive),a
        xor a
        ld (dt_shown),a
        ld (dt_count),a
        jp dt_redraw

; everything (also after a language change)
dt_redraw:
        call dt_draw_screen
        ld a,(dt_drive)
        inc a
        ret z
        jp dt_draw_window

dt_draw_screen:
        call ptr_hide
        ld a,UIP_DESK
        call ui_pen
        call gfx_cls
        call wall_draw              ; the desk's picture (shell/wall.asm)
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
        call dt_draw_drive
        ld a,(dt_m4)
        or a
        ret z
        ld a,2
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
        ld de,dt_line               ; "A:", "B:" or "DISK:"
        ld a,(dt_d)
        call file_drive_text
        xor a
        ld (de),a
        ld hl,DT_DRIVE_X + 16
        ld a,(dt_d)
        cp 2
        jr c,.label
        ld hl,DT_DRIVE_X + 4
.label:
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

; read the open drive, then draw the window (none: nothing)
dt_load:
        ld a,(dt_drive)
        cp DT_CLOSED
        ret z
        ld a,1
        ld (dt_shown),a
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
        ld a,(dt_drive)             ; the SD card: the folder, its last
        cp 2                        ; 20 characters
        jr c,.found
        ld hl,m4_path_e
        call ext_call
        ld hl,bank_buf
        ld bc,0
.end:
        ld a,(hl)
        or a
        jr z,.cut
        inc hl
        inc c
        jr .end
.cut:
        ld a,c
        sub 20
        jr c,.short
        ld c,a
        ld hl,bank_buf
        add hl,bc
        jr .keep
.short:
        ld hl,bank_buf
.keep:
        ld de,dt_path
        ld bc,21
        ldir
.found:
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
        call .box
        call ui_rect
        ld a,UIP_FRAME
        call .box
        call ui_frame
        ld a,UIP_SEL                ; title: "A: DATA  3 FILES",
        call .box                   ; "DISK:/GAMES/  3 FILES"
        ld a,12
        call ui_rect
        ld de,dt_line
        ld a,(dt_drive)
        call file_drive_text
        ld a,(dt_err)
        or a
        jr nz,.title
        ld a,(dt_drive)
        cp 2
        jr c,.disc
        ld hl,dt_path
.path:
        ld a,(hl)
        inc hl
        or a
        jr z,.count
        ld (de),a
        inc de
        jr .path
.disc:
        ld a," "
        call util_char
        ld a,(dt_fmt)
        or a
        ld a,MSG_FMT_DATA
        jr z,.format
        ld a,MSG_FMT_SYSTEM
.format:
        call util_msg
.count:
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
        ld hl,(dt_w)                ; no further than the X
        ld de,-24
        add hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        cp 39
        jr c,.fits
        ld a,39
.fits:
        ld e,a
        ld d,0
        ld hl,dt_line
        add hl,de
        ld (hl),0
        ld a,UIP_SELTEXT
        ld c,UIP_SEL
        call ui_colours
        ld a,2
        call dt_text_at
        call txt_print
        ld hl,(dt_wx)               ; the X that closes it
        ld de,(dt_w)
        add hl,de
        ld de,-16
        add hl,de
        ld de,(dt_wy)
        inc de
        inc de
        ld bc,dt_x_text
        call txt_print
        call dt_draw_bar
        call dt_draw_grip
        call dt_draw_cells
        ld a,(dt_err)               ; free space, or the error
        or a
        jr nz,.error
        ld a,(dt_count)
        or a
        ld a,MSG_NO_FILES
        jr z,.message
        ld de,dt_line
        ld a,(dt_drive)             ; (the SD card's free room is more
        cp 2                        ; than one byte of K says)
        jr nc,.end_line
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
.end_line:
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
        ld a,(dt_h)
        sub 12
        call dt_text_at
        jp txt_print
.box:
        ld (ui_fill_pen),a
        ld hl,(dt_wx)
        ld de,(dt_wy)
        ld bc,(dt_w)
        ld a,(dt_h)
        ret

; the corner that sizes the window: a small square, below on the right
dt_draw_grip:
        ld a,UIP_TEXT
        ld (ui_fill_pen),a
        call dt_grip_xy
        ld bc,6
        ld a,6
        jp ui_rect
; -> HL, DE: the grip's top left (8 pixels in from the corner)
dt_grip_xy:
        ld hl,(dt_wx)
        ld de,(dt_w)
        add hl,de
        ld de,-9
        add hl,de
        push hl
        ld hl,(dt_wy)
        ld a,(dt_h)
        sub 9
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        ret

; the scroll bar: the rows of files there are, the thumb where the
; window is among them
dt_draw_bar:
        call dt_bar_geometry
        ld a,UIP_BAR
        ld (ui_fill_pen),a
        call .track
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        call .track
        call ui_frame
        ld a,UIP_SEL
        ld (ui_fill_pen),a
        ld hl,(dt_bx)
        inc hl
        inc hl
        ld de,(dt_by)
        ld a,(dt_ty)
        add a,e
        ld e,a
        jr nc,.y
        inc d
.y:
        inc de
        ld bc,DT_BAR_W - 4
        ld a,(dt_tl)
        sub 2
        jp ui_rect
.track:
        ld hl,(dt_bx)
        ld de,(dt_by)
        ld bc,DT_BAR_W
        ld a,(dt_th)
        ret

; -> dt_bx, dt_by, dt_th: the bar; dt_ty, dt_tl: its thumb (in it)
dt_bar_geometry:
        ld hl,(dt_wx)
        ld de,(dt_w)
        add hl,de
        ld de,-(DT_BAR_W + 4)
        add hl,de
        ld (dt_bx),hl
        ld hl,(dt_wy)
        ld de,14
        add hl,de
        ld (dt_by),hl
        ld a,(dt_h)
        sub 28
        ld (dt_th),a
        ld (dt_tl),a
        xor a
        ld (dt_ty),a
        call dt_total_rows          ; all of them in the window: all bar
        ld hl,dt_rows
        cp (hl)
        ret c
        ret z
        ld (dt_tr),a
        ld a,(dt_top)
        call .part
        ld (dt_ty),a
        ld a,(dt_rows)
        call .part
        cp 4
        jr nc,.long
        ld a,4
.long:
        ld (dt_tl),a
        ret
; A = rows -> A = rows * dt_th / dt_tr
.part:
        ld l,a
        ld a,(dt_th)
        ld e,a
        ld d,0
        call dt_mul
        ld a,(dt_tr)
        ld e,a
        ld c,0
.div:
        or a
        sbc hl,de
        jr c,.done
        inc c
        jr .div
.done:
        ld a,c
        ret

; -> A = rows of files (dt_count / dt_cols, rounded up)
dt_total_rows:
        ld a,(dt_count)
        or a
        ret z
        dec a
        call dt_file_row
        inc a
        ret

; HL, DE = a click on the bar: up or down a window of rows
dt_bar_click:
        push de
        call dt_bar_geometry
        pop hl
        ld de,(dt_by)
        or a
        sbc hl,de
        ld a,(dt_ty)
        cp l                        ; above the thumb: up
        ld a,(dt_top)
        ld hl,dt_rows
        jr c,.down
        sub (hl)
        jr nc,.set
        xor a
        jr .set
.down:
        add a,(hl)                  ; (below it, or on it: down)
        push af
        call dt_total_rows          ; no further than the last rows
        ld hl,dt_rows
        sub (hl)
        jr nc,.last
        xor a
.last:
        ld c,a
        pop af
        cp c
        jr c,.set
        ld a,c
.set:
        ld (dt_top),a
        call dt_draw_bar
        jp dt_draw_cells

; the grip taken: a dashed outline (ext2.asm: drag_outline) follows the
; pointer in whole cells until the button goes up, then the window has
; that size
dt_resize:
        ld hl,(dt_wx)
        ld (dr_nx),hl
        ld hl,(dt_wy)
        ld (dr_ny),hl
        call .size
        call .outline
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
        call .outline               ; away from where it was
        ld hl,(ev_cur + 4)          ; columns: (x - wx - 12) / 72
        ld de,(dt_wx)
        ld bc,DT_CELL_W
        call .cells
        ld e,a
        ld a,DT_MAX_COLS
        cp e
        jr c,.cols
        ld a,e
.cols:
        cp 2
        jr nc,.cols_ok
        ld a,2
.cols_ok:
        ld (dt_cols),a
.wide:
        call dt_size                ; on the screen
        ld hl,(dt_wx)
        ld de,(dt_w)
        add hl,de
        ld de,384 + 1               ; (mode 1)
        or a
        sbc hl,de
        jr c,.rows
        ld hl,dt_cols
        dec (hl)
        jr .wide
.rows:
        ld hl,(ev_cur + 6)          ; rows: (y - wy - 11) / 38
        ld de,(dt_wy)
        ld bc,DT_CELL_H
        call .cells
        ld e,a
        ld a,DT_MAX_ROWS
        cp e
        jr c,.rows_set
        ld a,e
.rows_set:
        or a
        jr nz,.rows_ok
        inc a
.rows_ok:
        ld (dt_rows),a
.high:
        call dt_size
        ld hl,(dt_wy)
        ld a,(dt_h)
        ld e,a
        ld d,0
        add hl,de
        ld de,DT_KEYS_Y + 1
        or a
        sbc hl,de
        jr c,.sized
        ld hl,dt_rows
        dec (hl)
        jr .high
.sized:
        call .size
        pop af
        cp EV_PTR_UP
        jr z,.done
        call .outline
        jp .event
.done:
        call dt_scroll
        jp dt_redraw
.size:
        ld hl,(dt_w)
        ld (dr_w),hl
        ld a,(dt_h)
        ld (dr_h),a
        ret
.outline:
        ld hl,drag_outline
        jp ext2_call
; HL = pointer, DE = the window's edge, BC = a cell -> A = cells to it
.cells:
        or a
        sbc hl,de
        jr nc,.in
        ld hl,0
.in:
        ld e,c
        ld d,b
        srl d                       ; to the nearest: + half a cell
        rr e
        add hl,de
        ld de,12
        or a
        sbc hl,de
        jr nc,.count
        ld hl,0
.count:
        ld e,c
        ld d,b
        ld c,0
.sub:
        or a
        sbc hl,de
        jr c,.counted
        inc c
        jr .sub
.counted:
        ld a,c
        ret

; A = y in the window -> HL, DE: dt_line's place there, BC -> dt_line
dt_text_at:
        ld hl,(dt_wy)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld hl,(dt_wx)
        ld bc,8
        add hl,bc
        ld bc,dt_line
        ret

dt_draw_cells:
        xor a
.cell:
        push af
        call dt_draw_cell
        pop af
        inc a
        ld hl,dt_cells
        cp (hl)
        jr c,.cell
        ret

; A = cell on screen: the file there, if any
dt_draw_cell:
        ld (dt_k),a
        ld c,0                      ; column, row
        ld hl,dt_cols
.row:
        sub (hl)
        jr c,.col
        inc c
        jr .row
.col:
        add a,(hl)
        ld l,a
        ld h,0
        ld de,DT_CELL_W
        push bc
        call dt_mul
        call dt_cell0
        pop bc
        add hl,de
        ld (dt_cx),hl
        ld l,c
        ld h,0
        ld de,DT_CELL_H
        call dt_mul
        call dt_cell0
        add hl,bc
        ld (dt_cy),hl
        ld a,UIP_BAR                ; clear the cell
        ld (ui_fill_pen),a
        ld hl,(dt_cx)
        ld de,(dt_cy)
        ld bc,DT_CELL_W
        ld a,DT_CELL_H
        call ui_rect
        ld a,(dt_top)               ; file = top row * columns + cell
        call dt_row_file
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
        ld hl,(dt_ent)              ; a folder: a tab on its page
        ld de,M4_FOLDER
        add hl,de
        ld a,(hl)
        or a
        jr z,.named_file
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,(dt_cx)
        ld de,22
        add hl,de
        ld de,(dt_cy)
        ld bc,12
        ld a,2
        call ui_rect
.named_file:
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

; -> DE = x, BC = y of the first cell. Keeps HL
dt_cell0:
        push hl
        ld hl,(dt_wx)
        ld de,8
        add hl,de
        ex de,hl
        ld hl,(dt_wy)
        ld bc,16
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        ret

; dt_top so that the selection is on the screen -> carry if it moved
dt_scroll:
        ld a,(dt_sel)               ; row of the selection
        call dt_file_row
        ld b,a
        ld a,(dt_rows)
        dec a
        ld c,a
        ld a,(dt_top)
        cp b
        jr z,.done
        jr c,.below
        ld a,b                      ; above the screen
        jr .set
.below:
        add a,c
        cp b
        jr nc,.done
        ld a,b
        sub c
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
        jr nc,.same
        call dt_draw_bar
        jp dt_draw_cells
.same:
        push bc                     ; same screen: old and new cell
        ld a,(dt_top)
        call dt_row_file
        pop bc
        ld c,a
        ld a,b
        sub c
        push bc
        call dt_draw_cell
        pop bc
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
        jp z,dt_close               ; the open one again: closed
        ld b,(hl)
        ld (hl),a
        xor a
        ld (dt_sel),a
        ld a,b                      ; the one it was, then this one
        cp DT_CLOSED
        call nz,dt_draw_drive
        ld a,(dt_drive)
        call dt_draw_drive
        jp dt_load

; -> A = the drive after dt_drive (A:, B:, DISK with an M4 board)
dt_next:
        ld a,(dt_drive)
        inc a
        cp 2
        ret c
        jr nz,.first
        ld a,(dt_m4)
        or a
        ld a,2
        ret nz
.first:
        xor a
        ret

; ---------------------------------------------------------------------
dt_event:
        ld a,(ev_cur)               ; the screen saver: with a picture on
        cp EV_FRAME                 ; the desk, after DT_SAVER_FRAMES
        jr nz,.input                ; with nothing done, the picture
        ld a,(dt_saver)             ; alone; anything brings the
        or a                        ; Desktop back
        ret nz
        ld hl,(dt_idle)
        inc hl
        ld (dt_idle),hl
        ld de,DT_SAVER_FRAMES
        or a
        sbc hl,de
        ret c
        ld a,(cfg_data + CFG_WALL)
        inc a
        ret z
        ld a,(ui_open)
        cp UI_NONE
        ret nz
        ld a,1
        ld (dt_saver),a
        call ptr_hide
        ld a,UIP_DESK
        call ui_pen
        call gfx_cls
        jp wall_draw
.input:
        ld hl,0
        ld (dt_idle),hl
        ld a,(dt_saver)
        or a
        jr z,.awake
        xor a
        ld (dt_saver),a
        jp dt_redraw
.awake:
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
        ld e,a
        ld a,(dt_cols)
        ld d,a
        ld a,e
        cp KEY_DOWN
        jr z,.move
        ld a,d
        neg
        ld d,a
        ld a,e
        cp KEY_UP
        jr z,.move
        cp KEY_TAB
        jr nz,.not_tab
        call dt_next
        jp dt_open_drive
.not_tab:
        cp KEY_RETURN
        jp z,dt_run
        cp KEY_ENTER
        jp z,dt_run
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
        ld a,(dt_drive)             ; no window: only the drives
        cp DT_CLOSED
        jp z,.drive
        ld hl,(ev_cur + 4)          ; in the window? HL, DE: where in it
        ld de,(dt_wx)
        or a
        sbc hl,de
        jp c,.drive
        push hl
        ld de,(dt_w)
        sbc hl,de
        pop bc
        jp nc,.drive
        ld hl,(ev_cur + 6)
        ld de,(dt_wy)
        or a
        sbc hl,de
        jp c,.drive
        ld a,(dt_h)
        ld e,a
        ld d,0
        push hl
        sbc hl,de
        pop de
        jp nc,.drive
        ld h,b                      ; HL = x, DE = y in the window
        ld l,c
        ld a,d
        or a
        jr nz,.not_title
        ld a,e
        cp 12
        jr nc,.not_title
        push hl                     ; the title bar: its X closes
        ld de,(dt_w)
        ld bc,16
        ex de,hl
        or a
        sbc hl,bc
        ex de,hl
        or a
        sbc hl,de
        pop hl
        jp nc,dt_close
        ld hl,(dt_wx)               ; the rest drags the window
        ld de,(dt_wy)
        ld bc,(dt_w)
        ld a,(dt_h)
        call ui_drag
        ret nc
        ld (dt_wx),hl
        ld (dt_wy),de
        jp dt_redraw
.not_title:
        push de                     ; the grip: the window's size
        push hl
        ld de,(dt_w)
        ld bc,-11
        ex de,hl
        add hl,bc
        ex de,hl
        or a
        sbc hl,de
        pop hl
        pop de
        jr c,.not_corner
        ld a,(dt_h)
        sub 11
        cp e
        jp c,dt_resize
        ; the bar
        push de
        ld de,(dt_w)
        ld bc,-(DT_BAR_W + 4)
        ex de,hl
        add hl,bc
        ex de,hl
        or a
        sbc hl,de
        pop de
        jr c,.window
        ld hl,(ev_cur + 6)
        ex de,hl
        jp dt_bar_click
.not_corner:
        push de                     ; the bar?
        ld de,(dt_w)
        ld bc,-(DT_BAR_W + 4)
        ex de,hl
        add hl,bc
        ex de,hl
        or a
        sbc hl,de
        pop de
        jr c,.window
        ld hl,(ev_cur + 6)
        ex de,hl
        jp dt_bar_click
.drive:
        ld hl,(ev_cur + 4)          ; a drive icon?
        ld de,DT_DRIVE_X
        or a
        sbc hl,de
        ret c
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
        ld b,2                      ; B:, then DISK
.next_drive:
        inc a
        ld de,DT_DRIVE_STEP - DT_DRIVE_H
        sbc hl,de
        ret c
        ld de,DT_DRIVE_H
        sbc hl,de
        jr c,.on_drive
        djnz .next_drive
        ret
.on_drive:
        cp 2
        jr c,dt_open_drive_a
        ld c,a
        ld a,(dt_m4)
        or a
        ret z
        ld a,c
        jr dt_open_drive_a
.window:
        ld hl,(ev_cur + 4)          ; a cell?
        call dt_cell0
        or a
        sbc hl,de
        ret c
        ld de,DT_CELL_W
        ld c,0
.cx:
        or a
        sbc hl,de
        jr c,.cx_done
        inc c
        jr .cx
.cx_done:
        ld a,c
        ld hl,dt_cols
        cp (hl)
        ret nc
        ld (dt_k),a
        ld hl,(ev_cur + 6)
        call dt_cell0
        ld d,b
        ld e,c
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
        ld hl,dt_rows
        cp (hl)
        ret nc
        ld hl,dt_top                ; file = (top + row) * columns +
        add a,(hl)                  ; column
        call dt_row_file
        ld hl,dt_k
        add a,(hl)
        ld hl,dt_count
        cp (hl)
        ret nc
        ld hl,dt_sel
        cp (hl)
        jp nz,dt_select
        jr dt_run                   ; again on the selected file: open
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
        ld (dt_ent_sel),hl
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
        call dt_folder
        ld a,(dt_drive)
        jp z,file_open
        ld hl,m4_cd_e               ; a folder of the SD card: into it
        call ext_call
        jp c,sys_error
        xor a
        ld (dt_sel),a
        jp dt_load

; -> NZ if the selected file is a folder (an entry of the SD card)
dt_folder:
        ld hl,(dt_ent_sel)
        ld de,M4_FOLDER
        add hl,de
        ld a,(hl)
        or a
        ret

; the target is the next drive, which is not on the screen
dt_copy:
        call dt_selected
        ret c
        push af
        call dt_next
        ld (fi_target),a
        pop af
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
        db MSG_ITEM_OPEN, CMD_RUN, 0, 0
        db MSG_ITEM_INFO, CMD_INFO, "I", 0
        db MSG_ITEM_COPY_DRIVE, CMD_COPY, "C", 0
        db MSG_ITEM_DELETE, CMD_DELETE, "D", 0
        db MSG_ITEM_RENAME, CMD_RENAME, "N", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_REFRESH, CMD_REFRESH, "R", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_QUIT, CMD_QUIT, "Q", 0

; ---- state ----------------------------------------------------------
dt_drive:       db 0                ; the open drive
dt_m4:          db 0                ; 1: an M4 board, DISK its card
dt_path:        ds 21               ; the card's folder, for the title
dt_ent_sel:     dw 0
dt_count:       db 0
dt_sel:         db 0
dt_top:         db 0                ; first row on the screen
dt_err:         db 0
dt_free:        db 0
dt_fmt:         db 0
dt_d:           db 0
dt_idle:        dw 0                ; frames with nothing done
dt_saver:       db 0                ; 1: the screen saver is on
dt_k:           db 0
dt_i:           db 0
dt_cx:          dw 0
dt_cy:          dw 0
dt_ent:         dw 0
dt_colours:     dw 0
dt_name_colours: dw 0
dt_line:        ds 40
dt_w:           dw 0                ; the window's width and height
dt_h:           db 0
dt_cells:       db 0                ; columns * rows
dt_bx:          dw 0                ; its scroll bar, thumb
dt_by:          dw 0
dt_th:          db 0
dt_ty:          db 0
dt_tl:          db 0
dt_tr:          db 0                ; rows of files
dt_x_text:      db "X", 0
dt_vbn:         db "VBN"

        include "wall.asm"
