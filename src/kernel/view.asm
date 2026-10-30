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
; F6 (or PROGRAMS in the VIEW menu) lists the programs running and
; goes on with one (kernel/ext.asm).
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
CMD_ACC         equ 13              ; Launcher: as the accessory
CMD_PROGRAMS    equ 14              ; the program switcher
CMD_DRIVE       equ 15              ; Launcher: the other drive
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
        ld a,(acc_req)              ; the accessory opens or closes
        or a
        call nz,acc_toggle
        ld a,(acc_moved)            ; or moved (VOS_DRAG)
        or a
        call nz,acc_move
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
        ld hl,VIEW_BANK_CFG * 256 + (VIEW_ADDR >> 8)
        ld (vw_page),hl             ; views: bank 5, not moved (vw_cfg)
        ld hl,app_back              ; a view: no caller to go back to
        ld (hl),0
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
        jp z,view_install
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
        ld hl,app_child             ; asked by VOS_RUN?
        ld a,(hl)
        ld (hl),0
        ld (app_was_child),a
        ld a,(app_wake)             ; one in its slot runs again
        or a                        ; (Launcher, F6)
        ld hl,slot_wake
        jr nz,.placed
        ld a,(app_drive)
        call fdc_select
        ld hl,file_name
        call view_fetch
        jr c,app_fail
        ld de,"A" * 256 + "V"       ; "VA", and an API we have
        or a
        sbc hl,de
        jr nz,.bad
        ld a,c
        cp VOS_API_VERSION + 1
        jr nc,.bad
        ld hl,app_place             ; where it goes (kernel/ext.asm)
.placed:
        call ext_call
        ld a,FS_ERR_NO_ROOM
        jr c,app_fail
        ld a,(view_cur)
        cp VIEW_APP
        jr z,.return
        ld (app_return),a
.return:
        ld a,(app_was_child)        ; the caller starts again after it
        or a
        jr z,.self
        ld (app_back),a
        ld hl,app_self
        ld de,app_parent
        ld bc,12
        ldir
.self:
        ld a,(app_drive)            ; who runs now: db drive, name
        ld hl,app_self
        ld (hl),a
        inc hl
        ex de,hl
        ld hl,file_name
        ld bc,11
        ldir
        ld hl,slot_own              ; and in its slot
        call ext_call
        ld hl,app_wake
        ld a,(hl)
        ld (hl),0
        or a
        ld a,VIEW_APP
        jp z,view_install
        ld (vw_n),a                 ; init gets A = 2: go on as it was
        call ptr_hide
        call view_base
        ld a,(vw_cfg)               ; its bank
        ld (ram_home_cfg),a
        call ram_select
        ld a,2
        jp view_start
.bad:
        ld a,FS_ERR_NOT_PROGRAM
        ; fall through
; A = error: no file for the next program either
app_fail:
        push af
        xor a
        ld (app_open),a
        pop af
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

; A = view: the file in bank 4 becomes the running view, from bank
; vw_cfg at vw_page
view_install:
        ld (vw_n),a
        call ptr_hide
        call view_base
        ld a,BUF_CFG
        ld (ab_from),a
        ld a,(vw_cfg)               ; from now on kernel calls map it back
        ld (ram_home_cfg),a
        ld (ab_to),a
        ld hl,BUF_ADDR
        ld bc,(fs_length)
        call bank_copy              ; (and maps it)
        xor a                       ; init: A = 0
; A = for init: start the view vw_n at cur_base
view_start:
        push af
        call snd_off                ; the last one's sound and mixed
        call split_off              ; screen stop (one going on sets them)
        call acc_reset              ; an accessory that was open is closed
        ld a,(vw_n)
        ld (view_cur),a
        xor a                       ; no frame events, no program texts,
        ld (view_ticks),a           ; no buttons of the last program,
        ld (ptr_keys_on),a          ; the cursor keys its own
        ld hl,api_no_texts
        ld (app_texts),hl
        ld hl,ui_no_widgets
        ld (ui_widgets),hl
        pop af
        ld hl,(cur_base)
        jp (hl)

; vw_page -> DE = cur_base = its address
view_base:
        ld a,(vw_page)
        ld d,a
        ld e,0
        ld (cur_base),de
        ret

; ev_cur: F1-F6 outside menus -> carry, the key is taken: a switch is
; requested, the accessory opens or closes, or (F6) the program
; switcher runs
view_keys:
        ld a,(ev_cur)
        cp EV_KEY_DOWN
        jr nz,.no
        ld a,(ui_open)
        cp UI_NONE
        jr nz,.no
        ld a,(ev_cur + 1)
        cp KEY_F5                   ; the accessory
        jr nz,.not_acc
        ld (acc_req),a
        scf
        ret
.not_acc:
        cp KEY_F6
        jr nz,.not_sw
        call view_programs
        scf
        ret
.not_sw:
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

view_programs:
        ld hl,sw_run
; HL = a routine of the kernel extension (kernel/ext.asm): run it with
; bank 7 as the home bank
ext_call:
        ld a,(ram_home_cfg)
        ld (ext_home),a
        ld a,LANG_BANK_CFG
        ld (ram_home_cfg),a
        call ram_select
        call .go
        push af                     ; (its A and flags)
        ld a,(ext_home)
        ld (ram_home_cfg),a
        call ram_select
        pop af
        ret
.go:
        jp (hl)

; A = a shared command (VIEW and HELP menus, exit): carry it out
view_command:
        cp CMD_PROGRAMS
        jr z,view_programs
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
        ld (cfg_data + CFG_LANG),a  ; Setup shows it, and saves it
        ld de,6
        jr cur_call
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

; DE = 3: event (HL = ev_cur), 6: redraw, of the view or program, or
; of the accessory while it is open
cur_call:
        ld hl,(cur_base)
        add hl,de
        push hl
        ld hl,ev_cur
        ret

; ---------------------------------------------------------------------
; The desk accessory: a relocatable program in bank 6 at ACC_ADDR
; (src/api/vos_api.inc). Open, it is the home bank (ram_home) and
; cur_base, and has view_ticks, app_texts, ui_widgets and ui_bar of its
; own: acc_swap exchanges them with acc_ctx.
; ---------------------------------------------------------------------
ACC_CFG         equ #C6

; main loop: open or close it
acc_toggle:
        xor a
        ld (acc_req),a
        ld a,(acc_loaded)
        or a
        ret z
        ld a,(acc_open)
        or a
        jr nz,acc_close
        call acc_up
        ld a,1                      ; init, as an accessory
        jp ACC_ADDR

; main loop: it moved, what was under it is drawn, then the accessory
acc_move:
        xor a
        ld (acc_moved),a
        call acc_close
        call acc_up
        ld de,6
        jp cur_call

acc_up:
        ld a,1
        ld (acc_open),a
        call acc_swap
        ld a,ACC_CFG
        ld hl,ACC_ADDR
        jr acc_home

acc_close:
        xor a
        ld (acc_open),a
        call acc_swap
        ld hl,(vw_page - 1)         ; the program draws everything
        ld l,0
        ld a,(vw_cfg)
        call acc_home
        ld de,6
        jp cur_call

acc_home:
        ld (cur_base),hl
        ld (ram_home_cfg),a
        jp ram_select

; the accessory closed, its own values fresh for the next time
acc_reset:
        xor a
        ld (acc_open),a
        ld hl,acc_fresh
        ld de,acc_ctx
        ld bc,7
        ldir
        ret

acc_swap:
        ld hl,acc_vars
        ld de,acc_ctx
        ld b,7
.byte:
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(bc)
        push af
        ld a,(de)
        ld (bc),a
        pop af
        ld (de),a
        inc de
        pop bc
        djnz .byte
        ret

acc_vars:       dw view_ticks, app_texts, app_texts + 1, ui_widgets
                dw ui_widgets + 1, ui_bar, ui_bar + 1
acc_fresh:      db 0
                dw api_no_texts, ui_no_widgets, ui_no_widgets  ; (no menus)

menu_view:
        db MSG_MENU_VIEW, 7
        db MSG_ITEM_DESKTOP, CMD_DESKTOP, 0, 0
        db MSG_ITEM_LAUNCHER, CMD_LAUNCHER, 0, 0
        db MSG_ITEM_COMMANDER, CMD_COMMANDER, 0, 0
        db MSG_ITEM_SETUP, CMD_SETUP, 0, 0
        db MSG_ITEM_PROGRAMS, CMD_PROGRAMS, 0, 0
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
app_child:      db 0                ; VOS_RUN asked for the next program
app_was_child:  db 0
app_back:       db 0                ; on VOS_EXIT, run app_parent
app_self        equ #8800           ; 12: the program running: drive,
app_parent      equ #880C           ; name; 12: the one that called VOS_RUN
cur_base:       dw VIEW_ADDR        ; whose entries cur_call uses
acc_loaded:     db 0
acc_open:       db 0
acc_req:        db 0                ; open or close it in the main loop
acc_ctx         equ #8818           ; 7: the other side's acc_vars
app_open        equ #B000           ; 13: db 1, drive, name: the file
                                    ; the next program opens (file_open)
vw_page:        db VIEW_ADDR >> 8   ; where view_install puts it,
vw_cfg:         db VIEW_BANK_CFG    ; in that bank
data_cfg:       db BUF_CFG          ; the data bank (api_drive)
app_slot:       db 0                ; the program's slot (kernel/ext.asm;
                                    ; 0: none, it has all of bank 5)
app_wake:       db 0                ; a slot to run again (Launcher, F6)
ext_home:       db 0                ; ext_call
rl_pages:       db 0
