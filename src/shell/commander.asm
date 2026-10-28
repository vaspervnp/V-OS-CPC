; =====================================================================
; commander.asm - the Commander view (C): two file panels, A: and B:
;
; Mode 1. The left panel lists drive A:, the right one drive B:. Each
; shows the format and file count in its title, the files, and the free
; space. The active panel has a dark title and selection.
;   UP/DOWN          select (SHIFT: a page)
;   TAB, LEFT/RIGHT  other panel
;   RETURN/ENTER     file info: size, type, load address, first bytes
;   ^C copy to the other panel, ^D delete, ^N rename, ^R read both
;   discs again, ^L language, ^K keys, ^Q exit; ESC opens the menus
;   mouse            click a file to select it, click it again for info
; An overlay (kernel/view.asm). The panel lists are kept in bank 7
; after the language pack, so switching panels needs no disc access;
; the cursor keys select files, not move the pointer.
; =====================================================================

CM_ROWS         equ 20
CM_W            equ 192             ; panel width, two side by side
CM_Y            equ 16
CM_ROWS_Y       equ CM_Y + 14
CM_H            equ 14 + CM_ROWS * 10 + 14
CM_FREE_Y       equ CM_Y + CM_H - 12
CM_KEYS_Y       equ GFX_H - 10
CM_CAT_CFG      equ LISTS_CFG       ; #400 bytes per panel
CM_CAT_ADDR     equ LISTS_ADDR

        jp cm_init
        jp cm_event
        jp cm_redraw
        db "VV", VIEW_COMMANDER

; ---------------------------------------------------------------------
; cm_init - mode 1, menus, read both drives
; ---------------------------------------------------------------------
cm_init:
        ld hl,cm_bar
        call ui_set_bar
        ld hl,ui_no_widgets
        call ui_set_widgets
        xor a
        ld (ptr_keys_on),a
        ld a,(sys_drive)            ; the file selected in the last view
        ld (cm_active),a
        ld a,1
        call ui_set_mode
        ld hl,palette_mode1
        call ga_set_palette
        ld a,2                      ; pointer outline pen
        ld (ptr_pen_out),a
        call ptr_clamp
        call cm_draw_screen
        ; fall through
cm_refresh:
        xor a
        call cm_load
        ld a,1
        jp cm_load

; screen without the panels' contents
cm_draw_screen:
        call ptr_hide
        ld a,UIP_DESK
        call ui_pen
        call gfx_cls
        call ui_draw_bar
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld a,MSG_KEYS_BAR
        call lang_msg
        ld b,h
        ld c,l
        ld hl,0
        ld de,CM_KEYS_Y
        jp txt_print

; everything again (after a language change)
cm_redraw:
        call cm_draw_screen
        xor a
        call cm_draw_panel
        ld a,1
        jp cm_draw_panel

; ---------------------------------------------------------------------
; cm_event - ev_cur from the main loop
; ---------------------------------------------------------------------
cm_event:
        ld a,(ui_open)              ; menus handle their own keys
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
        jp cm_command
.key:
        ld a,(ev_cur + 3)           ; SHIFT: a page at a time
        and MOD_SHIFT
        ld d,1
        jr z,.step
        ld d,CM_ROWS
.step:
        ld a,(ev_cur + 1)
        cp KEY_DOWN
        jp z,cm_move
        cp KEY_UP
        jr nz,.not_up
        xor a
        sub d
        ld d,a
        jp cm_move
.not_up:
        cp KEY_LEFT
        ld b,0
        jr z,.panel
        cp KEY_RIGHT
        ld b,1
        jr z,.panel
        cp KEY_TAB
        jr nz,.not_tab
        ld a,(cm_active)
        xor 1
        ld b,a
.panel:
        ld a,(cm_active)
        cp b
        ret z
        ld a,b
        jp cm_activate
.not_tab:
        cp KEY_RETURN
        jp z,cm_info
        cp KEY_ENTER
        jp z,cm_info
        jr .ui                      ; ESC, CONTROL shortcuts
.click:
        ld hl,(ev_cur + 6)
        ld de,UI_BAR_H
        or a
        sbc hl,de
        jr c,.ui                    ; the menu bar
        ld hl,(ev_cur + 4)          ; which panel?
        ld de,CM_W
        or a
        sbc hl,de
        ld a,0
        jr c,.side
        inc a
.side:
        ld hl,cm_active
        cp (hl)
        ld b,1                      ; B = 1: the panel was already active
        jr z,.same_panel
        dec b
        push bc
        call cm_activate
        pop bc
.same_panel:
        ld hl,(ev_cur + 6)          ; which row?
        ld de,CM_ROWS_Y
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        ld c,0
.row:
        sub 10
        jr c,.found
        inc c
        jr .row
.found:
        ld a,c
        cp CM_ROWS
        ret nc
        ld a,(cm_active)
        push bc
        call cm_set_p
        pop bc
        ld hl,cm_top
        call cm_at
        ld a,c
        add a,(hl)                  ; file number
        ld hl,cm_count
        call cm_at
        cp (hl)
        ret nc
        ld hl,cm_sel
        call cm_at
        cp (hl)
        jp nz,cm_select
        dec b                       ; second click on the selected file
        jp z,cm_info
        ret

; A = CMD_*
cm_command:
        cp CMD_REFRESH
        jp z,cm_refresh
        cp CMD_INFO
        jp z,cm_info
        cp CMD_COPY
        jp z,cm_copy
        cp CMD_DELETE
        jp z,cm_delete
        cp CMD_RENAME
        jp z,cm_rename
        cp CMD_FORMAT
        jp z,cm_format
        cp CMD_RUN
        jp z,cm_run
        jp view_command

; ---------------------------------------------------------------------
; panels
; ---------------------------------------------------------------------

; A = panel: current panel for the routines below
cm_set_p:
        ld (cm_p),a
        ld hl,0
        or a
        jr z,.x
        ld hl,CM_W
.x:
        ld (cm_px),hl
        ret

; HL = per-panel array -> HL = its byte for the current panel.
; Preserves A, BC, DE
cm_at:
        push af
        ld a,(cm_p)
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        pop af
        ret

; the current panel's drive for the disc calls
cm_drive:
        ld a,(cm_p)
        jp fdc_select

; A = panel: read its drive's catalog into bank 5, then draw it
cm_load:
        call cm_set_p
        call cm_drive
        call fs_catalog
        jr c,.failed
        ld (cm_n),a
        ld a,(cm_p)                 ; the active panel: the selected file
        ld hl,cm_active
        cp (hl)
        jr nz,.listed
        call file_find
        jr c,.listed
        ld hl,cm_sel
        call cm_at
        ld (hl),a
.listed:
        ld a,(cm_n)
        ld l,a                      ; count * 16 bytes to bank 7
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld a,b
        or c
        jr z,.copied
        ld a,(cm_p)
        add a,a
        add a,a
        add a,CM_CAT_ADDR >> 8
        ld d,a
        ld e,0
        ld hl,FS_CAT
        ld a,CM_CAT_CFG
        call bank_put
.copied:
        call fs_free_k
        ld hl,cm_free
        call cm_at
        ld (hl),a
        ld a,(fs_reserved)
        ld hl,cm_fmt
        call cm_at
        ld (hl),a
        ld a,(cm_n)
        ld c,0
        jr .store
.failed:
        ld c,a                      ; the error is shown in the panel
        xor a
.store:
        ld hl,cm_count
        call cm_at
        ld (hl),a
        ld b,a
        ld a,c
        ld hl,cm_err
        call cm_at
        ld (hl),a
        ld hl,cm_sel                ; selection still inside the list
        call cm_at
        ld a,(hl)
        cp b
        jr c,.sel_ok
        ld a,b
        or a
        jr z,.sel
        dec a
.sel:
        ld (hl),a
.sel_ok:
        sub CM_ROWS - 1             ; and on the screen
        jr nc,.top
        xor a
.top:
        ld hl,cm_top
        call cm_at
        ld (hl),a
        ld a,(cm_p)
        ; fall through

; A = panel: frame, title, rows, free space
cm_draw_panel:
        call cm_set_p
        ld a,UIP_BAR
        ld (ui_fill_pen),a
        ld hl,(cm_px)
        ld de,CM_Y
        ld bc,CM_W
        ld a,CM_H
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,(cm_px)
        ld de,CM_Y
        ld bc,CM_W
        ld a,CM_H
        call ui_frame
        call cm_draw_title
        call cm_draw_rows
        ; free space on the last line
        ld hl,cm_err
        call cm_at
        ld a,(hl)
        or a
        ret nz
        ld de,cm_line
        ld a,MSG_FREE
        call util_msg
        ld a," "
        call util_char
        ld hl,cm_free
        call cm_at
        ld l,(hl)
        ld h,0
        call util_dec
        ld a,"K"
        call util_char
        xor a
        ld (de),a
        ld a,UIP_TEXT
        ld c,UIP_BAR
        call ui_colours
        ld de,CM_FREE_Y
        jr cm_print_line

; "A: DATA  2 FILES", dark when the panel is active
cm_draw_title:
        ld de,cm_line
        ld a,(cm_p)
        add a,"A"
        call util_char
        ld a,":"
        call util_char
        ld hl,cm_err
        call cm_at
        ld a,(hl)
        or a
        jr nz,.text
        ld a," "
        call util_char
        ld hl,cm_fmt
        call cm_at
        ld a,(hl)
        or a
        ld a,MSG_FMT_DATA
        jr z,.format
        ld a,MSG_FMT_SYSTEM
.format:
        call util_msg
        ld a," "
        call util_char
        call util_char
        ld hl,cm_count
        call cm_at
        ld l,(hl)
        ld h,0
        call util_dec
        ld a," "
        call util_char
        ld a,MSG_FILES
        call util_msg
.text:
        xor a
        ld (de),a
        ld bc,UIP_DESKTEXT * 256 + UIP_DESK
        ld a,(cm_active)
        ld hl,cm_p
        cp (hl)
        jr nz,.colours
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        push bc
        ld a,c
        ld (ui_fill_pen),a
        ld hl,(cm_px)
        ld de,CM_Y
        ld bc,CM_W
        ld a,12
        call ui_rect
        pop bc
        ld a,b
        call ui_colours
        ld de,CM_Y + 2
        ; fall through

; DE = y: cm_line at the panel's text column
cm_print_line:
        ld hl,(cm_px)
        ld bc,8
        add hl,bc
        ld bc,cm_line
        jp txt_print

cm_draw_rows:
        xor a
.row:
        push af
        call cm_draw_row
        pop af
        inc a
        cp CM_ROWS
        jr c,.row
        ret

; A = row on screen of the current panel
cm_draw_row:
        ld (cm_r),a
        ld l,a                      ; y = CM_ROWS_Y + row * 10
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld de,CM_ROWS_Y
        add hl,de
        ld (cm_ry),hl
        ld hl,cm_top                ; file = top + row
        call cm_at
        add a,(hl)
        ld (cm_i),a
        ld bc,UIP_TEXT * 256 + UIP_BAR
        ld hl,cm_count
        call cm_at
        cp (hl)
        jr nc,.colours              ; no file here
        ld hl,cm_sel
        call cm_at
        cp (hl)
        jr nz,.colours
        ld bc,UIP_DESKTEXT * 256 + UIP_DESK     ; inactive panel
        ld a,(cm_active)
        ld hl,cm_p
        cp (hl)
        jr nz,.colours
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        push bc
        ld a,c
        ld (ui_fill_pen),a
        ld hl,(cm_px)
        ld de,4
        add hl,de
        ld de,(cm_ry)
        ld bc,CM_W - 8
        ld a,10
        call ui_rect
        pop bc
        ld a,b
        call ui_colours
        ld hl,cm_err                ; text: error, "no files" or the file
        call cm_at
        ld a,(hl)
        or a
        jr z,.no_error
        ld b,a
        ld a,(cm_i)
        or a
        ret nz
        ld a,b
        add a,MSG_ERR_1 - 1
        jr .message
.no_error:
        ld a,(cm_i)
        ld hl,cm_count
        call cm_at
        cp (hl)
        jr c,.file
        or a
        ret nz
        ld a,MSG_NO_FILES
.message:
        ld de,cm_line
        call util_msg
        xor a
        ld (de),a
        jr .print
.file:
        call cm_entry
        ld hl,cm_ent
        ld de,cm_line
        call util_cat_row
.print:
        ld de,(cm_ry)
        inc de
        jp cm_print_line

; A = file of the current panel -> its catalog entry in cm_ent
cm_entry:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(cm_p)
        add a,a
        add a,a
        add a,CM_CAT_ADDR >> 8
        add a,h
        ld h,a
        ld de,bank_buf
        ld bc,16
        ld a,CM_CAT_CFG
        call bank_get
        ld hl,bank_buf
        ld de,cm_ent
        ld bc,16
        ldir
        ret

; A = panel to make active
cm_activate:
        ld (cm_active),a
        call cm_remember
        xor a
        call .redraw
        ld a,1
.redraw:
        call cm_set_p
        call cm_draw_title
        jp cm_draw_rows

; D = steps (signed) in the active panel
cm_move:
        ld a,(cm_active)
        call cm_set_p
        ld hl,cm_count
        call cm_at
        ld a,(hl)
        or a
        ret z
        ld c,a
        ld hl,cm_sel
        call cm_at
        ld a,(hl)
        add a,d
        bit 7,d
        jr nz,.back
        cp c
        jr c,.go
        ld a,c                      ; past the end: the last file
        dec a
        jr .go
.back:
        jr c,.go                    ; no borrow: still >= 0
        xor a
.go:
        cp (hl)
        ret z
        ; fall through

; A = file to select in the current panel; scrolls when needed
cm_select:
        ld hl,cm_sel
        call cm_at
        ld b,(hl)                   ; old
        ld (hl),a
        push af
        push bc
        call cm_remember
        pop bc
        pop af
        ld c,a
        ld hl,cm_top
        call cm_at
        cp (hl)
        jr c,.up
        ld a,(hl)
        add a,CM_ROWS
        ld d,a
        ld a,c
        cp d
        jr nc,.down
        ld a,b                      ; same page: old and new row only
        sub (hl)
        call cm_draw_row
        ld hl,cm_top
        call cm_at
        ld a,(hl)
        ld hl,cm_sel
        call cm_at
        neg
        add a,(hl)
        jp cm_draw_row
.up:
        ld (hl),c
        jp cm_draw_rows
.down:
        ld a,c
        sub CM_ROWS - 1
        ld (hl),a
        jp cm_draw_rows

; active panel's selected file -> file_name, A = its drive; carry if
; the panel is empty
cm_selected:
        ld a,(cm_active)
        call cm_set_p
        ld hl,cm_count
        call cm_at
        ld a,(hl)
        or a
        scf
        ret z
        ld hl,cm_sel
        call cm_at
        ld a,(hl)
        call cm_entry
        ld hl,cm_ent
        ld de,file_name
        ld bc,11
        ldir
        ld a,(cm_p)
        or a
        ret

; the active panel's selection, for the next view
cm_remember:
        ld a,(cm_p)
        push af
        call cm_selected
        pop bc
        jr c,.back
        ld (sys_drive),a
.back:
        ld a,b
        jp cm_set_p

; ---------------------------------------------------------------------
; file commands (kernel/files.asm); afterwards the changed drive is
; read again
; ---------------------------------------------------------------------
cm_info:
        call cm_selected
        ret c
        jp file_info

cm_run:
        call cm_selected
        ret c
        jp app_request

cm_copy:
        call cm_selected
        ret c
        call file_copy
        ld a,(cm_active)            ; the target changed, even on failure
        xor 1
        jp cm_load

cm_delete:
        call cm_selected
        ret c
        call file_delete
        ret c
        ld a,(cm_active)
        jp cm_load

cm_rename:
        call cm_selected
        ret c
        call file_rename
        ret c
        ld a,(cm_active)
        jp cm_load

; format the active panel's drive
cm_format:
        ld a,(cm_active)
        call file_format
        ret c
        ld a,(cm_active)
        jp cm_load

; ---- menus ----------------------------------------------------------
cm_bar:
        db 3
        dw cm_menu_file, menu_view, menu_help
cm_menu_file:
        db MSG_MENU_FILE, 10
        db MSG_ITEM_RUN, CMD_RUN, 0, 0
        db MSG_ITEM_INFO, CMD_INFO, 0, 0
        db MSG_ITEM_COPY, CMD_COPY, "C", 0
        db MSG_ITEM_DELETE, CMD_DELETE, "D", 0
        db MSG_ITEM_RENAME, CMD_RENAME, "N", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_REFRESH, CMD_REFRESH, "R", 0
        db MSG_ITEM_FORMAT, CMD_FORMAT, 0, 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_QUIT, CMD_QUIT, "Q", 0

; ---- state ----------------------------------------------------------
cm_active:      db 0                ; panel with the selection
cm_p:           db 0                ; panel the routines work on
cm_px:          dw 0
cm_count:       ds 2                ; per panel (index cm_p)
cm_sel:         ds 2
cm_top:         ds 2
cm_err:         ds 2                ; 0 or the error of the last read
cm_free:        ds 2
cm_fmt:         ds 2                ; reserved tracks: 0 DATA, 2 SYSTEM
cm_n:           db 0
cm_r:           db 0
cm_i:           db 0
cm_ry:          dw 0
cm_ent:         ds 16
cm_line:        ds 50
