; =====================================================================
; kernel.asm - kernel entry and the M3 desktop test
;
; A small desktop built with the UI toolkit (src/ui):
;   menu bar   FILE: New ^N, Open ^O, Exit to BASIC ^Q
;              VIEW: Mode 1, Mode 0, Switch language ^L
;              HELP: Keys ^K, About V-OS
;   buttons    About, Mode 0/1, Keys (TAB moves the focus)
;   status     the last command
; New and Open show a "not yet" dialog; Exit asks before restarting the
; CPC; Switch language flips the UI between English and the pack.
; =====================================================================

CMD_NEW         equ 1
CMD_OPEN        equ 2
CMD_QUIT        equ 3
CMD_MODE1       equ 4
CMD_MODE0       equ 5
CMD_LANG        equ 6
CMD_KEYS        equ 7
CMD_ABOUT       equ 8
CMD_TOGGLE      equ 9

HEADING_Y       equ 24
HINT_Y          equ 38
BUTTONS_Y       equ 64
STATUS_Y        equ GFX_H - 24

kernel_entry:
        di
        ld sp,STACK_TOP
        im 1
        call lang_init              ; before gfx_init reuses #8000
        call gfx_init
        ei
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
        cp CMD_NEW
        jr z,.not_yet
        cp CMD_OPEN
        jr z,.not_yet
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
.not_yet:
        ld hl,dlg_not_yet
        jr .dialog
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

; ---- menus ----------------------------------------------------------
app_bar:
        db 3
        dw menu_file, menu_view, menu_help
menu_file:
        db MSG_MENU_FILE, 4
        db MSG_ITEM_NEW, CMD_NEW, "N", 0
        db MSG_ITEM_OPEN, CMD_OPEN, "O", 0
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
dlg_not_yet:    db MSG_DLG_NYI_T, MSG_DLG_NYI, 1, MSG_BTN_OK

; status text per command
app_cmd_msgs:
        db MSG_NONE, MSG_ITEM_NEW, MSG_ITEM_OPEN, MSG_ITEM_QUIT
        db MSG_ITEM_MODE1, MSG_ITEM_MODE0, MSG_ITEM_LANG, MSG_ITEM_KEYS
        db MSG_ITEM_ABOUT, MSG_BTN_MODE

palette_mode1:                      ; Desktop palette
        db 1, 26, 0, 11
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db 0                        ; border
palette_mode0:                      ; Launcher palette
        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
        db 0

app_mode:       db 1
app_last:       db 0
