; =====================================================================
; kernel.asm - kernel entry and M1 graphics test
;
; M1 switches to the 32K overscan screen and alternates every three
; seconds between a mode 1 and a mode 0 test screen. Each screen has:
;   - a one-pixel frame on the outermost pixels (x = 0 / last, y = 271),
;   - a title bar and the full ASCII character set,
;   - filled rectangles, including widths that end inside a byte,
;   - a diagonal drawn with gfx_plot.
; =====================================================================

kernel_entry:
        di
        ld sp,STACK_TOP
        im 1
        call gfx_init
        ei

        ld a,1
.main:
        ld (demo_mode),a
        ld a,(int_frames)
        ld (draw_start),a
        ld a,(demo_mode)
        call show_test
        call show_draw_time
        ld b,150                    ; three seconds
.wait:
        push bc
        call wait_frame
        pop bc
        djnz .wait
        ld a,(demo_mode)
        xor 1
        jr .main

; ---------------------------------------------------------------------
; show_test - A = mode. Draws that mode's test screen.
; ---------------------------------------------------------------------
show_test:
        push af
        call gfx_set_mode
        pop af
        or a
        jr z,.mode0

        ld hl,palette_mode1
        call ga_set_palette
        xor a
        call gfx_cls
        ld hl,list_mode1
        call run_list
        ld de,20
        call draw_charset
        ld hl,200
        ld de,140
        ld b,110
        ld a,1
        jp draw_diagonal

.mode0:
        ld hl,palette_mode0
        call ga_set_palette
        xor a
        call gfx_cls
        ld hl,list_mode0
        call run_list
        ld de,20
        call draw_charset
        call draw_bars
        ld hl,8
        ld de,196
        ld b,48
        ld a,10
        jp draw_diagonal

; ---------------------------------------------------------------------
; show_draw_time - prints "DRAW nnn FRAMES" (frames since draw_start)
; in the title bar
; ---------------------------------------------------------------------
show_draw_time:
        ld a,(draw_start)
        ld b,a
        ld a,(int_frames)
        sub b
        ld hl,draw_digits
        ld b,100
        call .digit
        ld b,10
        call .digit
        add a,'0'
        ld (hl),a
        ld a,0
        ld c,1
        call txt_set_colours
        ld hl,(gfx_width)
        ld de,-15 * 8
        add hl,de
        ld de,2
        ld bc,draw_text
        jp txt_print
; (HL++) = '0' + A / B; A = A mod B
.digit:
        ld c,'0'
.sub:
        cp b
        jr c,.store
        sub b
        inc c
        jr .sub
.store:
        ld (hl),c
        inc hl
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

; ---------------------------------------------------------------------
; draw_charset - DE = y. Codes 32..127, as many per line as fit,
; lines 10 pixels apart. Uses the current text colours.
; ---------------------------------------------------------------------
draw_charset:
        ld (cs_y),de
        ld hl,0
        ld (cs_x),hl
        ld a,32
.char:
        ld (cs_char),a
        ld hl,(cs_x)
        ld de,(cs_y)
        call txt_char
        ld hl,(cs_x)
        ld de,8
        add hl,de
        ld de,(gfx_width)
        or a
        sbc hl,de
        jr c,.same_line
        ld hl,(cs_y)
        ld de,10
        add hl,de
        ld (cs_y),hl
        ld hl,0
        jr .store
.same_line:
        add hl,de
.store:
        ld (cs_x),hl
        ld a,(cs_char)
        inc a
        cp 128
        jr c,.char
        ret

; ---------------------------------------------------------------------
; draw_bars - mode 0: sixteen 12-pixel bars, one per pen
; ---------------------------------------------------------------------
draw_bars:
        xor a
.bar:
        ld (bar_rect + 8),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de                   ; x = pen * 12
        ld (bar_rect),hl
        ld ix,bar_rect
        call gfx_fill_rect
        ld a,(bar_rect + 8)
        inc a
        cp 16
        jr c,.bar
        ret

; ---------------------------------------------------------------------
; draw_diagonal - HL = x, DE = y, B = length, A = pen (45 degrees)
; ---------------------------------------------------------------------
draw_diagonal:
        ld (dg_x),hl
        ld (dg_y),de
        ld (dg_pen),a
.point:
        push bc
        ld hl,(dg_x)
        ld de,(dg_y)
        ld a,(dg_pen)
        call gfx_plot
        ld hl,(dg_x)
        inc hl
        ld (dg_x),hl
        ld hl,(dg_y)
        inc hl
        ld (dg_y),hl
        pop bc
        djnz .point
        ret

; ---- test screens ---------------------------------------------------
list_mode1:
        db 1 : dw 0, 0, 384, 12 : db 1                  ; title bar
        db 2 : dw 8, 2 : db 2, 1, "V-OS 0.02  M1  MODE 1", 0
        db 2 : dw 8, 48 : db 3, 0, "PLOT, RECT AND TEXT ON 32K OVERSCAN", 0
        db 1 : dw 8, 64, 120, 64 : db 1
        db 1 : dw 136, 64, 120, 64 : db 2
        db 1 : dw 264, 64, 112, 64 : db 3
        db 2 : dw 16, 92 : db 2, 1, "PEN 1", 0
        db 2 : dw 144, 92 : db 1, 2, "PEN 2", 0
        db 2 : dw 272, 92 : db 0, 3, "PEN 3", 0
        db 1 : dw 9, 140, 1, 40 : db 1                  ; widths 1..9,
        db 1 : dw 13, 140, 2, 40 : db 3                 ; odd offsets
        db 1 : dw 18, 140, 3, 40 : db 1
        db 1 : dw 24, 140, 4, 40 : db 3
        db 1 : dw 31, 140, 5, 40 : db 1
        db 1 : dw 39, 140, 6, 40 : db 3
        db 1 : dw 48, 140, 7, 40 : db 1
        db 1 : dw 58, 140, 8, 40 : db 3
        db 1 : dw 69, 140, 9, 40 : db 1
        db 2 : dw 8, 188 : db 1, 0, "WIDTHS 1-9 FROM ODD X", 0
        db 2 : dw 8, 248 : db 1, 0, "FRAME: X=0, X=383, Y=271", 0
        db 1 : dw 0, 0, 1, 272 : db 3                   ; frame
        db 1 : dw 383, 0, 1, 272 : db 3
        db 1 : dw 0, 271, 384, 1 : db 3
        db 0

list_mode0:
        db 1 : dw 0, 0, 192, 12 : db 1
        db 2 : dw 4, 2 : db 0, 1, "MODE 0", 0
        db 2 : dw 4, 176 : db 8, 0, "192X272 16 PENS", 0
        db 2 : dw 4, 256 : db 1, 0, "FRAME X=0 191", 0
        db 1 : dw 0, 0, 1, 272 : db 5
        db 1 : dw 191, 0, 1, 272 : db 5
        db 1 : dw 0, 271, 192, 1 : db 5
        db 0

palette_mode1:                      ; Desktop palette
        db 1, 26, 0, 11
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db 0                        ; border
palette_mode0:                      ; Launcher palette
        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
        db 0

bar_rect:   dw 0, 70, 12, 100
            db 0

draw_text:  db "DRAW "
draw_digits: db "000 FRAMES", 0
draw_start: db 0

demo_mode:  db 1
cs_x:       dw 0
cs_y:       dw 0
cs_char:    db 0
dg_x:       dw 0
dg_y:       dw 0
dg_pen:     db 0
