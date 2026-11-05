; =====================================================================
; api.asm - the program API (src/api/vos_api.inc): jump table and the
; few calls that are not kernel routines as they are
; =====================================================================

api_jumps:
        jp api_exit                 ; 0
        jp api_ticks
        jp api_frames
        jp api_random
        jp view_command
        jp sys_error                ; 5
        jp ui_set_mode
        jp ga_set_palette
        jp api_cls
        jp api_plot
        jp api_rect                 ; 10
        jp txt_set_colours
        jp api_print
        jp api_char
        jp lang_msg
        jp ui_set_bar               ; 15
        jp ui_draw_bar
        jp ui_event
        jp dialog_run
        jp input_run
        jp ui_set_widgets           ; 20
        jp ui_draw_widgets
        jp api_menu_view
        jp api_menu_help
        jp api_catalog
        jp api_load                 ; 25
        jp api_save
        jp api_delete
        jp file_pick
        jp api_texts
        jp api_menu_open            ; 30
        jp api_key_held
        jp api_blit
        jp snd_play                 ; 33
        jp api_split
        jp api_run                  ; 35
        jp api_keep
        jp api_bank_get
        jp api_bank_put
        jp api_background           ; 39
        jp api_drag                 ; 40
        jp ui_fit
        jp api_ext                  ; 42: VOS_EXT, the calls after it
        assert $ == VOS_API + VOS_API_COUNT * 3
        assert VM_OK == MSG_BTN_OK && VM_YES == MSG_BTN_YES && VM_NO == MSG_BTN_NO

; VOS_EXT: A = call number (VX_*), BC, DE, HL as the call wants. A
; call in the kernel extension (bank 7, from EXT_ADDR) runs through
; ext_call and finds its HL in xa_hl; the others get it as it was.
; An unknown number: carry, A = 0.
api_ext:
        cp VX_COUNT
        jr nc,.none
        ld (xa_hl),hl
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,xa_table
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                    ; HL = the routine
        pop de
        ld a,h
        cp EXT_ADDR >> 8
        jp nc,ext_call
        push hl
        ld hl,(xa_hl)
        ret
.none:
        xor a
        scf
        ret

xa_table:       dw xa_version, xa_free, xa_clip_put, xa_clip_get, xa_m4
                dw xa_mem, xa_behind, xa_data, xa_db, xa_utf8, xa_calc
                dw xa_lang, xa_irq, xa_drive, xa_print, xa_view
                dw xa_window
        assert $ - xa_table == VX_COUNT * 2
xa_hl:          dw 0

; ---- a program's view (VX_VIEW): its drawing through gfx/view.asm in
; the second extension while one is set, straight to gfx as before
; while not. The program's arguments are copied first: its memory is
; not mapped there.
vw_on           equ GAP2 + 700      ; 1: a view is set
vw_a            equ GAP2 + 701      ; the pen, the character
vw_x            equ GAP2 + 702
vw_y            equ GAP2 + 704
vw_ox           equ GAP2 + 706      ; x: the origin, the clip from, to
vw_x0           equ GAP2 + 708
vw_x1           equ GAP2 + 710
vw_oy           equ GAP2 + 712      ; y: the same (gfx/view.asm: vw_axis)
vw_y0           equ GAP2 + 714
vw_y1           equ GAP2 + 716
vw_tx           equ GAP2 + 718
vw_ty           equ GAP2 + 720
vw_h            equ GAP2 + 722
vw_buf          equ GAP2 + 723      ; 12: a rectangle, an image, a split
wm_on           equ GAP2 + 735      ; the program in front: 1 in a window,
                                    ; 2 the same full screen (wm/wm.asm)
wm_was          equ GAP2 + 736      ; wm_on before this view started
wm_sys          equ GAP2 + 737      ; 1: WM.SYS is in wm_bank (boot_x)
wm_dw_hook      equ GAP2 + 738      ; ui_draw_widget calls it; and
WM_CALL_GAP     equ GAP2 + 766      ; wm_call goes there; both copied at
wm_sp           equ GAP2 + 798      ; boot (boot/gap.asm)
        assert wm_sp + 2 <= GAP2 + GAP_SIZE

; Z: no view. Keeps all but the flags
vw_check:
        push hl
        ld hl,vw_on
        inc (hl)
        dec (hl)
        pop hl
        ret

api_cls:
        call vw_check
        jp z,gfx_cls
        ld (vw_a),a
        ld hl,vw_cls
        jp wm_call

api_plot:
        call vw_check
        jp z,gfx_plot
        ld bc,vw_plot
        jr vw_go

api_char:
        call vw_check
        jp z,txt_char
        ld bc,vw_char
; A, HL, DE kept for the routine BC of the second extension
vw_go:
        ld (vw_a),a
        ld (vw_x),hl
        ld (vw_y),de
        ld h,b
        ld l,c
        jp wm_call

; as txt_print: BC -> the zero after the text
api_print:
        call vw_check
        jp z,txt_print
.char:
        ld a,(bc)
        or a
        ret z
        push bc
        push de
        push hl
        ld bc,vw_char
        call vw_go
        pop hl
        pop de
        pop bc
        inc bc
        push de
        ld de,8
        add hl,de
        pop de
        jr .char

api_rect:
        call vw_check
        jp z,gfx_fill_rect
        call vw_copy
        ld hl,vw_rect
        jp wm_call

api_blit:
        call vw_check
        jp z,gfx_blit
        call vw_copy
        ld hl,vw_blit
        call wm_call
        ret c
        push ix
        ld ix,vw_buf
        call gfx_blit
        pop ix
        ret

; IX -> 9 bytes -> vw_buf
vw_copy:
        push ix
        pop hl
        ld bc,9
vw_copy_hl:
        ld de,vw_buf
        ldir
        ret

; VOS_SPLIT: HL -> 12 bytes, or 0 (gfx/split_set.asm)
api_split:
        ld a,h
        or l
        jp z,split_off
        ld bc,12
        call vw_copy_hl
        ld hl,split_set
        jp ext2_call

; VX_VIEW: HL -> dw x, y, w, h, or 0 (gfx/view.asm: vw_set). Without a
; RAM expansion: carry, A = 0
xa_view:
        ld a,(wm_bank)
        or a
        scf
        ret z
        ld a,h
        or l
        ld (vw_a),a
        ld bc,8
        call nz,vw_copy_hl
        ld hl,vw_set
        jp wm_call

wm_bank:        db 0                ; its RAM config (boot/expand.asm)

; VX_WINDOW: HL -> dw w, h: the program in a window (wm/wm.asm). Without
; WM.SYS (no RAM expansion): carry, A = 0
xa_window:
        ld a,(wm_sys)
        or a
        scf
        ret z
        ld (vw_x),hl                ; (its size is written back there)
        ld de,vw_buf
        ld bc,4
        ldir
        ld hl,wm_window
        jp wm_call

; VX_DB: C = DB_* call, DE, HL (xa_hl): the database engine (kernel/
; ext2.asm: db_entry)
xa_db:
        ld hl,db_entry
        jp ext2_call

; VX_CALC: C = CALC_* call, DE, HL (xa_hl): the formula engine (kernel/
; ext2.asm: calc_entry)
xa_calc:
        ld hl,calc_entry
        jp ext2_call

; VX_UTF8: HL (xa_hl) -> text, BC, E (kernel/ext2.asm: u8_entry). B
; goes as D and comes back in H: ext2_call's ram_select takes B
xa_utf8:
        ld d,b
        ld hl,u8_entry
        call ext2_call
        ld b,h
        ld c,l
        ret

; VX_PRINT: HL (xa_hl) -> text, BC, E (kernel/ext2.asm: prt_entry); B
; goes as D, as for VX_UTF8
xa_print:
        ld d,b
        ld hl,prt_entry
        jp ext2_call

; VX_BEHIND: DE -> db drive, name: the file in app_open, and the main
; loop starts its program behind this one (kernel/ext2.asm, behind_run)
xa_behind:
        ex de,hl
        ld de,app_open + 1
        ld bc,12
        ldir
        ld a,1
        ld (app_open),a
        ld (bh_req),a
        ret

; VX_VERSION -> A = API version, HL = kernel version (BCD)
xa_version:
        ld hl,VOS_VERSION
        ld a,VOS_API_VERSION
        or a
        ret

; VX_CLIP_PUT: HL = text, BC = bytes (at most CLIP_MAX kept) -> the
; clipboard, at CLIP_ADDR in bank 7; HL = bytes kept
xa_clip_put:
        push hl
        ld hl,CLIP_MAX
        or a
        sbc hl,bc
        jr nc,.fits
        ld bc,CLIP_MAX
.fits:
        ld (clip_len),bc
        ld a,(vw_cfg)
        ld (ab_from),a
        ld a,LANG_BANK_CFG
        ld (ab_to),a
        pop hl
        ld de,CLIP_ADDR
        call bank_copy
        ld hl,(clip_len)
        ret

; VX_CLIP_GET: DE = where, BC = room -> as much of the clipboard as fits
; there; HL = its size (BC = 0: only the size)
xa_clip_get:
        ld hl,(clip_len)
        push hl
        or a
        sbc hl,bc
        jr nc,.room                 ; bigger than the room: the room
        pop bc
        push bc
.room:
        ld a,LANG_BANK_CFG
        ld (ab_from),a
        ld a,(vw_cfg)
        ld (ab_to),a
        ld hl,CLIP_ADDR
        call bank_copy
        pop hl
        ret
clip_len:       dw 0

; VX_M4: HL -> a command for the M4 board (db size, dw command, data),
; DE -> where its response goes, BC = how many bytes of it (db size,
; dw command, then the data) -> carry if there is no M4 board. The M4
; ROM is mapped at #C000 only while the response is copied, with the
; interrupts off (the screen is there). HL = 0: BC bytes of the ROM's
; sock_info (the sockets' state, 16 bytes each) to DE.
xa_m4:
        push bc
        push de
        push hl
        ld hl,m4_find               ; (kernel/files_ext.asm)
        call ext_call
        pop hl
        jr c,.none
        ld a,h
        or l
        jr z,.socks
        ld bc,#FE00                 ; the command, its size byte first
        ld d,(hl)
        inc d
.send:
        inc b
        outi
        dec d
        jr nz,.send
        ld bc,#FC00                 ; go
        out (c),c
        pop de
        pop bc
        di
        call m4_rom
        ld hl,(#FF02)               ; the ROM's response buffer
.copy:
        ldir
        jr m4_done
.socks:
        pop de
        pop bc
        di
        call m4_rom
        ld hl,(#FF06)
        jr .copy
.none:
        pop de
        pop bc
        ret

; the ROM m4_num at #C000 (interrupts off before); BC kept
m4_rom:
        push bc
        ld a,(m4_num)
        ld bc,#DF00
        out (c),a
        ld a,(gfx_mode)
        or GA_RMR + GA_RMR_LOROM_OFF
        ld b,GA_PORT >> 8
        out (c),a
        pop bc
        ret
; and the RAM there again; carry clear
m4_done:
        ld a,(gfx_mode)
        call ga_set_mode
        ei
        or a
        ret
m4_num:         db #FF                ; #FF: not looked for, #FE: none

api_exit:
        ld a,(acc_open)             ; an accessory: it closes, after
        or a                        ; this event (view_poll)
        jr z,.program
        ld (acc_req),a
        ret
.program:
        call api_end
        ld hl,app_back              ; started by VOS_RUN: its caller again
        cp (hl)
        ld (hl),a
        jr z,.view
        ld hl,app_parent
        ld a,(hl)
        inc hl
        call app_name_set
        jp app_request
.view:
        ld a,(app_return)
        jp view_request

; A = drive, HL -> 11-byte name: run it once this event is handled;
; when it exits, the program that called starts again
api_run:
        push af
        push hl
        call api_end                ; the caller ends, as with VOS_EXIT
        inc a
        ld (app_child),a
        pop hl
        pop af
        call app_name_set
        jp app_request

; a program ends: no sound, no split, no frame events, its slot free
; -> A = 0
api_end:
        call snd_off
        call split_off
        ld hl,slot_free             ; (kernel/ext.asm)
        call ext_call
        xor a
        ld (view_ticks),a
        ret

; HL -> 11-byte name -> file_name (keeps A)
app_name_set:
        ld de,file_name
        ld bc,11
        ldir
        ret

api_keep:
        ld hl,app_keep
        ret

; A = 1: the program goes on in the background, 0: it pauses there
api_background:
        ld e,a
        ld hl,slot_bg               ; (kernel/ext.asm)
        jp ext_call

; VOS_DRAG (ui/ui.asm, ui_drag): an accessory that moved is drawn
; again by the main loop (kernel/view.asm)
api_drag:
        call ui_drag
        ret nc
        ld a,(acc_open)
        ld (acc_moved),a
        ret

; in the background the calls not for a program there come here
; (kernel/ext.asm, bg_hush): nothing, A = 0, Z, no carry
api_quiet:
        xor a
        ret

; The data bank (data_get) at #4000-#7FFF, through fs_buf, 512 bytes
; a time; the program's own bank is vw_cfg. HL = source, DE =
; destination, BC = bytes. data_get first: the first time it gives a
; program its own bank it copies bank 4 there with ab_from and ab_to
api_bank_get:                       ; from the data bank
        call data_get
        ld (ab_from),a
        ld a,(vw_cfg)
        ld (ab_to),a
        jr bank_copy
api_bank_put:                       ; to the data bank
        call data_get
        ld (ab_to),a
        ld a,(vw_cfg)
        ld (ab_from),a
; from bank ab_from to bank ab_to, both at #4000-#7FFF
bank_copy:
.piece:
        ld a,b
        or c
        jp z,ram_home
        push bc                     ; this piece: up to 512
        ld a,b
        cp 2
        jr c,.short
        ld bc,512
.short:
        ld (ab_n),bc
        push de
        ld a,(ab_from)
        call ram_select
        ld de,fs_buf
        ld bc,(ab_n)
        ldir
        ld a,(ab_to)
        call ram_select
        pop de
        push hl
        ld hl,fs_buf
        ld bc,(ab_n)
        ldir
        pop hl
        pop bc                      ; bytes left
        push hl
        ld hl,(ab_n)
        ex de,hl                    ; HL = destination, DE = piece
        push hl
        ld h,b
        ld l,c
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop de
        pop hl
        jr .piece

api_ticks:
        ld b,a
        and 1                       ; bit 0: VE_FRAME events
        ld (view_ticks),a
        ld a,b
        rrca                        ; bit 1 (VOS_PTR_KEYS): the cursor
        and 1                       ; keys and COPY drive the pointer
        ld (ptr_keys_on),a
        ret

api_frames:
        ld hl,(int_frames)
        ld a,(int_frames_hi)
        ret

; -> A: a 16-bit xorshift (7, 9, 8), the frame counter mixed into the
; seed first so that the time of the calls counts too
api_random:
        ld hl,(api_seed)
        ld a,(int_frames)
        xor l
        ld l,a
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (api_seed),hl
        ret

api_menu_view:
        ld hl,menu_view
        ret
api_menu_help:
        ld hl,menu_help
        ret

api_catalog:
        ld (cat_a),a                ; kept, for the file list's folders
        ld de,cat_ext               ; (kernel/filedlg.asm)
        ld bc,3
        ldir
        ld hl,cat_run               ; (kernel/ext2.asm)
        jp ext2_call

; A = drive (+ VOS_DATA: the data bank), HL = name, DE = destination
api_load:
        call api_drive
        push bc
        push hl
        push de
        call fdc_select
        pop de
        pop hl
        pop bc
        jp fs_load

; A = drive + maybe VOS_DATA -> A = drive, C = the bank's RAM config:
; the program's, or its data bank
api_drive:
        bit 7,a
        push af
        ld a,(vw_cfg)
        call nz,data_get
        ld c,a
        pop af
        and #7F
        ret

; -> A = the running program's data bank (data_bank, kernel/ext.asm:
; bank 4, or one of its own in a RAM expansion); the rest kept
data_get:
        push hl
        push de
        push bc
        ld hl,data_bank
        call ext_call
        pop bc
        pop de
        pop hl
        ld a,(data_cfg)
        ret

; A = drive (+ VOS_DATA, + VOS_LOAD_IX), HL = name, DE = data, BC =
; bytes: a binary file; its header says it loads at DE, or at IX
api_save:
        ld (fs_hdr_load),de
        bit 6,a
        jr z,.at
        ld (fs_hdr_load),ix
        and #BF
.at:
        push bc
        call api_drive
        push af
        ld a,c
        ld (as_cfg),a
        pop af
        pop bc
        push hl
        push de
        push bc
        call fdc_select
        ld a,2
        ld (fs_hdr_type),a
        pop bc
        pop de
        pop hl
        push hl
        ld hl,0
        ld (fs_hdr_exec),hl
        pop hl
        ld a,(as_cfg)
        jp fs_save

api_delete:
        push hl
        call fdc_select
        pop hl
        jp fs_delete

api_texts:
        ld (app_texts),hl
        ret

; A = key number -> NZ while it is held (the last keyboard scan)
api_key_held:
        ld c,a
        srl a
        srl a
        srl a
        ld e,a
        ld d,0
        ld hl,kbd_now
        add hl,de
        ld a,c
        and 7
        ld b,a
        ld a,1
        jr z,.bit
.shift:
        add a,a
        djnz .shift
.bit:
        and (hl)
        ret

api_menu_open:
        ld a,(ui_open)
        inc a                       ; UI_NONE = #FF
        ret

; A = VT_FIRST.. -> HL = the program's text in the UI language: the
; second column if its language is the pack's, else English
api_text:
        sub VT_FIRST
        ld hl,(app_texts)
        cp (hl)
        jr nc,.none
        inc hl
        ld c,(hl)                   ; BC = the second column's language
        inc hl
        ld b,(hl)
        inc hl
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)                   ; English
        inc hl
        ld d,(hl)
        inc hl
        ld a,(lang_ui)
        or a
        jr z,.english
        push hl
        ld hl,(lang_code)
        sbc hl,bc                   ; (no carry: or a)
        pop hl
        jr nz,.english
        ld a,(hl)                   ; the other one, if there is one
        inc hl
        ld h,(hl)
        ld l,a
        or h
        ret nz
.english:
        ex de,hl
        ret
.none:
        ld hl,api_empty
        ret

api_empty:      db 0
api_seed:       dw #1234
app_keep:       ds 16               ; VOS_KEEP
as_cfg:         db 0
ab_from:        db 0
ab_to:          db 0
ab_n:           dw 0
app_texts:      dw api_no_texts
api_no_texts:   db 0
