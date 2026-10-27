; =====================================================================
; kernel.asm - kernel entry and M2 input test
;
; The test screen exercises the keyboard, the event queue and the
; pointer, in mode 1 (F1) or mode 0 (F2):
;   EVENTS  the last 8 events, newest marked with '>'
;   MATRIX  the 10x8 keyboard matrix, live (one row per line, bit 0 left)
;   TYPED   characters from key events; DEL deletes, RETURN clears
;   pointer position and buttons; clicks paint a dot in the bottom box
; The pointer moves with the cursor keys or an AMX mouse; COPY or the
; left mouse button clicks.
; =====================================================================

LOG_LINES       equ 8
LOG_LEN         equ 16              ; characters per log line
LOG_Y           equ 26
MATRIX_Y        equ 120
FIELD_Y         equ 196
INFO_Y          equ 212
CANVAS_Y        equ 224
CANVAS_H        equ 33

kernel_entry:
        di
        ld sp,STACK_TOP
        im 1
        call gfx_init
        call log_init
        ei
        ld a,1
        call set_test_mode
        call ptr_show

.main:
        call wait_frame
        call matrix_changed
        jr nz,.work
        ld a,(ev_tail)
        ld hl,ev_head
        cp (hl)
        jr nz,.work
        call ptr_update
        jr .main
.work:
        call ptr_hide
        call matrix_update
.events:
        call ev_get
        jr z,.done
        call handle_event
        jr .events
.done:
        call ptr_show
        jr .main

; ---------------------------------------------------------------------
; set_test_mode - A = 0 or 1. Redraws the whole test screen.
; The pointer must be hidden.
; ---------------------------------------------------------------------
set_test_mode:
        ld (test_mode),a
        call gfx_set_mode
        ld a,(test_mode)
        or a
        jr z,.mode0
        ld hl,palette_mode1
        call ga_set_palette
        ld a,2
        ld (ptr_pen_out),a
        ld a,3
        ld (dot_pen),a
        ld hl,list_mode1
        jr .draw
.mode0:
        ld hl,palette_mode0
        call ga_set_palette
        xor a
        ld (ptr_pen_out),a
        ld a,8
        ld (dot_pen),a
        ld hl,list_mode0
.draw:
        push hl
        xor a
        call gfx_cls
        pop hl
        call run_list
        ld hl,(gfx_width)           ; field holds width / 8 - 2 characters
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        sub 2
        ld (field_max),a
        ld b,a
        ld a,(field_len)
        cp b
        jr c,.len_ok
        ld a,b
        ld (field_len),a
.len_ok:
        call field_redraw
        call matrix_draw_all
        call log_redraw
        call ptr_clamp
        jp show_ptr_info

; ---------------------------------------------------------------------
; handle_event - act on ev_cur
; ---------------------------------------------------------------------
handle_event:
        ld a,(ev_cur)
        cp EV_PTR_MOVE
        jp z,show_ptr_info
        call log_event
        ld a,(ev_cur)
        cp EV_PTR_DOWN
        jr z,.ptr_down
        cp EV_PTR_UP
        jp z,show_ptr_info
        cp EV_KEY_UP
        ret z
        ld a,(ev_cur + 1)           ; key down or repeat
        cp KEY_F1
        jr z,.f1
        cp KEY_F2
        jr z,.f2
        ld a,(ev_cur + 2)
        jp field_input
.f1:
        ld a,1
        jr .switch
.f2:
        xor a
.switch:
        ld b,a
        ld a,(ev_cur)
        cp EV_KEY_DOWN
        ret nz
        ld a,b
        jp set_test_mode
.ptr_down:
        call show_ptr_info
        jp canvas_click

; ---------------------------------------------------------------------
; typed text field
; ---------------------------------------------------------------------
field_input:
        or a
        ret z
        cp 8                        ; DEL
        jr z,.delete
        cp 13                       ; RETURN / ENTER
        jr z,.clear
        cp 32
        ret c
        cp 127
        ret nc
        ld c,a
        ld a,(field_len)
        ld b,a
        ld a,(field_max)
        cp b
        ret z
        ret c
        ld hl,field_buf
        ld e,b
        ld d,0
        add hl,de
        ld (hl),c
        ld a,b
        inc a
        ld (field_len),a
        ld a,c
        jr field_char               ; B = position
.delete:
        ld a,(field_len)
        or a
        ret z
        dec a
        ld (field_len),a
        ld b,a
        ld a," "
        jr field_char
.clear:
        xor a
        ld (field_len),a
        jp field_redraw

; A = character, B = position in the field
field_char:
        push af
        push bc
        ld a,1
        ld c,2
        call txt_set_colours
        pop bc
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,8
        add hl,de
        ld de,FIELD_Y + 2
        pop af
        jp txt_char

field_redraw:
        ld hl,(gfx_width)
        ld de,-8
        add hl,de
        ld (field_rect + 4),hl
        ld ix,field_rect
        call gfx_fill_rect
        ld a,(field_len)
        or a
        ret z
        ld b,0
.char:
        push bc
        ld hl,field_buf
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        call field_char
        pop bc
        inc b
        ld a,(field_len)
        cp b
        jr nz,.char
        ret

; ---------------------------------------------------------------------
; keyboard matrix display
; ---------------------------------------------------------------------
; NZ if kbd_now differs from what is on screen
matrix_changed:
        ld hl,kbd_now
        ld de,mx_shown
        ld b,10
.cmp:
        ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .cmp
        ret

matrix_draw_all:
        ld c,0                      ; line
.line:
        ld b,0                      ; bit
.bit:
        push bc
        ld a,2
        call matrix_cell
        pop bc
        inc b
        ld a,b
        cp 8
        jr c,.bit
        inc c
        ld a,c
        cp 10
        jr c,.line
        ld hl,mx_shown
        ld b,10
.zero:
        ld (hl),0
        inc hl
        djnz .zero
        ; fall through: draw the keys held now

matrix_update:
        ld c,0
.line:
        ld b,0
        ld hl,kbd_now
        ld e,c
        ld d,0
        add hl,de
        ld a,(hl)
        ld hl,mx_shown
        add hl,de
        ld d,a                      ; now
        xor (hl)
        ld (hl),d
        ld e,a                      ; changed
.bit:
        bit 0,e
        jr z,.next
        push bc
        push de
        ld a,2                      ; released: pen 2
        bit 0,d
        jr z,.pen
        ld a,1                      ; held: pen 1
.pen:
        call matrix_cell
        pop de
        pop bc
.next:
        srl e
        srl d
        inc b
        ld a,b
        cp 8
        jr c,.bit
        inc c
        ld a,c
        cp 10
        jr c,.line
        ret

; C = line, B = bit, A = pen
matrix_cell:
        ld (mx_rect + 8),a
        ld a,b
        ld e,a
        add a,a
        add a,e
        add a,a                     ; bit * 6
        add a,4
        ld (mx_rect),a
        ld a,c
        ld e,a
        add a,a
        add a,e
        add a,a                     ; line * 6
        add a,MATRIX_Y
        ld (mx_rect + 2),a
        ld ix,mx_rect
        jp gfx_fill_rect

; ---------------------------------------------------------------------
; pointer info and canvas
; ---------------------------------------------------------------------
show_ptr_info:
        ld de,info_text + 2
        ld hl,(ptr_x)
        call fmt_dec3
        ld de,info_text + 8
        ld hl,(ptr_y)
        call fmt_dec3
        ld a,(ptr_buttons)
        add a,'0'
        ld (info_text + 14),a
        ld a,1
        ld c,0
        call txt_set_colours
        ld hl,4
        ld de,INFO_Y
        ld bc,info_text
        jp txt_print

canvas_click:
        ld hl,(ev_cur + 6)          ; y inside the box, away from its edges
        ld de,CANVAS_Y + 1
        or a
        sbc hl,de
        ret c
        ld de,CANVAS_H - 4
        or a
        sbc hl,de
        ret nc
        ld hl,(ev_cur + 4)          ; x
        ld de,5
        or a
        sbc hl,de
        ret c
        ld hl,(gfx_width)
        ld de,-12
        add hl,de
        ld de,(ev_cur + 4)
        or a
        sbc hl,de
        ret c
        ld (dot_rect),de
        ld hl,(ev_cur + 6)
        ld (dot_rect + 2),hl
        ld a,(dot_pen)
        ld (dot_rect + 8),a
        ld ix,dot_rect
        jp gfx_fill_rect

; ---------------------------------------------------------------------
; event log
; ---------------------------------------------------------------------
log_init:
        ld hl,log_text
        ld c,LOG_LINES
.line:
        ld b,LOG_LEN
.space:
        ld (hl)," "
        inc hl
        djnz .space
        ld (hl),0
        inc hl
        dec c
        jr nz,.line
        ret

; HL -> text of log line A
log_line_ptr:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de                   ; * (LOG_LEN + 1)
        ld de,log_text
        add hl,de
        ret

; DE = y of log line A
log_line_y:
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,a                     ; * 10
        add a,LOG_Y
        ld e,a
        ld d,0
        ret

log_event:
        ld a,(log_next)
        call log_line_ptr
        ex de,hl
        call fmt_event
        ld a,(log_next)
        call log_draw_line
        ld a,(log_next)             ; move the marker
        dec a
        and LOG_LINES - 1
        ld c," "
        call log_marker
        ld a,(log_next)
        ld c,">"
        call log_marker
        ld a,(log_next)
        inc a
        and LOG_LINES - 1
        ld (log_next),a
        ret

log_redraw:
        xor a
.line:
        push af
        call log_draw_line
        pop af
        inc a
        cp LOG_LINES
        jr c,.line
        ld a,(log_next)
        dec a
        and LOG_LINES - 1
        ld c,">"
        ; fall through

; A = line, C = marker character
log_marker:
        push bc
        call log_line_y
        push de
        ld a,3
        ld c,0
        call txt_set_colours
        pop de
        pop bc
        ld a,c
        ld hl,4
        jp txt_char

; A = line
log_draw_line:
        push af
        ld a,1
        ld c,0
        call txt_set_colours
        pop af
        push af
        call log_line_ptr
        pop af
        push hl
        call log_line_y
        pop bc
        ld hl,16
        jp txt_print

; ---------------------------------------------------------------------
; formatting
; ---------------------------------------------------------------------
; DE -> LOG_LEN characters: the event in ev_cur
fmt_event:
        ld a,(ev_cur)
        cp EV_PTR_DOWN
        jr z,.ptr
        cp EV_PTR_UP
        jr z,.ptr
        ld hl,str_down
        cp EV_KEY_DOWN
        jr z,.key
        ld hl,str_up
        cp EV_KEY_UP
        jr z,.key
        ld hl,str_repeat
.key:
        ldi                         ; "DN " etc.
        ldi
        ldi
        ld a,(ev_cur + 1)
        ld l,a
        ld h,0
        call fmt_dec3
        ld a," "
        ld (de),a
        inc de
        ld a,(ev_cur + 2)
        call fmt_char
        ld a," "
        ld (de),a
        inc de
        ld a,(ev_cur + 3)
        call fmt_mods
        ld a," "
        ld (de),a
        ret
.ptr:
        ld hl,str_bdown
        cp EV_PTR_DOWN
        jr z,.button
        ld hl,str_bup
.button:
        ldi                         ; "BD X"
        ldi
        ldi
        ldi
        ld hl,(ev_cur + 4)
        call fmt_dec3
        ld a," "
        ld (de),a
        inc de
        ld a,"Y"
        ld (de),a
        inc de
        ld hl,(ev_cur + 6)
        call fmt_dec3
        ld a," "
        ld (de),a
        inc de
        ld a,(ev_cur + 1)
        add a,'0'
        ld (de),a
        inc de
        ld a," "
        ld (de),a
        ret

; HL = 0..999 -> 3 digits at DE, DE advanced. Destroys: AF, BC, HL
fmt_dec3:
        ld bc,100
        call .digit
        ld bc,10
        call .digit
        ld a,l
        add a,'0'
        ld (de),a
        inc de
        ret
.digit:
        ld a,'0'
.sub:
        or a
        sbc hl,bc
        jr c,.done
        inc a
        jr .sub
.done:
        add hl,bc
        ld (de),a
        inc de
        ret

; A = character -> 3 characters at DE: 'c' or #hh
fmt_char:
        cp 32
        jr c,.hex
        cp 127
        jr nc,.hex
        ld c,a
        ld a,39
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        ld a,39
        ld (de),a
        inc de
        ret
.hex:
        ld c,a
        ld a,"#"
        ld (de),a
        inc de
        ld a,c
        ; fall through
; A -> 2 hex digits at DE, DE advanced. Destroys: AF, C
fmt_hex2:
        ld c,a
        rrca
        rrca
        rrca
        rrca
        call .nibble
        ld a,c
.nibble:
        and 15
        add a,'0'
        cp '9' + 1
        jr c,.store
        add a,'A' - '9' - 1
.store:
        ld (de),a
        inc de
        ret

; A = MOD_* bits -> 4 characters at DE, "SCPL" or '.'
fmt_mods:
        ld c,a
        ld hl,str_mods
        ld b,4
.bit:
        rr c
        ld a,(hl)
        jr c,.set
        ld a,"."
.set:
        ld (de),a
        inc de
        inc hl
        djnz .bit
        ret

; ---------------------------------------------------------------------
; run_list - HL = drawing list:
;   1, dw x, y, w, h, db pen              filled rectangle
;   2, dw x, y, db fg, bg, "text", 0      text
;   0                                     end
; ---------------------------------------------------------------------
run_list:
        ld a,(hl)
        inc hl
        cp 1
        jr z,.rect
        cp 2
        jr z,.text
        ret
.rect:
        push hl
        pop ix
        ld de,9
        add hl,de
        push hl
        call gfx_fill_rect
        pop hl
        jr run_list
.text:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push bc                     ; x
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push bc                     ; y
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        call txt_set_colours
        pop bc                      ; string
        pop de
        pop hl
        call txt_print
        ld h,b
        ld l,c
        inc hl
        jr run_list

; ---- test screens ---------------------------------------------------
list_mode1:
        db 1 : dw 0, 0, 384, 12 : db 1
        db 2 : dw 8, 2 : db 2, 1, "V-OS 0.03  M2 INPUT", 0
        db 2 : dw 192, 2 : db 2, 1, "F1/F2 MODE  COPY CLICKS", 0
        db 2 : dw 4, 16 : db 3, 0, "EVENTS", 0
        db 2 : dw 4, 110 : db 3, 0, "MATRIX", 0
        db 2 : dw 64, 140 : db 3, 0, "LINE 0 AT TOP, BIT 0 LEFT", 0
        db 2 : dw 4, 186 : db 3, 0, "TYPED", 0
        db 1 : dw 4, CANVAS_Y, 376, CANVAS_H : db 2
        db 0

list_mode0:
        db 1 : dw 0, 0, 192, 12 : db 1
        db 2 : dw 4, 2 : db 0, 1, "M2 INPUT F1 F2", 0
        db 2 : dw 4, 16 : db 3, 0, "EVENTS", 0
        db 2 : dw 4, 110 : db 3, 0, "MATRIX", 0
        db 2 : dw 4, 186 : db 3, 0, "TYPED", 0
        db 1 : dw 4, CANVAS_Y, 184, CANVAS_H : db 2
        db 0

palette_mode1:                      ; Desktop palette
        db 1, 26, 0, 11
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db 0                        ; border
palette_mode0:                      ; Launcher palette
        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
        db 0

str_down:   db "DN "
str_up:     db "UP "
str_repeat: db "RP "
str_bdown:  db "BD X"
str_bup:    db "BU X"
str_mods:   db "SCPL"

info_text:  db "X 000 Y 000 B 0", 0

field_rect: dw 4, FIELD_Y, 0, 12
            db 2
mx_rect:    dw 0, 0, 5, 5
            db 0
dot_rect:   dw 0, 0, 3, 3
            db 0

test_mode:  db 1
dot_pen:    db 3
field_len:  db 0
field_max:  db 0
field_buf:  ds 48
mx_shown:   ds 10
log_next:   db 0
log_text:   ds LOG_LINES * (LOG_LEN + 1)
