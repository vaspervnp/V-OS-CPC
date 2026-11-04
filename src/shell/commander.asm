; =====================================================================
; commander.asm - the Commander view (C): two file panels, A: and B:
;
; Mode 1. The left panel lists drive A:, the right one drive B:; ^G (or
; a click on its title) gives a panel the next drive, DISK too with an
; M4 board (its SD card: its folders, RETURN goes in, ".." up). Each
; shows the format (the card: the folder) and file count in its title,
; the files, and the free space. The active panel has a dark title and
; selection.
;   UP/DOWN          select (SHIFT: a page)
;   TAB, LEFT/RIGHT  other panel
;   RETURN/ENTER     file info: size, type, load address, first bytes
;   ^C copy to the other panel, ^D delete, ^N rename, ^R read both
;   discs again, ^L language, ^K keys, ^Q exit; ESC opens the menus
;   ^F FIND: a name with * and ? (README.*, *.TXT, NOTE?AD), looked
;                    for on A:, B: and DISK (its folder now); the
;                    active panel lists what was found, each with its
;                    drive, and RETURN goes to it on its drive (reading
;                    the panel again ends the list)
;   ^V SHOW THE TEXT: the selected file's first lines in the other panel
;   ^E COPY THE DISC: the active panel's disc onto the other's (A: and
;                    B:), track by track through bank 4, each track of
;                    the target formatted first as the source's (DATA
;                    or SYSTEM)
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
CM_FOUND_MAX    equ 64              ; #400 / 16
CM_ENT_DRIVE    equ 14              ; FIND: the drive, in an entry
CM_COLS         equ (CM_W - 8) / 8  ; characters on a row

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
        ld hl,m4_find               ; an M4 board: DISK too
        call ext_call
        sbc a,a
        inc a
        ld (cm_m4),a
        ld a,(sys_drive)            ; the file selected in the last view:
        cp 2                        ; on DISK, the right panel shows it
        jr c,.panel
        ld (cm_drv + 1),a
        ld a,1
.panel:
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
        jp z,cm_run
        cp KEY_ENTER
        jp z,cm_run
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
        jr nc,.rows
        ld a,(cm_active)            ; the title: the next drive
        jp cm_next_drive_a
.rows:
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
        jp z,cm_run
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
        cp CMD_DRIVE
        jp z,cm_next_drive
        cp CMD_RUN
        jp z,cm_run
        cp CMD_FIND
        jp z,cm_find
        cp CMD_PEEK
        jp z,cm_peek
        cp CMD_DCOPY
        jp z,cm_dcopy
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

; the current panel's drive for the disc calls -> A = it
cm_drive:
        ld hl,cm_drv
        call cm_at
        ld a,(hl)
        push af
        call fdc_select
        pop af
        ret

; the active panel's next drive: A:, B:, DISK (with an M4 board)
cm_next_drive:
        ld a,(cm_active)
cm_next_drive_a:                    ; A = panel
        call cm_set_p
        ld hl,cm_drv
        call cm_at
        ld a,(hl)
        inc a
        cp 2
        jr c,.set
        jr nz,.first
        ld a,(cm_m4)
        or a
        ld a,2
        jr nz,.set
.first:
        xor a
.set:
        ld (hl),a
        xor a
        ld hl,cm_sel
        call cm_at
        ld (hl),a
        ld a,(cm_p)
        jp cm_load

; the card's folder -> cm_folder: its last 9 characters (m4_path_e)
cm_path:
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
        ld hl,bank_buf
        ld a,c
        sub 9
        jr c,.keep
        ld c,a
        add hl,bc
.keep:
        ld de,cm_folder
        ld bc,10
        ldir
        jp cm_drive

; A = panel: read its drive's catalog into bank 5, then draw it
cm_load:
        call cm_set_p
        call cm_is_found            ; the found list ends
        jr nz,.not_found
        xor a
        ld (cm_found),a
.not_found:
        call cm_drive
        cp 2                        ; the card: its folder for the title
        call nc,cm_path
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
        call cm_draw_frame
        call cm_draw_title
        call cm_draw_rows
        ; free space on the last line
        ld hl,cm_err
        call cm_at
        ld a,(hl)
        or a
        ret nz
        ld de,cm_line
        call cm_is_found
        jr z,.end_line
        ld hl,cm_drv                ; (the card's free room is more than
        call cm_at                  ; one byte of K says)
        ld a,(hl)
        cp 2
        jr nc,.end_line
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
.end_line:
        xor a
        ld (de),a
        ld a,UIP_TEXT
        ld c,UIP_BAR
        call ui_colours
        ld de,CM_FREE_Y
        jp cm_print_line

; the current panel's frame, empty
cm_draw_frame:
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
        jp ui_frame

; -> Z: the current panel lists what FIND found
cm_is_found:
        ld a,(cm_found)
        dec a
        ld hl,cm_p
        cp (hl)
        ret

; "A: DATA  2 FILES", "DISK:/APPS/  2 FILES", dark when the panel is
; active
cm_draw_title:
        ld de,cm_line
        call cm_is_found
        jr nz,.drive
        ld a,MSG_FOUND              ; "FOUND  3 FILES"
        call util_msg
        jr .count
.drive:
        ld hl,cm_drv
        call cm_at
        ld a,(hl)
        push af
        call file_drive_text
        ld hl,cm_err
        call cm_at
        ld a,(hl)
        pop bc
        or a
        jr nz,.text
        ld a,b
        cp 2
        jr c,.disc
        ld hl,cm_folder
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
        ld hl,cm_fmt
        call cm_at
        ld a,(hl)
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
        jr nz,cm_title_line
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
cm_title_line:                      ; B, C = its pens
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
        ld de,cm_line
        call cm_is_found
        ld a,(cm_ent + CM_ENT_DRIVE)
        call z,file_drive_text      ; found: its drive first
        ld hl,cm_ent
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
        call cm_is_found
        ld a,(cm_ent + CM_ENT_DRIVE)
        ret z                       ; (no carry)
        ld hl,cm_drv
        call cm_at
        ld a,(hl)
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
        ld b,a
        call cm_is_found
        jr nz,.not_found
        ld hl,cm_drv                ; found: the panel on its drive, the
        call cm_at                  ; file selected (cm_load: file_find)
        ld (hl),b
        ld a,b
        cp 2
        call nc,cm_path
        ld a,(cm_p)
        jp cm_load
.not_found:
        ld a,(cm_ent + M4_FOLDER)
        or a
        ld a,b
        jp z,file_open
        ld hl,m4_cd_e               ; a folder of the card: into it, and
        call ext_call               ; both panels read again (both may
        jp c,sys_error              ; show the card)
        xor a
        ld hl,cm_sel
        call cm_at
        ld (hl),a
        jp cm_refresh

; the target is the other panel's drive
cm_copy:
        call cm_selected
        ret c
        push af
        ld a,(cm_active)
        xor 1
        ld (cm_p),a
        ld hl,cm_drv
        call cm_at
        ld a,(hl)
        ld (fi_target),a
        ld a,(cm_active)
        ld (cm_p),a
        pop af
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
        call cm_set_p
        call cm_drive
        call file_format
        ret c
        ld a,(cm_active)
        jp cm_load

; FIND: a name with * and ? -> cm_pat; the files that match on A:,
; B: and DISK (with an M4 board, the folder it is in), up to
; CM_FOUND_MAX, into the active panel's list, each with its drive
cm_find:
        ld a,MSG_FIND_T
        ld hl,cm_pat_in
        ld c,12
        call input_run
        ret c
        call cm_pattern
        ld a,(cm_active)
        call cm_set_p
        xor a
        ld (cm_n),a
        ld (cm_fd),a
.drive:
        ld a,(cm_fd)
        cp 2
        jr c,.read
        jr nz,.done
        ld a,(cm_m4)
        or a
        jr z,.done
        ld a,2
.read:
        call fdc_select
        call fs_catalog
        jr c,.next                  ; no disc there: none from it
        or a
        jr z,.next
        ld b,a
        ld hl,FS_CAT
.entry:
        push bc
        push hl
        call cm_match
        jr nz,.skip
        ld a,(cm_n)
        cp CM_FOUND_MAX
        jr nc,.skip
        ld de,bank_buf              ; to the list, with its drive
        ld bc,16
        ldir
        ld a,(cm_fd)
        ld (bank_buf + CM_ENT_DRIVE),a
        ld a,(cm_n)
        inc a
        ld (cm_n),a
        dec a
        ld l,a                      ; its place: n * 16
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
        ld d,a
        ld e,l
        ld hl,bank_buf
        ld bc,16
        ld a,CM_CAT_CFG
        call bank_put
.skip:
        pop hl
        ld de,16
        add hl,de
        pop bc
        djnz .entry
.next:
        ld hl,cm_fd
        inc (hl)
        jr .drive
.done:
        ld a,(cm_p)
        inc a
        ld (cm_found),a
        ld hl,cm_count
        call cm_at
        ld a,(cm_n)
        ld (hl),a
        xor a
        ld hl,cm_sel
        call cm_at
        ld (hl),a
        ld hl,cm_top
        call cm_at
        ld (hl),a
        ld hl,cm_err
        call cm_at
        ld (hl),a
        call cm_remember
        ld a,(cm_p)
        jp cm_draw_panel

; cm_pat_in ("NOTE*.T?T") -> cm_pat, 11 bytes as the catalog's names,
; ? for any character: * fills the rest of its part; with no "." any
; extension
cm_pattern:
        ld hl,cm_pat
        ld b,11
.space:
        ld (hl)," "
        inc hl
        djnz .space
        ld hl,cm_pat_in
        ld de,cm_pat
        ld b,8
        call .part
        ld a,(hl)
        or a
        ld b,3
        jr nz,.ext
.any:
        ld a,"?"
        ld (de),a
        inc de
        djnz .any
        ret
.ext:
        inc hl                      ; after the "."
        ld de,cm_pat + 8
        ; fall through
; HL -> the text, DE -> the part, B = its length: up to "." or the end
.part:
        ld a,(hl)
        or a
        ret z
        cp "."
        ret z
        inc hl
        cp "*"
        jr z,.star
        cp "a"                      ; capitals, as AMSDOS names are
        jr c,.put
        cp "z" + 1
        jr nc,.put
        sub 32
.put:
        dec b
        inc b
        jr z,.part                  ; too long: the rest left out
        ld (de),a
        inc de
        dec b
        jr .part
.star:
        ld a,b
        or a
        jr z,.part
        ld a,"?"
.fill:
        ld (de),a
        inc de
        djnz .fill
        jr .part

; HL -> a catalog entry -> Z if it is a file that matches cm_pat
cm_match:
        push hl
        ld bc,M4_FOLDER
        add hl,bc
        ld a,(hl)
        pop hl
        or a
        ret nz                      ; a folder
        push hl
        ld de,cm_pat
        ld b,11
.char:
        ld a,(de)
        cp "?"
        jr z,.ok
        cp (hl)
        jr nz,.no
.ok:
        inc hl
        inc de
        djnz .char
.no:
        pop hl
        ret

; SHOW THE TEXT: the selected file, loaded into bank 4, its first lines
; in the other panel (CR, LF or CR LF end a line, ^Z the text; what
; does not fit is left out), until it is drawn again
cm_peek:
        call cm_selected
        ret c
        ld b,a
        ld a,(cm_ent + M4_FOLDER)
        or a
        ret nz
        ld a,b
        call fdc_select
        ld hl,file_name
        ld de,BUF_ADDR
        ld c,BUF_CFG
        call fs_load
        jp c,sys_error
        ld (cm_rd_left),bc
        ld hl,BUF_ADDR
        ld (cm_rd_at),hl
        xor a
        ld (cm_rd_n),a
        ld a,(cm_active)
        xor 1
        call cm_set_p
        call cm_draw_frame
        ld de,cm_line               ; its name for a title
        ld hl,file_name
        call util_fcb_text
        xor a
        ld (de),a
        ld bc,UIP_DESKTEXT * 256 + UIP_DESK
        call cm_title_line
        ld a,UIP_TEXT
        ld c,UIP_BAR
        call ui_colours
        ld hl,CM_ROWS_Y + 1
        ld b,CM_ROWS + 1
.line:
        push bc
        push hl
        ld de,cm_line
        ld c,CM_COLS
.char:
        call cm_getc
        jr c,.end
        cp 26                       ; ^Z: the end of a text
        jr z,.over
        cp 10
        jr z,.end
        cp 13
        jr z,.cr
        cp 9
        jr nz,.not_tab
        ld a," "
.not_tab:
        cp " "
        jr nc,.shown
        ld a,"."
.shown:
        dec c
        inc c
        jr z,.char                  ; past the panel's width
        ld (de),a
        inc de
        dec c
        jr .char
.over:
        ld hl,0                     ; nothing after it
        ld (cm_rd_left),hl
        jr .end
.cr:
        call cm_getc                ; CR LF: one end
        jr c,.end
        cp 10
        jr z,.end
        ld hl,cm_rd_n               ; not LF: it is the next line's
        inc (hl)
        ld hl,(cm_rd_at)
        dec hl
        ld (cm_rd_at),hl
        ld hl,(cm_rd_left)
        inc hl
        ld (cm_rd_left),hl
.end:
        xor a
        ld (de),a
        pop de
        push de
        call cm_print_line
        pop hl
        ld bc,10
        add hl,bc
        pop bc
        djnz .line
        ret

; -> A = the next byte of the file in bank 4, 32 at a time through
; bank_buf; carry at its end
cm_getc:
        ld hl,(cm_rd_left)
        ld a,h
        or l
        scf
        ret z
        dec hl
        ld (cm_rd_left),hl
        ld hl,cm_rd_n
        ld a,(hl)
        or a
        jr nz,.have
        push bc
        push de
        ld hl,(cm_rd_at)
        ld de,32
        or a
        sbc hl,de
        add hl,de
        ld de,bank_buf
        ld bc,32
        ld a,BUF_CFG
        call bank_get
        pop de
        pop bc
        ld hl,cm_rd_n
        ld (hl),32
.have:
        dec (hl)
        ld a,32 - 1
        sub (hl)
        ld hl,bank_buf
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ld hl,(cm_rd_at)
        inc hl
        ld (cm_rd_at),hl
        or a
        ret

; COPY THE DISC: asked first ("A: > B:?"); a track at a time, its 9
; sectors into bank 4 from the source, then the target's track
; formatted and written
cm_dcopy:
        ld a,(cm_active)
        call cm_set_p
        ld hl,cm_drv
        call cm_at
        ld a,(hl)
        ld (cm_src),a
        ld a,(cm_active)            ; the other panel's
        xor 1
        ld e,a
        ld d,0
        ld hl,cm_drv
        add hl,de
        ld a,(hl)
        ld (cm_tgt),a
        ld a,(cm_src)               ; A: and B: only, not the same
        ld b,a
        ld a,(cm_tgt)
        cp b
        ld a,37                     ; IT IS ON THAT DRIVE ALREADY
        jp z,sys_error
        ld a,(cm_tgt)
        or b
        cp 2
        ld a,38                     ; not the SD card
        jp nc,sys_error
        ld de,dlg_custom            ; COPY THE DISC|A: > B:?|...
        ld a,MSG_ITEM_DCOPY
        call util_msg
        call file_newline
        ld a,(cm_src)
        call file_drive_text
        ld a," "
        call util_char
        ld a,">"
        call util_char
        ld a," "
        call util_char
        ld a,(cm_tgt)
        call file_drive_text
        ld a,"?"
        call util_char
        call file_newline
        ld a,MSG_DCOPY_LOST
        call file_ask
        ret c
        ld a,MSG_COPYING
        call ui_busy
        call .copy
        push af
        call ui_restore
        pop af
        call c,sys_error
        jp cm_refresh
.copy:
        ld a,(cm_src)               ; its format: track 0's first sector
        call fdc_select
        ld de,#00C1                 ; DATA
        ld hl,fs_buf
        call fdc_read
        ld a,#C1
        jr nc,.base
        ld de,#0041                 ; SYSTEM
        ld hl,fs_buf
        call fdc_read
        ld a,#41
        jr nc,.base
        ld a,6                      ; UNKNOWN FORMAT
        scf
        ret
.base:
        ld (cm_base),a
        xor a
.track:
        ld (cm_trk),a
        ld a,(cm_src)
        call fdc_select
        ld hl,BUF_ADDR
        ld (cm_at_buf),hl
        ld b,9
.read:
        push bc
        call cm_sector              ; -> D, E
        ld hl,fs_buf
        call fdc_read
        jr c,.failed
        ld hl,fs_buf
        ld de,(cm_at_buf)
        ld bc,512
        ld a,BUF_CFG
        call bank_put
        call cm_next_buf
        pop bc
        djnz .read
        ld a,(cm_tgt)
        call fdc_select
        ld a,(cm_trk)
        ld d,a
        ld a,(cm_base)
        ld e,a
        call fdc_format
        ret c
        ld hl,BUF_ADDR
        ld (cm_at_buf),hl
        ld b,9
.write:
        push bc
        ld hl,(cm_at_buf)
        ld de,fs_buf
        ld bc,512
        ld a,BUF_CFG
        call bank_get
        pop bc
        push bc
        call cm_sector
        ld hl,fs_buf
        call fdc_write
        jr c,.failed
        call cm_next_buf
        pop bc
        djnz .write
        ld a,(cm_trk)
        inc a
        cp 40
        jr c,.track
        or a
        ret
.failed:
        pop bc
        ret

; B = 9..1 -> D = cm_trk, E = its sector's ID
cm_sector:
        ld a,(cm_trk)
        ld d,a
        ld a,(cm_base)
        add a,9
        sub b
        ld e,a
        ret
cm_next_buf:
        ld hl,(cm_at_buf)
        ld de,512
        add hl,de
        ld (cm_at_buf),hl
        ret

; ---- menus ----------------------------------------------------------
cm_bar:
        db 3
        dw cm_menu_file, menu_view, menu_help
cm_menu_file:
        db MSG_MENU_FILE, 14
        db MSG_ITEM_OPEN, CMD_RUN, 0, 0
        db MSG_ITEM_INFO, CMD_INFO, "I", 0
        db MSG_ITEM_PEEK, CMD_PEEK, "V", 0
        db MSG_ITEM_FIND, CMD_FIND, "F", 0
        db MSG_ITEM_DCOPY, CMD_DCOPY, "E", 0
        db MSG_ITEM_COPY, CMD_COPY, "C", 0
        db MSG_ITEM_DELETE, CMD_DELETE, "D", 0
        db MSG_ITEM_RENAME, CMD_RENAME, "N", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_REFRESH, CMD_REFRESH, "R", 0
        db MSG_ITEM_NEXT_DRIVE, CMD_DRIVE, "G", 0
        db MSG_ITEM_FORMAT, CMD_FORMAT, 0, 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_QUIT, CMD_QUIT, "Q", 0

; ---- state ----------------------------------------------------------
cm_active:      db 0                ; panel with the selection
cm_drv:         db 0, 1             ; per panel: its drive (2: DISK)
cm_m4:          db 0                ; 1: an M4 board
cm_folder:      ds 10               ; the card's folder: its last 9
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
cm_found:       db 0                ; 1 + the panel FIND filled, or 0
cm_src:         db 0                ; COPY THE DISC: the drives,
cm_tgt:         db 0
cm_base:        db 0                ; the first sector's ID,
cm_trk:         db 0                ; the track,
cm_at_buf:      dw 0                ; where in bank 4
cm_fd:          db 0                ; FIND: the drive it reads
cm_pat_in:      db "*.TXT", 0       ; what was typed (12 + 2)
                ds 8
cm_pat:         ds 11
cm_rd_at:       dw 0                ; SHOW THE TEXT: the next byte in
cm_rd_left:     dw 0                ; bank 4, how many are left, and
cm_rd_n:        db 0                ; how many in bank_buf
