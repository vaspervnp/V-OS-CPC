; =====================================================================
; setup.asm - the Setup view: settings, saved in A:SETUP.CFG
;
; Mode 1. One row per setting (kernel/setup.asm): view at boot,
; language, key repeat delay and speed, AMX mouse and how it is read,
; desk colour, the keyboards CONTROL+SHIFT goes through. Changes apply at once. LANGUAGE goes through English and
; each language pack, which is loaded from A: at once (st_lang).
;   UP/DOWN          choose a setting
;   LEFT/RIGHT       change it (also a click on the row)
;   RETURN, ^S       save
; An overlay (kernel/view.asm).
; =====================================================================

ST_X            equ 32
ST_Y            equ 30
ST_W            equ 320
ST_ROW_H        equ 16
ST_ROWS_Y       equ ST_Y + 18
ST_COUNT        equ 8               ; rows: the settings but CFG_PACK
ST_H            equ 18 + ST_COUNT * ST_ROW_H + 6
ST_VALUE_X      equ ST_X + 184
ST_STATUS_Y     equ ST_Y + ST_H + 12
ST_KEYS_Y       equ GFX_H - 10
ST_PACK         equ #FE             ; option text: the pack's own name
ST_ROW_SIZE     equ 11              ; db label, count, then 4 x (text, value)

        jp st_init
        jp st_event
        jp st_redraw
        db "VV", VIEW_SETUP

st_init:
        ld hl,st_bar
        call ui_set_bar
        ld hl,ui_no_widgets
        call ui_set_widgets
        xor a
        ld (ptr_keys_on),a
        ld a,1
        call ui_set_mode
        ld hl,palette_mode1
        call ga_set_palette
        ld a,2
        ld (ptr_pen_out),a
        call ptr_clamp
        ; fall through

st_redraw:
        call ptr_hide
        ld a,UIP_DESK
        call ui_pen
        call gfx_cls
        call ui_draw_bar
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld a,MSG_SET_KEYS
        call lang_msg
        ld b,h
        ld c,l
        ld hl,0
        ld de,ST_KEYS_Y
        call txt_print
        ld a,UIP_BAR                ; the box and its title bar
        ld (ui_fill_pen),a
        call .box
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        call .box
        call ui_frame
        ld a,UIP_SEL
        ld (ui_fill_pen),a
        call .box
        ld a,12
        call ui_rect
        ld a,UIP_SELTEXT
        ld c,UIP_SEL
        call ui_colours
        ld a,MSG_SET_TITLE
        call lang_msg
        ld b,h
        ld c,l
        ld hl,ST_X + 8
        ld de,ST_Y + 2
        call txt_print
        xor a
.row:
        push af
        call st_draw_row
        pop af
        inc a
        cp ST_COUNT
        jr c,.row
        ret
.box:
        ld hl,ST_X
        ld de,ST_Y
        ld bc,ST_W
        ld a,ST_H
        ret

; A = row: label and "< value >", dark when chosen
st_draw_row:
        ld (st_r),a
        call st_row_ptr
        ld (st_ptr),hl
        ld l,a                      ; y = ST_ROWS_Y + row * 16
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ST_ROWS_Y
        add hl,de
        ld (st_row_y),hl
        ld bc,UIP_TEXT * 256 + UIP_BAR
        ld a,(st_r)
        ld hl,st_sel
        cp (hl)
        jr nz,.colours
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        push bc
        ld a,c
        ld (ui_fill_pen),a
        ld hl,ST_X + 4
        ld de,(st_row_y)
        ld bc,ST_W - 8
        ld a,12
        call ui_rect
        pop bc
        ld a,b
        call ui_colours
        ld hl,(st_ptr)              ; label
        ld a,(hl)
        call lang_msg
        ld b,h
        ld c,l
        ld hl,ST_X + 8
        ld de,(st_row_y)
        inc de
        inc de
        call txt_print
        call st_option              ; value: "< TEXT >"
        ld de,st_line
        ld a,"<"
        ld (de),a
        inc de
        ld a," "
        ld (de),a
        inc de
        ld a,(hl)
        cp ST_PACK
        jr nz,.message
        ld hl,lang_name
        call util_copy
        jr .end
.message:
        call util_msg
.end:
        ld a," "
        ld (de),a
        inc de
        ld a,">"
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld hl,ST_VALUE_X
        ld de,(st_row_y)
        inc de
        inc de
        ld bc,st_line
        jp txt_print

; A = row -> HL -> its table entry. Preserves A
st_row_ptr:
        push af
        ld hl,st_rows
        ld de,ST_ROW_SIZE
        inc a
        jr .first
.next:
        add hl,de
.first:
        dec a
        jr nz,.next
        pop af
        ret

; st_ptr's setting -> HL -> its current option (text, value), A = its
; number. An unknown value counts as the first option.
st_option:
        ld hl,(st_ptr)
        inc hl
        ld a,(hl)                   ; setting
        inc hl
        ld b,(hl)                   ; options
        inc hl
        ld e,a
        ld d,0
        push hl
        ld hl,cfg_data
        add hl,de
        ld c,(hl)                   ; current value
        pop hl
        push hl
        ld e,0
.find:
        inc hl
        ld a,(hl)
        cp c
        jr z,.found
        inc hl
        inc e
        djnz .find
        pop hl
        xor a
        ret
.found:
        dec hl
        pop af
        ld a,e
        ret

; D = +1 or -1: the next or previous option of the chosen setting
st_change:
        ld a,d
        ld (st_step),a
        ld a,(st_sel)
        cp CFG_LANG
        jr z,st_lang
        call st_row_ptr
        ld (st_ptr),hl
        call st_option              ; A = option now
        ld hl,st_step
        add a,(hl)
        ld hl,(st_ptr)
        inc hl
        inc hl
        ld b,(hl)                   ; options
        cp b
        jr c,.inside
        jr z,.first
        ld a,b                      ; -1: the last
        dec a
        jr .inside
.first:
        xor a
.inside:
        add a,a                     ; its value
        inc a
        inc a
        ld e,a
        ld d,0
        add hl,de
        ld b,(hl)
        ld hl,(st_ptr)
        inc hl
        ld e,(hl)                   ; setting
        ld hl,cfg_data
        add hl,de
        ld (hl),b
        call cfg_apply
        ld a,(st_sel)               ; language: everything again
        cp CFG_LANG
        jp z,st_redraw
        cp CFG_DESK
        jr nz,.row
        ld hl,palette_mode1
        call ga_set_palette
.row:
        ld a,(st_sel)
        jp st_draw_row

; LANGUAGE: English (CFG_LANG 0), then each pack (CFG_PACK, from 0;
; CFG_LANG 1). A pack is loaded at once; one that is not on A: leaves
; English.
st_lang:
        ld a,(cfg_data + CFG_LANG)  ; A = 0 English, or the pack + 1
        or a
        jr z,.step
        ld a,(cfg_data + CFG_PACK)
        inc a
.step:
        ld hl,st_step
        add a,(hl)
        cp #FF                      ; before English: the last pack
        jr nz,.wrap
        ld a,LANG_PACKS
.wrap:
        cp LANG_PACKS + 1           ; after the last: English
        jr c,.inside
        xor a
.inside:
        or a
        jr z,.texts
        dec a
        ld (cfg_data + CFG_PACK),a
        ld a,MSG_SET_LANG           ; "PLEASE WAIT: LANGUAGE"
        call ui_busy
        xor a
        call fdc_select
        ld hl,lang_init
        call ext_call
        call ui_restore
        ld a,(lang_loaded)          ; 1 if it is there
.texts:
        ld (cfg_data + CFG_LANG),a
        call cfg_apply
        jp st_redraw

; A = row to choose
st_choose:
        ld hl,st_sel
        ld b,(hl)
        ld (hl),a
        ld a,b
        call st_draw_row
        ld a,(st_sel)
        jp st_draw_row

st_save:
        call cfg_save
        jp c,sys_error
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld a,MSG_SET_SAVED
        call lang_msg
        ld b,h
        ld c,l
        ld hl,ST_X
        ld de,ST_STATUS_Y
        jp txt_print

; ---------------------------------------------------------------------
st_event:
        ld a,(ui_open)
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
        cp CMD_SAVE
        jr z,st_save
        jp view_command
.key:
        ld a,(ev_cur + 1)
        ld d,1
        cp KEY_RIGHT
        jp z,st_change
        ld d,-1
        cp KEY_LEFT
        jp z,st_change
        cp KEY_RETURN
        jr z,st_save
        cp KEY_ENTER
        jr z,st_save
        cp KEY_UP
        jr z,.up
        cp KEY_DOWN
        jr nz,.ui
        ld a,(st_sel)
        inc a
        cp ST_COUNT
        ret nc
        jr st_choose
.up:
        ld a,(st_sel)
        or a
        ret z
        dec a
        jr st_choose
.click:
        ld hl,(ev_cur + 6)
        ld de,UI_BAR_H
        or a
        sbc hl,de
        jr c,.ui
        ld hl,(ev_cur + 6)          ; a row?
        ld de,ST_ROWS_Y
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        ld c,0
.row:
        sub ST_ROW_H
        jr c,.found
        inc c
        jr .row
.found:
        ld a,c
        cp ST_COUNT
        ret nc
        ld hl,st_sel
        cp (hl)
        jp nz,st_choose
        ld d,1                      ; the chosen row again: next option
        jp st_change

; ---- menus ----------------------------------------------------------
st_bar:
        db 3
        dw st_menu_file, menu_view, menu_help
st_menu_file:
        db MSG_MENU_FILE, 3
        db MSG_ITEM_SAVE_SET, CMD_SAVE, "S", 0
        db UI_SEPARATOR, 0, 0, 0
        db MSG_ITEM_QUIT, CMD_QUIT, "Q", 0

; one row per setting, in CFG_* order (CFG_PACK goes with CFG_LANG)
st_rows:
        db MSG_SET_VIEW, CFG_VIEW, 4
        db MSG_VW_DESKTOP, VIEW_DESKTOP, MSG_VW_LAUNCHER, VIEW_LAUNCHER
        db MSG_VW_COMMANDER, VIEW_COMMANDER, MSG_SET_TITLE, VIEW_SETUP
        db MSG_SET_LANG, CFG_LANG, 2
        db MSG_VAL_ENGLISH, 0, ST_PACK, 1, 0, 0, 0, 0
        db MSG_SET_DELAY, CFG_DELAY, 3
        db MSG_VAL_SHORT, 15, MSG_VAL_MEDIUM, 25, MSG_VAL_LONG, 40, 0, 0
        db MSG_SET_RATE, CFG_RATE, 3
        db MSG_VAL_SLOW, 5, MSG_VAL_MEDIUM, 3, MSG_VAL_FAST, 2, 0, 0
        db MSG_SET_AMX, CFG_AMX, 2
        db MSG_VAL_ON, 1, MSG_VAL_OFF, 0, 0, 0, 0, 0
        db MSG_SET_AMX_MODE, CFG_AMX_LEVELS, 2
        db MSG_VAL_PULSES, 0, MSG_VAL_LEVELS, 1, 0, 0, 0, 0
        db MSG_SET_DESK, CFG_DESK, 4
        db MSG_COL_BLUE, 1, MSG_COL_BLACK, 0, MSG_COL_GREEN, 9, MSG_COL_RED, 3
        db MSG_SET_KBDS, CFG_KBDS, 2
        db MSG_VAL_KB_PACK, 0, MSG_VAL_KB_ALL, 1, 0, 0, 0, 0

; ---- state ----------------------------------------------------------
st_sel:         db 0
st_step:        db 0
st_r:           db 0
st_ptr:         dw 0
st_row_y:           dw 0
st_line:        ds 24
