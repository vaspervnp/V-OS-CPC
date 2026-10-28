; =====================================================================
; view.asm - the shell's views as overlays
;
; Each view (Desktop, Launcher, Commander, Setup) is a file on drive A:,
; assembled for VIEW_ADDR, and runs in bank 5 (VIEW_BANK_CFG). It
; starts with
;   +0  jp init     set mode, palette and menus, read, draw everything
;   +3  jp event    handle ev_cur
;   +6  jp redraw   draw everything again (the language changed)
;   +9  db "VV", view number
; Programs (app_request, src/api/vos_api.inc) run the same way, from
; any drive, with "VA" and their API version at +9.
; Views share the VIEW and HELP menus and their commands (view_command).
; F1 to F4 (or a view's VIEW menu, through view_request) switch
; views. A new view is loaded into bank 4 first and checked, so a disc
; error leaves the running view intact.
; =====================================================================

VIEW_DESKTOP    equ 0
VIEW_LAUNCHER   equ 1
VIEW_COMMANDER  equ 2
VIEW_SETUP      equ 3
VIEW_APP        equ 4               ; a program (kernel/api.asm)
VIEW_NONE       equ #FF

OV_INIT         equ VIEW_ADDR
OV_EVENT        equ VIEW_ADDR + 3
OV_REDRAW       equ VIEW_ADDR + 6
OV_MAGIC        equ VIEW_ADDR + 9   ; "VV", view number

; menu commands of all views
CMD_INFO        equ 1
CMD_COPY        equ 2
CMD_DELETE      equ 3
CMD_RENAME      equ 4
CMD_REFRESH     equ 5
CMD_QUIT        equ 6
CMD_LANG        equ 7
CMD_KEYS        equ 8
CMD_ABOUT       equ 9
CMD_FORMAT      equ 10
CMD_SAVE        equ 11
CMD_RUN         equ 12
CMD_DESKTOP     equ 16              ; CMD_DESKTOP + view number
CMD_LAUNCHER    equ 17
CMD_COMMANDER   equ 18
CMD_SETUP       equ 19

; A = view to switch to once the current event is handled
view_request:
        ld (view_next),a
        ret

; main loop: a pending switch
view_poll:
        ld a,(view_next)
        cp VIEW_NONE
        ret z
        ld b,a
        ld a,VIEW_NONE
        ld (view_next),a
        ld a,b
        cp VIEW_APP
        jr z,app_run
        ld a,(view_cur)
        cp b
        ret z
        ld a,b
        ; fall through

; A = view: load its overlay and start it
view_switch:
        ld (vw_n),a
        ld l,a                      ; name = view_files + view * 11
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        add hl,de
        ld de,view_files
        add hl,de
        push hl
        xor a                       ; overlays live on drive A:
        call fdc_select
        pop hl
        call view_fetch
        jp c,sys_error
        ld de,"V" * 256 + "V"       ; is it the view asked for?
        or a
        sbc hl,de
        jr nz,.bad
        ld a,(vw_n)
        cp c
        jr z,view_install
.bad:
        ld a,FS_ERR_FORMAT
        jp sys_error

; A = drive: run the program file_name (from a view: it starts once
; the view's event is handled)
app_request:
        ld (app_drive),a
        ld a,VIEW_APP
        jp view_request

app_run:
        ld a,(app_drive)
        call fdc_select
        ld hl,file_name
        call view_fetch
        jp c,sys_error
        ld de,"A" * 256 + "V"       ; "VA", and an API we have
        or a
        sbc hl,de
        jr nz,.bad
        ld a,c
        cp VOS_API_VERSION + 1
        jr nc,.bad
        ld a,(view_cur)
        cp VIEW_APP
        jr z,.return
        ld (app_return),a
.return:
        ld a,VIEW_APP
        jr view_install
.bad:
        ld a,FS_ERR_NOT_PROGRAM
        jp sys_error

; HL = name, on the drive selected: the file into bank 4 -> HL = bytes
; 9 and 10 (the magic), C = byte 11. Carry and A = error on failure.
view_fetch:
        ld de,BUF_ADDR
        ld c,BUF_CFG
        call fs_load
        ret c
        ld a,BUF_CFG
        call ram_select
        ld hl,(BUF_ADDR + OV_MAGIC - VIEW_ADDR)
        ld a,(BUF_ADDR + OV_MAGIC - VIEW_ADDR + 2)
        ld c,a                      ; (ram_select destroys B)
        call ram_home
        or a
        ret

; A = view: the file in bank 4 becomes the running view, from bank 5
view_install:
        ld (vw_n),a
        call ptr_hide
        ld hl,(fs_length)           ; 512-byte pieces through fs_buf
        ld de,511
        add hl,de
        ld a,h
        srl a
        ld (vw_left),a
        ld hl,VIEW_ADDR
        ld (vw_ptr),hl
.piece:
        ld a,BUF_CFG
        call ram_select
        ld hl,(vw_ptr)
        ld de,fs_buf
        ld bc,512
        ldir
        ld a,VIEW_BANK_CFG
        call ram_select
        ld hl,fs_buf
        ld de,(vw_ptr)
        ld bc,512
        ldir
        ld (vw_ptr),de
        ld hl,vw_left
        dec (hl)
        jr nz,.piece
        ld a,VIEW_BANK_CFG          ; from now on kernel calls map it back
        ld (ram_home_cfg),a
        ld a,(vw_n)
        ld (view_cur),a
        xor a                       ; no frame events, no program texts
        ld (view_ticks),a
        ld hl,api_no_texts
        ld (app_texts),hl
        jp OV_INIT

; ev_cur: F1-F4 outside menus -> carry, a switch is requested
view_keys:
        ld a,(ev_cur)
        cp EV_KEY_DOWN
        jr nz,.no
        ld a,(ui_open)
        cp UI_NONE
        jr nz,.no
        ld a,(ev_cur + 1)
        ld b,VIEW_DESKTOP
        cp KEY_F1
        jr z,.view
        inc b
        cp KEY_F2
        jr z,.view
        inc b
        cp KEY_F3
        jr z,.view
        inc b
        cp KEY_F4
        jr nz,.no
.view:
        ld a,b
        call view_request
        scf
        ret
.no:
        or a
        ret

; A = a shared command (VIEW and HELP menus, exit): carry it out
view_command:
        cp CMD_DESKTOP
        jr c,.not_view
        sub CMD_DESKTOP
        jp view_request
.not_view:
        cp CMD_LANG
        jr nz,.not_lang
        ld a,(lang_loaded)
        or a
        ret z
        ld a,(lang_ui)
        xor 1
        ld (lang_ui),a
        jp OV_REDRAW
.not_lang:
        ld hl,dlg_keys
        cp CMD_KEYS
        jp z,dialog_run
        ld hl,dlg_about
        cp CMD_ABOUT
        jp z,dialog_run
        cp CMD_QUIT
        ret nz
        ld hl,dlg_quit
        call dialog_run
        or a                        ; 0 = YES
        ret nz
        di                          ; restart: lower ROM back at #0000
        ld bc,GA_PORT + GA_RAMCFG
        out (c),c
        ld hl,.reset                ; the last two instructions run from
        ld de,fs_buf                ; RAM at #C000+: once the lower ROM is
        ld bc,3                     ; on, #0000-#3FFF is not this code
        ldir
        ld bc,GA_PORT + GA_RMR + GA_RMR_HIROM_OFF + 1
        jp fs_buf
.reset:
        out (c),c
        rst 0

menu_view:
        db MSG_MENU_VIEW, 6
        db MSG_ITEM_DESKTOP, CMD_DESKTOP, 0, 0
        db MSG_ITEM_LAUNCHER, CMD_LAUNCHER, 0, 0
        db MSG_ITEM_COMMANDER, CMD_COMMANDER, 0, 0
        db MSG_ITEM_SETUP, CMD_SETUP, 0, 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_LANG, CMD_LANG, "L", 0
menu_help:
        db MSG_MENU_HELP, 3
        db MSG_ITEM_KEYS, CMD_KEYS, "K", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_ABOUT, CMD_ABOUT, 0, 0

dlg_about:      db MSG_DLG_ABOUT_T, MSG_DLG_ABOUT, 1, MSG_BTN_OK
dlg_keys:       db MSG_DLG_KEYS_T, MSG_DLG_KEYS, 1, MSG_BTN_OK
dlg_quit:       db MSG_DLG_QUIT_T, MSG_DLG_QUIT, 2, MSG_BTN_YES, MSG_BTN_NO

view_files:
        db "DESKTOP OVL"
        db "LAUNCHEROVL"
        db "COMMANDROVL"
        db "SETUP   OVL"

view_cur:       db VIEW_NONE
view_next:      db VIEW_DESKTOP     ; the first view (SETUP.CFG)
vw_n:           db 0
view_ticks:     db 0                ; EV_FRAME events for the view
app_drive:      db 0
app_return:     db VIEW_LAUNCHER    ; the view that started the program
vw_left:        db 0
vw_ptr:         dw 0
