; =====================================================================
; dialog.asm - modal dialogs
;
; dialog_run - HL -> db title MSG_*, text MSG_*, button count (1..3),
;              button MSG_*, ...
; With DLG_OWN_TEXT instead of the text MSG_*, the text is taken from
; dlg_custom (zero-terminated, up to DLG_TEXT_MAX - 1 characters).
; Returns A = the chosen button (0 = first). ESC chooses the last one.
;
; The dialog is centred, saves what it covers (bank 6, as menus do) and
; runs its own event loop until a button is chosen: TAB, SHIFT+TAB,
; LEFT and RIGHT move the focus; RETURN, ENTER or SPACE choose it; a
; click on a button chooses that button. "|" in the text starts a line.
; Close any open menu first: both use the same save-under buffer.
; =====================================================================

DLG_MAX_BUTTONS equ 3
DLG_TEXT_MAX    equ LANG_MSG_MAX + 1
DLG_OWN_TEXT      equ #FF

dialog_run:
        ld (dlg_def),hl
        ld hl,(ui_widgets)          ; keep the caller's buttons
        ld (dlg_saved_widgets),hl
        ld a,(ui_focus)
        ld (dlg_saved_focus),a
        ld a,(ptr_keys_on)
        ld (dlg_saved_keys),a
        xor a
        ld (ptr_keys_on),a

        ld hl,(dlg_def)             ; text: copy it, count lines
        inc hl
        ld a,(hl)
        cp DLG_OWN_TEXT
        ld hl,dlg_custom
        jr z,.text
        call lang_msg
.text:
        ld de,dlg_text
        ld bc,DLG_TEXT_MAX
        ldir
        ld hl,dlg_text
        ld bc,0                     ; B = longest line, C = lines
.line:
        inc c
        call ui_line_len
        cp b
        jr c,.shorter
        ld b,a
.shorter:
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        cp "|"
        jr z,.line
        ld a,b
        ld (dlg_chars),a
        ld a,c
        ld (dlg_lines),a

        ld hl,(dlg_def)             ; title
        ld a,(hl)
        call ui_msg
        ld hl,dlg_chars
        cp (hl)
        jr c,.title_ok
        ld (hl),a
.title_ok:
        ld hl,(dlg_def)             ; buttons: width = text + 4, min 8
        inc hl
        inc hl
        ld a,(hl)
        ld (dlg_wlist),a
        ld (dlg_count),a
        inc hl
        ld (dlg_bmsgs),hl
        xor a
        ld (dlg_bchars),a
        ld ix,dlg_wlist + 1
        ld a,(dlg_count)
        ld b,a
.button:
        push bc
        ld hl,(dlg_bmsgs)
        ld a,(hl)
        inc hl
        ld (dlg_bmsgs),hl
        ld (ix+5),a                 ; text
        call ui_msg
        add a,4
        cp 8
        jr nc,.wide
        ld a,8
.wide:
        ld (ix+4),a                 ; width in characters
        ld hl,dlg_bchars
        add a,(hl)
        inc a                       ; one character between buttons
        ld (hl),a
        pop bc
        ld a,(dlg_count)
        sub b
        ld (ix+6),a                 ; "command" = button number
        ld (ix+7),0
        ld de,8
        add ix,de
        djnz .button
        ld hl,dlg_bchars
        dec (hl)
        ld a,(dlg_bchars)
        ld hl,dlg_chars
        cp (hl)
        jr c,.size
        ld (hl),a
.size:
        ld a,(dlg_chars)            ; width = longest + 4 characters
        add a,4
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (dlg_w),hl
        ld a,(dlg_lines)            ; height = 12 + 6 + lines*10 + 4 + 14 + 6
        ld b,a
        ld a,12 + 6 + 4 + UI_BUTTON_H + 6
.height:
        add a,10
        djnz .height
        ld (dlg_h),a
        ld hl,(gfx_width)           ; x = (width - w) / 2, multiple of 8
        ld de,(dlg_w)
        or a
        sbc hl,de
        srl h
        rr l
        ld a,l
        and %11111000
        ld l,a
        ld (dlg_x),hl
        ld a,(dlg_h)                ; y = (GFX_H - h) / 2
        ld e,a
        ld d,0
        ld hl,GFX_H
        or a
        sbc hl,de
        srl h
        rr l
        ld (dlg_y),hl

        ld hl,(dlg_x)               ; save what the dialog covers
        ld de,(dlg_y)
        ld a,(ui_shadow_x)
        ld c,a
        ld b,0
        push hl
        ld hl,(dlg_w)
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        ld a,(ui_shadow_y)
        push hl
        ld hl,dlg_h
        add a,(hl)
        pop hl
        call ui_save
        call dlg_draw

        ld hl,dlg_wlist             ; buttons take the focus
        call ui_set_widgets
        call ui_draw_widgets

.loop:
        call wait_frame
.events:
        call ev_get
        jr z,.idle
        call dlg_event              ; A = button + 1, or 0
        or a
        jr z,.events
        dec a
        jr .done
.idle:
        call ptr_update
        jr .loop
.done:
        ld (dlg_result),a
        call ui_restore
        ld hl,(dlg_saved_widgets)
        ld (ui_widgets),hl
        ld a,(dlg_saved_focus)
        ld (ui_focus),a
        ld a,(dlg_saved_keys)
        ld (ptr_keys_on),a
        ld a,(dlg_result)
        ret

; frame, title bar, text lines; also places the buttons
dlg_draw:
        ld a,UIP_SHADOW
        ld (ui_fill_pen),a
        ld hl,(dlg_x)
        ld a,(ui_shadow_x)
        ld e,a
        ld d,0
        add hl,de
        ld de,(dlg_y)
        ld a,(ui_shadow_y)
        add a,e
        ld e,a
        ld a,0
        adc a,d
        ld d,a
        ld bc,(dlg_w)
        ld a,(dlg_h)
        call ui_rect
        ld a,UIP_BAR
        ld (ui_fill_pen),a
        ld hl,(dlg_x)
        ld de,(dlg_y)
        ld bc,(dlg_w)
        ld a,(dlg_h)
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,(dlg_x)
        ld de,(dlg_y)
        ld bc,(dlg_w)
        ld a,(dlg_h)
        call ui_frame
        ld a,UIP_SEL                ; title bar
        ld (ui_fill_pen),a
        ld hl,(dlg_x)
        ld de,(dlg_y)
        ld bc,(dlg_w)
        ld a,12
        call ui_rect
        ld a,UIP_SELTEXT
        ld c,UIP_SEL
        call ui_colours
        ld hl,(dlg_def)
        ld a,(hl)
        call ui_msg                 ; centred
        push hl
        call dlg_centre
        ld de,(dlg_y)
        inc de
        inc de
        pop bc
        call ui_text_line
        ld a,UIP_TEXT               ; text lines
        ld c,UIP_BAR
        call ui_colours
        ld hl,(dlg_y)
        ld de,18
        add hl,de
        ld (dlg_line_y),hl
        ld bc,dlg_text
.text:
        ld hl,(dlg_x)
        ld de,16
        add hl,de
        ld de,(dlg_line_y)
        call ui_text_line
        ld a,(bc)
        inc bc
        cp "|"
        jr nz,.buttons
        ld hl,(dlg_line_y)
        ld de,10
        add hl,de
        ld (dlg_line_y),hl
        jr .text
.buttons:
        ld a,(dlg_bchars)           ; first button x
        call dlg_centre
        ld (dlg_bx),hl
        ld hl,(dlg_y)               ; y = bottom - 6 - button height
        ld a,(dlg_h)
        sub UI_BUTTON_H + 6
        ld e,a
        ld d,0
        add hl,de
        ld (dlg_by),hl
        ld ix,dlg_wlist + 1
        ld a,(dlg_count)
        ld b,a
.place:
        ld hl,(dlg_bx)
        ld (ix+0),l
        ld (ix+1),h
        ld hl,(dlg_by)
        ld (ix+2),l
        ld (ix+3),h
        ld a,(ix+4)
        inc a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(dlg_bx)
        add hl,de
        ld (dlg_bx),hl
        ld de,8
        add ix,de
        djnz .place
        ret

; A = characters -> HL = x that centres them in the dialog (multiple of 8)
dlg_centre:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,(dlg_w)
        or a
        sbc hl,de
        srl h
        rr l
        ld a,l
        and %11111000
        ld l,a
        ld de,(dlg_x)
        add hl,de
        ret

; ev_cur -> A = button + 1 when one is chosen, else 0
dlg_event:
        ld a,(ev_cur)
        cp EV_LANG
        jr nz,.not_lang
        call ui_draw_indicator
        jr .none
.not_lang:
        cp EV_PTR_DOWN
        jr z,.click
        cp EV_KEY_DOWN
        jr z,.key
        cp EV_KEY_REPEAT
        jr z,.key
.none:
        xor a
        ret
.click:
        ld hl,(ev_cur + 4)
        ld de,(ev_cur + 6)
        call ui_widget_hit
        cp UI_NONE
        jr z,.none
        inc a
        ret
.key:
        ld a,(ev_cur + 1)
        cp KEY_ESC
        jr nz,.not_esc
        ld a,(dlg_count)
        ret
.not_esc:
        cp KEY_RETURN
        jr z,.choose
        cp KEY_ENTER
        jr z,.choose
        ld d,1
        cp KEY_RIGHT
        jr z,.move
        ld d,-1
        cp KEY_LEFT
        jr z,.move
        cp KEY_TAB
        jr nz,.not_tab
        ld d,1
        ld a,(ev_cur + 3)
        and MOD_SHIFT
        jr z,.move
        ld d,-1
.move:
        call ui_move_focus
        jr .none
.not_tab:
        ld a,(ev_cur + 2)
        cp " "
        jr nz,.none
.choose:
        ld a,(ui_focus)
        inc a
        ret

; ---- state ----------------------------------------------------------
dlg_def:            dw 0
dlg_saved_widgets:  dw 0
dlg_saved_focus:    db 0
dlg_saved_keys:     db 0
dlg_result:         db 0
dlg_count:          db 0
dlg_bmsgs:          dw 0
dlg_chars:          db 0
dlg_bchars:         db 0
dlg_lines:          db 0
dlg_x:              dw 0
dlg_y:              dw 0
dlg_w:              dw 0
dlg_h:              db 0
dlg_bx:             dw 0
dlg_by:             dw 0
dlg_line_y:         dw 0
dlg_wlist:          db 0
                    ds DLG_MAX_BUTTONS * 8
dlg_text            equ GAP1 + 512  ; DLG_TEXT_MAX bytes
dlg_custom          equ GAP3 + 544  ; text for DLG_OWN_TEXT dialogs
