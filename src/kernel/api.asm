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
        assert $ == VOS_API + VOS_API_COUNT * 3

api_exit:
        xor a
        ld (view_ticks),a
        ld a,(app_return)
        jp view_request

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

; A = drive, HL = name, DE = destination in the program's memory
api_load:
        push hl
        push de
        call fdc_select
        pop de
        pop hl
        ld c,VIEW_BANK_CFG
        jp fs_load

; A = drive, HL = name, DE = data, BC = bytes: a binary file
api_save:
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
        ld a,VIEW_BANK_CFG
        jp fs_save

api_delete:
        push hl
        call fdc_select
        pop hl
        jp fs_delete

api_texts:
        ld (app_texts),hl
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
app_texts:      dw api_no_texts
api_no_texts:   db 0
