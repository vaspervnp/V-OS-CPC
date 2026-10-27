; =====================================================================
; kernel.asm - kernel entry and the M4 desktop test
;
; A small desktop built with the UI toolkit (src/ui):
;   menu bar   FILE: Open ^O, Save test file ^S, Delete ^D, Disc info ^I,
;                    Exit to BASIC ^Q
;              VIEW: Mode 1, Mode 0, Switch language ^L
;              HELP: Keys ^K, About V-OS
;   buttons    About, Mode 0/1, Keys (TAB moves the focus)
;   status     the last command
; Open loads the chosen file into bank 4 and shows its header and first
; bytes; Save writes VOSTEST.TXT; Delete asks first. All go through the
; own FDC driver and file system (drivers/fdc.asm, kernel/fs.asm).
; Exit asks before restarting the CPC; Switch language flips the UI
; between English and the pack.
; =====================================================================

CMD_SAVE        equ 1
CMD_OPEN        equ 2
CMD_QUIT        equ 3
CMD_MODE1       equ 4
CMD_MODE0       equ 5
CMD_LANG        equ 6
CMD_KEYS        equ 7
CMD_ABOUT       equ 8
CMD_TOGGLE      equ 9
CMD_DELETE      equ 10
CMD_DISC        equ 11

VIEW_BANK_CFG   equ #C4             ; Open loads files here, at #4000
VIEW_BYTES      equ 18              ; first bytes shown

HEADING_Y       equ 24
HINT_Y          equ 38
BUTTONS_Y       equ 64
STATUS_Y        equ GFX_H - 24

kernel_entry:
        di
        ld sp,STACK_TOP
        im 1
        call gfx_init
        ld hl,palette_black         ; nothing to see while the disc loads
        call ga_set_palette
        ei
        call fdc_init
        call lang_init              ; GREEK.LNG from the disc
        ld hl,app_bar
        call ui_set_bar
        ld a,1
        call app_set_mode
        call ptr_show

.main:
        call wait_frame
.events:
        call ev_get
        jr z,.idle
        call ui_event
        or a
        call nz,app_command
        jr .events
.idle:
        call ptr_update
        jr .main

; ---------------------------------------------------------------------
; app_set_mode - A = 0 or 1: switch mode and redraw everything
; ---------------------------------------------------------------------
app_set_mode:
        ld (app_mode),a
        call ptr_hide
        ld a,(app_mode)
        call ui_set_mode
        ld a,(app_mode)
        or a
        ld hl,palette_mode0
        ld de,app_widgets0
        ld a,0                      ; pointer outline pen
        jr z,.set
        ld hl,palette_mode1
        ld de,app_widgets1
        ld a,2
.set:
        ld (ptr_pen_out),a
        push de
        call ga_set_palette
        pop hl
        ld a,(ui_focus)             ; same focus in the other layout
        push af
        call ui_set_widgets
        pop af
        ld (ui_focus),a
        call ptr_clamp
        ; fall through

app_redraw:
        ld a,UIP_DESK
        call ui_pen
        call gfx_cls
        call ui_draw_bar
        ld a,UIP_HEAD
        ld c,UIP_DESK
        call ui_colours
        ld a,MSG_HEADING
        call lang_msg
        ld b,h
        ld c,l
        ld hl,8
        ld de,HEADING_Y
        call txt_print
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld a,MSG_HINT
        call lang_msg
        ld b,h
        ld c,l
        ld hl,8
        ld de,HINT_Y
        call txt_print
        call ui_draw_widgets
        ; fall through

; "LAST COMMAND" and the text of app_last below it
app_draw_status:
        ld a,UIP_DESK
        ld (ui_fill_pen),a
        ld hl,0
        ld de,STATUS_Y
        ld bc,(gfx_width)
        ld a,20
        call ui_rect
        ld a,UIP_HEAD
        ld c,UIP_DESK
        call ui_colours
        ld a,MSG_STATUS
        call lang_msg
        ld b,h
        ld c,l
        ld hl,8
        ld de,STATUS_Y
        call txt_print
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld a,(app_last)
        ld hl,app_cmd_msgs
        call tbl_a
        call lang_msg
        ld b,h
        ld c,l
        ld hl,8
        ld de,STATUS_Y + 12
        jp txt_print

; ---------------------------------------------------------------------
; app_command - A = CMD_*
; ---------------------------------------------------------------------
app_command:
        ld (app_last),a
        cp CMD_OPEN
        jp z,app_open
        cp CMD_SAVE
        jp z,app_save
        cp CMD_DELETE
        jp z,app_delete
        cp CMD_DISC
        jp z,app_disc
        cp CMD_QUIT
        jr z,.quit
        cp CMD_MODE1
        jr z,.mode1
        cp CMD_MODE0
        jr z,.mode0
        cp CMD_TOGGLE
        jr z,.toggle
        cp CMD_LANG
        jr z,.lang
        cp CMD_KEYS
        jr z,.keys
        cp CMD_ABOUT
        jr z,.about
        ret
.keys:
        ld hl,dlg_keys
        jr .dialog
.about:
        ld hl,dlg_about
.dialog:
        call dialog_run
        jp app_draw_status
.quit:
        ld hl,dlg_quit
        call dialog_run
        or a                        ; 0 = YES
        jp nz,app_draw_status
        di                          ; restart: lower ROM back at #0000
        ld bc,GA_PORT + GA_RAMCFG
        out (c),c
        ld bc,GA_PORT + GA_RMR + GA_RMR_HIROM_OFF + 1
        out (c),c
        rst 0
.mode1:
        ld a,1
        jp app_set_mode
.mode0:
        xor a
        jp app_set_mode
.toggle:
        ld a,(app_mode)
        xor 1
        jp app_set_mode
.lang:
        ld a,(lang_loaded)
        or a
        jp z,app_draw_status
        ld a,(lang_ui)
        xor 1
        ld (lang_ui),a
        call ptr_hide
        jp app_redraw

; ---------------------------------------------------------------------
; FILE commands
; ---------------------------------------------------------------------

; choose a file and load it into bank 4, then show what it is
app_open:
        ld a,MSG_PICK_OPEN
        call app_pick
        ret c
        ld hl,app_name
        ld de,LANG_BANK_ADDR
        ld c,VIEW_BANK_CFG
        call fs_load
        jp c,app_error
        ld (app_length),bc
        ld de,dlg_custom            ; NAME.EXT
        call app_name_text
        call app_newline
        ld a,MSG_SIZE               ; SIZE n
        call app_label
        ld hl,(app_length)
        call util_dec
        call app_newline
        ld a,MSG_TYPE               ; TYPE ...
        call app_label
        ld a,(fs_hdr_type)
        ld c,MSG_TYPE_BASIC
        or a
        jr z,.type
        ld c,MSG_TYPE_TEXT
        inc a
        jr z,.type
        ld c,MSG_TYPE_BINARY
.type:
        ld a,c
        call util_msg
        ld a,(fs_hdr_type)          ; LOAD #nnnn, files with a header
        inc a
        jr z,.bytes
        call app_newline
        ld a,MSG_LOAD
        call app_label
        ld a,"#"
        ld (de),a
        inc de
        ld hl,(fs_hdr_load)
        call util_hex4
.bytes:
        call app_newline            ; the first bytes, as text
        ld hl,(app_length)
        ld bc,VIEW_BYTES
        or a
        sbc hl,bc
        jr nc,.count
        add hl,bc
        ld b,h
        ld c,l
.count:
        ld a,c
        or a
        jr z,.end
        ld b,a
        ld a,VIEW_BANK_CFG
        push bc
        call ram_select
        pop bc
        ld hl,LANG_BANK_ADDR
.byte:
        ld a,(hl)
        inc hl
        cp " "
        jr c,.dot
        cp "|"
        jr z,.dot
        cp #7F
        jr c,.store
        cp #A0
        jr nc,.store
.dot:
        ld a,"."
.store:
        ld (de),a
        inc de
        djnz .byte
        ld a,RAM_BASE_CFG
        call ram_select
.end:
        xor a
        ld (de),a
        ld hl,dlg_file
        jp app_dialog

; write MSG_SAVE_TEXT as VOSTEST.TXT
app_save:
        ld a,MSG_SAVE_TEXT          ; copy the text: lang_msg's buffer
        call lang_msg               ; is reused by the dialogs
        ld de,app_text
        call util_copy
        ex de,hl
        ld de,app_text
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,app_test_name
        ld de,app_name
        push bc
        ld bc,11
        ldir
        pop bc
        ld a,2                      ; binary header, loads at #4000
        ld (fs_hdr_type),a
        ld hl,LANG_BANK_ADDR
        ld (fs_hdr_load),hl
        ld hl,0
        ld (fs_hdr_exec),hl
        ld hl,app_name
        ld de,app_text
        ld a,RAM_BASE_CFG
        call fs_save
        jp c,app_error
        ld de,dlg_custom            ; SAVED|NAME.EXT|FREE nK
        ld a,MSG_SAVED
        call util_msg
        call app_newline
        call app_name_text
        call app_newline
        call app_free
        ld hl,dlg_file
        jp app_dialog

; choose a file, ask, delete it
app_delete:
        ld a,MSG_PICK_DELETE
        call app_pick
        ret c
        ld de,dlg_custom            ; DELETE|NAME.EXT?
        ld a,MSG_DELETE_Q
        call util_msg
        call app_newline
        call app_name_text
        ld a,MSG_QMARK
        call util_msg
        xor a
        ld (de),a
        ld hl,dlg_delete
        call dialog_run
        or a                        ; 0 = YES
        jp nz,app_draw_status
        ld hl,app_name
        call fs_delete
        jp c,app_error
        ld de,dlg_custom            ; DELETED|NAME.EXT|FREE nK
        ld a,MSG_DELETED
        call util_msg
        call app_newline
        call app_name_text
        call app_newline
        call app_free
        ld hl,dlg_file
        jp app_dialog

; FORMAT x|FILES n|FREE nK
app_disc:
        call fs_catalog
        jp c,app_error
        ld (app_files),a
        ld de,dlg_custom
        ld a,MSG_FORMAT
        call app_label
        ld a,(fs_reserved)
        or a
        ld a,MSG_FMT_DATA
        jr z,.format
        ld a,MSG_FMT_SYSTEM
.format:
        call util_msg
        call app_newline
        ld a,MSG_FILES
        call app_label
        ld a,(app_files)
        ld l,a
        ld h,0
        call util_dec
        call app_newline
        call app_free
        ld hl,dlg_disc
        jp app_dialog

; A = picker title -> app_name = the chosen file; carry if none
app_pick:
        push af
        call fs_catalog
        jr c,.error
        jr z,.empty
        pop af
        call file_pick
        jr c,.cancel
        ld l,a                      ; FS_CAT + index * 16
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        ld de,app_name
        ld bc,11
        ldir
        or a
        ret
.error:
        pop bc
        call app_error
        scf
        ret
.empty:
        pop af
        ld hl,dlg_no_files
        call app_dialog
        scf
        ret
.cancel:
        call app_draw_status
        scf
        ret

; A = FDC_ERR_* / FS_ERR_* -> error dialog
app_error:
        add a,MSG_ERR_1 - 1
        ld de,dlg_custom
        call util_msg
        xor a
        ld (de),a
        ld hl,dlg_error
        ; fall through
; HL = dialog with DLG_OWN_TEXT text
app_dialog:
        call dialog_run
        jp app_draw_status

; helpers: all write at DE
app_name_text:
        ld hl,app_name
        jp util_fcb_text
app_newline:
        ld a,"|"
        jp util_char
app_label:                          ; A = MSG_*: "TEXT "
        call util_msg
        ld a," "
        jp util_char
app_free:                           ; FREE nK and the end of the text
        ld a,MSG_FREE
        call app_label
        call fs_free_k
        ld l,a
        ld h,0
        call util_dec
        ld a,"K"
        call util_char
        xor a
        ld (de),a
        ret

app_test_name:  db "VOSTEST TXT"
app_name:       ds 11
app_length:     dw 0
app_files:      db 0
app_text        equ GAP6 + 448      ; up to LANG_MSG_MAX bytes, after the directory

; ---- menus ----------------------------------------------------------
app_bar:
        db 3
        dw menu_file, menu_view, menu_help
menu_file:
        db MSG_MENU_FILE, 7
        db MSG_ITEM_OPEN, CMD_OPEN, "O", 0
        db MSG_ITEM_SAVE, CMD_SAVE, "S", 0
        db MSG_ITEM_DELETE, CMD_DELETE, "D", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_DISC, CMD_DISC, "I", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_QUIT, CMD_QUIT, "Q", 0
menu_view:
        db MSG_MENU_VIEW, 4
        db MSG_ITEM_MODE1, CMD_MODE1, 0, 0
        db MSG_ITEM_MODE0, CMD_MODE0, 0, 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_LANG, CMD_LANG, "L", 0
menu_help:
        db MSG_MENU_HELP, 3
        db MSG_ITEM_KEYS, CMD_KEYS, "K", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_ABOUT, CMD_ABOUT, 0, 0

; ---- buttons --------------------------------------------------------
app_widgets1:                       ; mode 1: in a row
        db 3
        dw 24, BUTTONS_Y : db 12, MSG_BTN_ABOUT, CMD_ABOUT, 0
        dw 136, BUTTONS_Y : db 12, MSG_BTN_MODE, CMD_TOGGLE, 0
        dw 248, BUTTONS_Y : db 12, MSG_BTN_KEYS, CMD_KEYS, 0
app_widgets0:                       ; mode 0: in a column
        db 3
        dw 24, BUTTONS_Y : db 18, MSG_BTN_ABOUT, CMD_ABOUT, 0
        dw 24, BUTTONS_Y + 20 : db 18, MSG_BTN_MODE, CMD_TOGGLE, 0
        dw 24, BUTTONS_Y + 40 : db 18, MSG_BTN_KEYS, CMD_KEYS, 0

; ---- dialogs --------------------------------------------------------
dlg_about:      db MSG_DLG_ABOUT_T, MSG_DLG_ABOUT, 1, MSG_BTN_OK
dlg_keys:       db MSG_DLG_KEYS_T, MSG_DLG_KEYS, 1, MSG_BTN_OK
dlg_quit:       db MSG_DLG_QUIT_T, MSG_DLG_QUIT, 2, MSG_BTN_YES, MSG_BTN_NO
dlg_file:       db MSG_DLG_FILE_T, DLG_OWN_TEXT, 1, MSG_BTN_OK
dlg_disc:       db MSG_DLG_DISC_T, DLG_OWN_TEXT, 1, MSG_BTN_OK
dlg_error:      db MSG_DLG_ERR_T, DLG_OWN_TEXT, 1, MSG_BTN_OK
dlg_no_files:   db MSG_DLG_DISC_T, MSG_NO_FILES, 1, MSG_BTN_OK
dlg_delete:     db MSG_DLG_FILE_T, DLG_OWN_TEXT, 2, MSG_BTN_YES, MSG_BTN_NO

; status text per command
app_cmd_msgs:
        db MSG_NONE, MSG_ITEM_SAVE, MSG_ITEM_OPEN, MSG_ITEM_QUIT
        db MSG_ITEM_MODE1, MSG_ITEM_MODE0, MSG_ITEM_LANG, MSG_ITEM_KEYS
        db MSG_ITEM_ABOUT, MSG_BTN_MODE, MSG_ITEM_DELETE, MSG_ITEM_DISC

palette_black:  ds 17, 0
palette_mode1:                      ; Desktop palette
        db 1, 26, 0, 11
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db 0                        ; border
palette_mode0:                      ; Launcher palette
        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
        db 0

app_mode:       db 1
app_last:       db 0
