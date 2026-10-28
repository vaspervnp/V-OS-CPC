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
        assert $ == VOS_API + VOS_API_COUNT * 3
        assert VM_OK == MSG_BTN_OK && VM_YES == MSG_BTN_YES && VM_NO == MSG_BTN_NO

api_exit:
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

; a program ends: no sound, no split, no frame events -> A = 0
api_end:
        call snd_off
        call split_off
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

        assert BUF_CFG ^ VIEW_BANK_CFG == 1
; The data bank (bank 4) at #4000-#7FFF, through fs_buf, 512 bytes a
; time. HL = source, DE = destination, BC = bytes.
api_bank_get:                       ; from the data bank
        ld a,BUF_CFG
        jr api_bank_copy
api_bank_put:                       ; to the data bank
        ld a,VIEW_BANK_CFG
api_bank_copy:
        ld (ab_from),a
        xor 1                       ; the other one
        ld (ab_to),a
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
        ld (view_ticks),a
        ret

api_frames:
        ld hl,(int_frames)
        ret

; -> A: a 16-bit linear congruential generator, high byte
api_random:
        ld hl,(api_seed)
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de                   ; * 5
        ld de,(int_frames)
        add hl,de
        inc hl
        ld (api_seed),hl
        ld a,h
        ret

api_menu_view:
        ld hl,menu_view
        ret
api_menu_help:
        ld hl,menu_help
        ret

api_catalog:
        call fdc_select
        call fs_catalog
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
        ld c,VIEW_BANK_CFG
        bit 7,a
        ret z
        ld c,BUF_CFG
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

; A = VT_FIRST.. -> HL = the program's text in the UI language
api_text:
        sub VT_FIRST
        ld hl,(app_texts)
        cp (hl)
        jr nc,.none
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
