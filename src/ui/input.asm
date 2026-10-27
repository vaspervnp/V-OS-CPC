; =====================================================================
; input.asm - modal text input
;
; input_run - A = title MSG_*, HL = zero-terminated text (edited in
; place, starts with what is there; room for C + 2 bytes: the cursor is
; drawn from it), C = most characters.
; Returns carry if cancelled.
;
; Typed characters are added at the end, DEL removes the last one,
; RETURN or ENTER accept, ESC cancels. The pack keyboard works here as
; anywhere, so Greek can be typed; checking the text is the caller's.
; =====================================================================

input_run:
        ld (in_title),a
        ld (in_buf),hl
        ld a,c
        ld (in_max),a
        ld a,(ptr_keys_on)
        ld (in_keys),a
        xor a
        ld (ptr_keys_on),a
        ld a,(in_max)               ; width: field, hint or title, + 4
        inc a
        ld b,a
        ld a,MSG_INPUT_HINT
        call ui_msg
        cp b
        jr c,.hint
        ld b,a
.hint:
        ld a,(in_title)
        push bc
        call ui_msg
        pop bc
        cp b
        jr c,.title
        ld b,a
.title:
        ld a,b
        add a,4
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (uw_w),hl
        ld a,12 + 6 + 12 + 6 + 10 + 6
        ld (uw_h),a
        call ui_centre
        call ui_save_window
        ld a,(in_title)
        call ui_window
        ld a,UIP_TEXT
        ld c,UIP_BAR
        call ui_colours
        ld a,MSG_INPUT_HINT
        call lang_msg
        ld b,h
        ld c,l
        ld hl,(uw_x)
        ld de,16
        add hl,de
        ld de,(uw_y)
        ld a,12 + 6 + 12 + 6
        add a,e
        ld e,a
        jr nc,.hint_y
        inc d
.hint_y:
        call txt_print
        call in_draw

.loop:
        call wait_frame
.events:
        call ev_get
        jr z,.idle
        call in_event               ; A: 0 none, 1 accepted, 2 cancelled
        or a
        jr z,.events
        jr .done
.idle:
        call ptr_update
        jr .loop
.done:
        ld (in_result),a
        call ui_restore
        ld a,(in_keys)
        ld (ptr_keys_on),a
        ld a,(in_result)
        cp 2
        ccf                         ; carry if cancelled
        ret

; the field: the text and a cursor, on the desk colours
in_draw:
        ld a,UIP_DESK
        ld (ui_fill_pen),a
        ld hl,(uw_x)
        ld de,8
        add hl,de
        ld de,(uw_y)
        ld a,18
        add a,e
        ld e,a
        jr nc,.y
        inc d
.y:
        ld (in_y),de
        push hl
        push de
        ld hl,(uw_w)
        ld de,-16
        add hl,de
        ld b,h
        ld c,l
        pop de
        pop hl
        ld a,12
        call ui_rect
        ld a,UIP_DESKTEXT
        ld c,UIP_DESK
        call ui_colours
        ld hl,(in_buf)              ; text, then "_"
        call in_length
        ld e,a
        ld d,0
        add hl,de
        ld (hl),"_"
        inc hl
        ld (hl),0
        ld hl,(uw_x)
        ld de,16
        add hl,de
        ld de,(in_y)
        inc de
        inc de
        ld bc,(in_buf)
        call txt_print
        ld hl,(in_buf)              ; the cursor is not part of the text
        call in_length
        dec a
        ld e,a
        ld d,0
        add hl,de
        ld (hl),0
        ret

; HL -> text -> A = length. Preserves HL
in_length:
        push hl
        ld b,0
.count:
        ld a,(hl)
        or a
        jr z,.done
        inc hl
        inc b
        jr .count
.done:
        ld a,b
        pop hl
        ret

; ev_cur -> A = 0 nothing, 1 accepted, 2 cancelled
in_event:
        ld a,(ev_cur)
        cp EV_LANG
        jr nz,.not_lang
        call ui_draw_indicator
        jr .none
.not_lang:
        cp EV_KEY_DOWN
        jr z,.key
        cp EV_KEY_REPEAT
        jr nz,.none
.key:
        ld a,(ev_cur + 1)
        cp KEY_ESC
        ld b,2
        jr z,.end
        dec b
        cp KEY_RETURN
        jr z,.end
        cp KEY_ENTER
        jr z,.end
        ld hl,(in_buf)
        call in_length
        ld c,a
        ld a,(ev_cur + 1)
        cp KEY_DEL
        jr nz,.char
        ld a,c                      ; DEL: one less
        or a
        jr z,.none
        dec a
        ld e,a
        ld d,0
        add hl,de
        ld (hl),0
        jr .redraw
.char:
        ld a,(ev_cur + 2)
        cp " "
        jr c,.none
        ld b,a
        ld a,c
        ld de,in_max
        ex de,hl
        cp (hl)
        ex de,hl
        jr nc,.none                 ; full
        ld e,a
        ld d,0
        add hl,de
        ld (hl),b
        inc hl
        ld (hl),0
.redraw:
        call in_draw
.none:
        xor a
        ret
.end:
        ld a,b
        ret

in_title:       db 0
in_buf:         dw 0
in_max:         db 0
in_keys:        db 0
in_result:      db 0
in_y:           dw 0
