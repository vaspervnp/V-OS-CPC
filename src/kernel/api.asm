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
        jp gfx_cls
        jp gfx_plot
        jp gfx_fill_rect            ; 10
        jp txt_set_colours
        jp txt_print
        jp txt_char
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
        jp gfx_blit
        jp snd_play                 ; 33
        jp split_set
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
        assert $ - xa_table == VX_COUNT * 2
xa_hl:          dw 0

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
; interrupts off (the screen is there).
xa_m4:
        push bc
        push de
        push hl
        ld hl,m4_find               ; (kernel/files_ext.asm)
        call ext_call
        pop hl
        jr c,.none
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
        ldir
        jr m4_done
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

; The data bank (bank 4) at #4000-#7FFF, through fs_buf, 512 bytes a
; time; the program's own bank is vw_cfg. HL = source, DE =
; destination, BC = bytes.
api_bank_get:                       ; from the data bank
        ld a,(vw_cfg)
        ld (ab_to),a
        ld a,BUF_CFG
        ld (ab_from),a
        jr bank_copy
api_bank_put:                       ; to the data bank
        ld a,(vw_cfg)
        ld (ab_from),a
        ld a,BUF_CFG
        ld (ab_to),a
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
        push af
        push hl
        and #3F
        call fdc_select
        call fs_catalog
        pop de                      ; the extension
        pop bc
        jr c,.end
        bit 6,b                     ; VOS_CAT_EXT: only those files
        jr z,.end
        push ix
        ld ix,FS_CAT                ; where the next one kept goes
        ld hl,FS_CAT
        ld b,a
        ld c,0
        or a
        jr z,.kept
.file:
        push bc
        push de
        push hl
        ld bc,8
        add hl,bc
        ld b,3
.same:
        ld a,(de)
        cp (hl)
        jr nz,.other
        inc hl
        inc de
        djnz .same
.other:
        pop hl
        pop de
        pop bc
        jr nz,.next
        push bc
        push de
        push hl
        push ix
        pop de
        ld bc,16
        ldir
        push de
        pop ix
        pop hl
        pop de
        pop bc
        inc c
.next:
        ld a,16
        add a,l
        ld l,a
        jr nc,.carry
        inc h
.carry:
        djnz .file
.kept:
        ld a,c
        ld (fc_count),a
        pop ix
        or a
.end:
        ld hl,FS_CAT
        ret

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

; A = drive + maybe VOS_DATA -> A = drive, C = the bank's RAM config
api_drive:
        push hl
        ld hl,vw_cfg                ; the program's bank, or data_cfg
        bit 7,a
        jr z,.bank
        inc hl
.bank:
        ld c,(hl)
        pop hl
        and #7F
        ret

; A = drive (+ VOS_DATA), HL = name, DE = data, BC = bytes: a binary
; file
api_save:
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
        ld (fs_hdr_load),de
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
