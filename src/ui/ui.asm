; =====================================================================
; ui.asm - menu bar, drop-down menus, focusable buttons
;
; One menu bar and one list of buttons ("widgets") are active at a
; time. The program feeds every event to ui_event, which returns
; A = command number (0 = none) when the user picks a menu item, clicks
; or activates a button, or presses a CONTROL shortcut.
;
; Keys: ESC opens the first menu; in a menu LEFT/RIGHT change menu,
; UP/DOWN the item, RETURN/ENTER/SPACE pick it, ESC closes. Outside
; menus TAB / SHIFT+TAB move the focus and RETURN/ENTER/SPACE activate
; the focused button. While a menu or dialog is open the cursor keys
; navigate instead of moving the pointer.
;
; Mouse: click a title to open its menu, hover to switch menu or item,
; click an item to pick it, click outside to close. Click a button to
; focus and activate it.
;
; Menu bar:  db count, dw menu, menu, ...
; Menu:      db title MSG_*, item count, then per item:
;            db text MSG_* (UI_SEPARATOR = a line), command,
;               shortcut letter (CONTROL+letter, 0 = none), flags (0)
; Widgets:   db count, then per button (8 bytes):
;            dw x, y; db width in characters, text MSG_*, command, 0
;
; Texts come from lang_msg, so menus follow the UI language. The first
; letter of each menu title is underlined.
; =====================================================================

UI_BAR_H        equ 12              ; menu bar height, line 11 is its edge
UI_ITEM_H       equ 10
UI_BUTTON_H     equ 14
UI_SEPARATOR    equ #FF
UI_NONE         equ #FF
UI_SAVE_CFG     equ #C6             ; save-under buffer: bank 6 at #4000
UI_SAVE_ADDR    equ #4000

UIP_DESK        equ 0               ; offsets in ui_pens
UIP_BAR         equ 1               ; bar, menus, dialogs, buttons
UIP_TEXT        equ 2               ; text on UIP_BAR
UIP_SEL         equ 3               ; selection / focus background
UIP_SELTEXT     equ 4
UIP_SHADOW      equ 5
UIP_FRAME       equ 6
UIP_DESKTEXT    equ 7               ; text on the desk
UIP_HEAD        equ 8               ; headings on the desk
UI_PEN_COUNT    equ 9

; ---------------------------------------------------------------------
; ui_set_mode - A = 0, 1 or 2: screen mode plus the UI pens for it
; Destroys: all
; ---------------------------------------------------------------------
ui_set_mode:
        ld c,a
        ld a,(split_on)             ; (mixed screen: always mode 1 pixels)
        or a
        jr nz,.same_mode
        ld a,c                      ; keep the pointer on the same spot:
        ld hl,gfx_mode              ; its x doubles a mode up
        sub (hl)
        jr z,.same_mode
        di
        ld hl,(ptr_x)
        jp p,.up
.down:
        srl h
        rr l
        inc a
        jr nz,.down
        jr .scaled
.up:
        add hl,hl
        dec a
        jr nz,.up
.scaled:
        ld (ptr_x),hl
        ei
.same_mode:
        ld a,c
        push af
        call gfx_set_mode
        pop af
        ld hl,ui_pens_mode0
        ld bc,#0204                 ; shadow: 2 pixels right, 4 down
        ld de,#0104                 ; titles: 1 character wide margins,
        or a                        ; text 4 pixels in, bar from x = 0
        jr z,.copy
        ld hl,ui_pens_mode1
        ld bc,#0404
        ld de,#0208                 ; 2 characters, text 8 pixels in
        cp 2
        jr c,.copy
        ld hl,ui_pens_mode2
        ld b,8                      ; mode 2: the shadow 8 pixels right
.copy:
        ld a,d
        ld (ui_title_pad),a
        ld a,e
        ld (ui_title_off),a
        and 8                       ; first title at 0 (mode 0) or 8
        ld (ui_bar_x),a
        ld a,b
        ld (ui_shadow_x),a
        ld a,c
        ld (ui_shadow_y),a
        ld de,ui_pens
        ld bc,UI_PEN_COUNT
        ldir
        ld a,(cfg_data + CFG_THEME) ; dark: the pens swapped (kernel/
        or a                        ; ext2.asm)
        ret z
        ld hl,ui_dark
        jp ext2_call

; ---------------------------------------------------------------------
; ui_in_band - B = mode, HL = routine, A = its argument: runs it drawing
; in that mode when the screen is mixed (split.asm), then returns to
; the mode it was in. Returns the routine's A.
; ---------------------------------------------------------------------
ui_in_band:
        ld (uz_arg),a
        ld a,(split_on)
        or a
        jr z,.run
        ld a,(gfx_mode)
        cp b
        jr z,.run
        push af                     ; the mode to come back to
        push hl
        ld a,b
        call ui_set_mode
        pop hl
        call .run
        pop bc
        push af
        ld a,b
        call ui_set_mode
        pop af
        ret
.run:
        ld a,(uz_arg)
        jp (hl)

; ---------------------------------------------------------------------
; drawing helpers
; ---------------------------------------------------------------------
; A = UIP_* -> A = pen.  Destroys: HL
ui_pen:
        ld hl,ui_pens
        jp tbl_a

; HL = x, DE = y, BC = width, A = height, (ui_fill_pen) = UIP_*
; Destroys: all except IX
ui_rect:
        push ix
        ld (ui_r),hl
        ld (ui_r + 2),de
        ld (ui_r + 4),bc
        ld (ui_r + 6),a
        xor a
        ld (ui_r + 7),a
        ld a,(ui_fill_pen)
        call ui_pen
        ld (ui_r + 8),a
        ld ix,ui_r
        call gfx_fill_rect
        pop ix
        ret

; one-pixel frame, same arguments as ui_rect
ui_frame:
        ld (uf_x),hl
        ld (uf_y),de
        ld (uf_w),bc
        ld (uf_h),a
        ld a,1
        call ui_rect                ; top
        ld hl,(uf_y)
        ld a,(uf_h)
        dec a
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld hl,(uf_x)
        ld bc,(uf_w)
        ld a,1
        call ui_rect                ; bottom
        ld hl,(uf_x)
        ld de,(uf_y)
        ld bc,1
        ld a,(uf_h)
        call ui_rect                ; left
        ld hl,(uf_x)
        ld bc,(uf_w)
        add hl,bc
        dec hl
        ld de,(uf_y)
        ld bc,1
        ld a,(uf_h)
        jp ui_rect                  ; right

; A = foreground UIP_*, C = background UIP_*.  Destroys: all
ui_colours:
        push af
        ld a,c
        call ui_pen
        ld c,a
        pop af
        push bc
        call ui_pen
        pop bc
        jp txt_set_colours

; HL -> text -> A = length up to the zero or '|'.  Destroys: B
ui_line_len:
        push hl
        ld b,0
.count:
        ld a,(hl)
        or a
        jr z,.done
        cp "|"
        jr z,.done
        inc hl
        inc b
        jr .count
.done:
        ld a,b
        pop hl
        ret

; A = MSG_* -> HL = its text, A = its length (first line).
; Destroys: BC, DE
ui_msg:
        call lang_msg
        jp ui_line_len

; HL = x, DE = y, BC -> text: draw up to the zero, '|' or the right
; edge. Returns BC -> the character that stopped it.  Destroys: all
ui_text_line:
        ld a,(bc)
        or a
        ret z
        cp "|"
        ret z
        push hl                     ; stop at the right edge
        push de
        ld de,8
        add hl,de
        ld de,(gfx_width)
        ex de,hl
        or a
        sbc hl,de
        pop de
        pop hl
        ret c
        push bc
        push de
        push hl
        call txt_char
        pop hl
        pop de
        pop bc
        inc bc
        push de
        ld de,8
        add hl,de
        pop de
        jr ui_text_line

; ---------------------------------------------------------------------
; save-under: one area at a time, kept in bank 6 (16K)
; ui_save - HL = x, DE = y, BC = width, A = height
; ui_restore - put the last saved area back
; Destroys: all except IX
; ---------------------------------------------------------------------
ui_save:
        ld (sv_x),hl
        ld (sv_y),de
        ld (sv_w),bc
        ld (sv_h),a
        call ptr_guard
        call .geometry
        xor a
        jr ui_copy_area
.geometry:
        ld hl,(sv_x)                ; first byte and byte count
        call gfx_x_to_byte
        ld (sv_col),hl
        ld hl,(sv_x)
        ld bc,(sv_w)
        add hl,bc
        dec hl
        call gfx_x_to_byte
        ld de,(sv_col)
        or a
        sbc hl,de
        inc hl
        ld (sv_bytes),hl
        ret

ui_restore:
        ld hl,(sv_x)
        ld de,(sv_y)
        ld bc,(sv_w)
        ld a,(sv_h)
        call ptr_guard
        ld a,1
ui_copy_area:
        ld (sv_dir),a
        ld a,UI_SAVE_CFG
        call ram_select
        ld hl,(sv_y)
        add hl,hl
        ld de,gfx_lines
        add hl,de
        ld (sv_line),hl
        ld hl,UI_SAVE_ADDR
        ld (sv_buf),hl
        ld a,(sv_h)
.row:
        push af
        ld hl,(sv_buf)              ; up to the accessory (ACC_ADDR): the
        ld de,(sv_bytes)            ; rows after that are not kept
        add hl,de
        ld de,ACC_ADDR + 1
        or a
        sbc hl,de
        jr nc,.full
        ld hl,(sv_line)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sv_line),hl
        ld hl,(sv_col)
        add hl,de                   ; HL = screen
        ld de,(sv_buf)
        ld bc,(sv_bytes)
        ld a,(sv_dir)
        or a
        jr z,.to_buf
        ex de,hl
        ldir
        ld (sv_buf),hl
        jr .next
.to_buf:
        ldir
        ld (sv_buf),de
.next:
        pop af
        dec a
        jr nz,.row
        jp ram_home
.full:
        pop af
        jp ram_home

; ---------------------------------------------------------------------
; Windows for dialogs: uw_w (dw) and uw_h (db) set by the caller.
; ui_centre       uw_x, uw_y centre the window (x a multiple of 8;
;                 with a mixed screen, in the mode 0 band)
; ui_save_window  save what the window and its shadow cover
; ui_window       A = title MSG_*: shadow, box, frame, title bar
; Destroy: all except IX
; ---------------------------------------------------------------------
ui_centre:
        ld hl,(gfx_width)
        ld de,(uw_w)
        or a
        sbc hl,de
        srl h
        rr l
        ld a,l
        and %11111000
        ld l,a
        ld (uw_x),hl
        ld a,(uw_h)                 ; in the mode 0 band of a mixed
        ld e,a                      ; screen, if drawn in mode 0
        ld d,0
        ld hl,GFX_H
        ld bc,0
        ld a,(split_on)
        or a
        jr z,.height
        ld a,(gfx_mode)
        or a
        jr nz,.height
        ld hl,(split_y2)
        ld bc,(split_y1)
        sbc hl,bc                   ; carry is clear
.height:
        or a
        sbc hl,de
        jr nc,.fits
        ld hl,0
.fits:
        srl h
        rr l
        add hl,bc
        ld (uw_y),hl
        ret

ui_save_window:
        ld a,(ui_shadow_x)
        ld c,a
        ld b,0
        ld hl,(uw_w)
        add hl,bc
        ld b,h
        ld c,l
        ld a,(ui_shadow_y)
        ld hl,uw_h
        add a,(hl)
        ld hl,(uw_x)
        ld de,(uw_y)
        jp ui_save

ui_window:
        ld (uw_title),a
        ld a,UIP_SHADOW
        ld (ui_fill_pen),a
        ld hl,(uw_x)
        ld a,(ui_shadow_x)
        ld e,a
        ld d,0
        add hl,de
        ld de,(uw_y)
        ld a,(ui_shadow_y)
        add a,e
        ld e,a
        ld a,0
        adc a,d
        ld d,a
        ld bc,(uw_w)
        ld a,(uw_h)
        call ui_rect
        ld a,UIP_BAR
        call .rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        call .geometry
        call ui_frame
        ld a,UIP_SEL                ; title bar
        ld (ui_fill_pen),a
        call .geometry
        ld a,12
        call ui_rect
        ld a,UIP_SELTEXT
        ld c,UIP_SEL
        call ui_colours
        ld a,(uw_title)
        call ui_msg
        push hl
        call ui_centre_text
        ld de,(uw_y)
        inc de
        inc de
        pop bc
        jp ui_text_line
.rect:
        ld (ui_fill_pen),a
        call .geometry
        jp ui_rect
.geometry:
        ld hl,(uw_x)
        ld de,(uw_y)
        ld bc,(uw_w)
        ld a,(uw_h)
        ret

; ---------------------------------------------------------------------
; Moving windows (kernel/ext.asm, drag_run)
; ui_drag  HL = x, DE = y, BC = width, A = height, ev_cur a click: on
;          the top 10 rows the window is dragged as an outline ->
;          carry: it moved, HL, DE = where it is now
; ui_fit   the same window -> HL, DE: on the screen
; ui_move  ui_drag with the uw_ window (dialogs) -> carry: it moved,
;          what it covered is back, what it covers now is saved; draw
;          it again
; Destroy: all except IX
; ---------------------------------------------------------------------
ui_fit:
        ld (dr_h),a
        xor a
        jr ui_drag_go
ui_drag:
        ld (dr_h),a
        ld a,1
ui_drag_go:
        ld (dr_drag),a
        ld (dr_x),hl
        ld (dr_w),bc
        ld hl,drag_run              ; (DE goes through, HL and DE come
        jp ext2_call                ; back)

ui_move:
        ld hl,drag_window
        jp ext2_call

; ui_busy - A = MSG_*: a small "please wait" window with that text,
; while the disc works. ui_restore takes it away.
ui_busy:
        ld (uw_title),a
        call ui_msg
        ld b,a
        push bc
        ld a,MSG_WAIT
        call ui_msg
        pop bc
        cp b
        jr c,.width
        ld b,a
.width:
        ld a,b
        add a,4
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (uw_w),hl
        ld a,34
        ld (uw_h),a
        call ui_centre
        call ui_save_window
        ld a,(uw_title)
        push af
        ld a,MSG_WAIT
        call ui_window
        ld a,UIP_TEXT
        ld c,UIP_BAR
        call ui_colours
        pop af
        call lang_msg
        ld b,h
        ld c,l
        ld hl,(uw_x)
        ld de,16
        add hl,de
        ld de,(uw_y)
        ld a,18
        add a,e
        ld e,a
        jr nc,.y
        inc d
.y:
        jp txt_print

; A = characters -> HL = x that centres them in the window (multiple of 8)
ui_centre_text:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,(uw_w)
        or a
        sbc hl,de
        srl h
        rr l
        ld a,l
        and %11111000
        ld l,a
        ld de,(uw_x)
        add hl,de
        ret

; ---------------------------------------------------------------------
; ui_set_bar - HL = menu bar. ui_draw_bar draws it.
; ---------------------------------------------------------------------
ui_set_bar:
        ld (ui_bar),hl
        ld a,UI_NONE
        ld (ui_open),a
        ret

; HL -> menu A.  Destroys: DE
ui_menu_ptr:
        ld hl,(ui_bar)
        inc hl
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

ui_draw_bar:                        ; the bar is in the top band
        ld b,1
        ld hl,ui_bar_body
        jp ui_in_band
ui_bar_body:
        ld a,UIP_BAR
        ld (ui_fill_pen),a
        ld hl,0
        ld de,0
        ld bc,(gfx_width)
        ld a,UI_BAR_H - 1
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,0
        ld de,UI_BAR_H - 1
        ld bc,(gfx_width)
        ld a,1
        call ui_rect
        ld a,(ui_bar_x)             ; title positions
        ld l,a
        ld h,0
        ld (ub_x),hl
        xor a
.title:
        ld (ub_i),a
        ld hl,(ui_bar)
        cp (hl)
        jr nc,.done
        ld hl,ui_title_x            ; ui_title_x[i] = x
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld de,(ub_x)
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(ub_i)
        call ui_draw_title          ; A = width in characters + 2
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(ub_x)
        add hl,de
        ld (ub_x),hl
        ld a,(ub_i)
        inc a
        jr .title
.done:
        ld hl,(ub_x)                ; room left for the indicator?
        ld de,24
        add hl,de
        ld de,(gfx_width)
        ex de,hl
        or a
        sbc hl,de
        ld a,0
        jr c,.no_room
        inc a
.no_room:
        ld (ui_ind_room),a
        jp ui_draw_indicator

; A = menu. Draws its title, open or closed. Returns A = its width in
; characters (text + ui_title_pad), also stored in ui_title_w.
ui_draw_title:
        ld b,1
        ld hl,ui_title_body
        jp ui_in_band
ui_title_body:
        ld (ut_i),a
        call ui_menu_ptr
        ld a,(hl)
        call ui_msg                 ; HL = text, A = length
        ld (ut_text),hl
        ld hl,ui_title_pad
        add a,(hl)
        ld (ut_w),a
        ld hl,ui_title_w
        ld a,(ut_i)
        ld e,a
        ld d,0
        add hl,de
        ld a,(ut_w)
        ld (hl),a
        ld a,(ut_i)                 ; x
        add a,a
        ld e,a
        ld hl,ui_title_x
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (ut_x),de
        ld a,(ut_i)                 ; colours: open title inverted
        ld hl,ui_open
        cp (hl)
        ld a,UIP_BAR
        ld bc,UIP_TEXT * 256 + UIP_BAR
        jr nz,.colours
        ld a,UIP_SEL
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        ld (ui_fill_pen),a
        ld (ut_colours),bc
        ld a,(ut_w)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,(ut_x)
        ld de,0
        ld a,UI_BAR_H - 1
        call ui_rect
        ld a,(ut_colours + 1)       ; underline the first letter
        ld (ui_fill_pen),a
        ld hl,(ut_x)
        ld a,(ui_title_off)
        ld e,a
        ld d,0
        add hl,de
        ld de,UI_BAR_H - 2
        ld bc,8
        ld a,1
        call ui_rect
        ld a,(ut_colours + 1)
        ld bc,(ut_colours)
        call ui_colours
        ld hl,(ut_x)
        ld a,(ui_title_off)
        ld e,a
        ld d,0
        add hl,de
        ld de,1
        ld bc,(ut_text)
        call ui_text_line
        ld a,(ut_w)
        ret

; keyboard language at the right end of the bar: "EN" or the code of
; the keyboard in use (kbd_code)
ui_draw_indicator:
        ld b,1
        ld hl,ui_ind_body
        jp ui_in_band
ui_ind_body:
        ld a,(ui_ind_room)
        or a
        ret z
        ld hl,str_en
        ld a,(lang_input)
        or a
        jr z,.code
        ld hl,kbd_code
.code:
        ld de,ind_text
        ldi
        ldi
        ld a,UIP_SELTEXT
        ld c,UIP_SEL
        call ui_colours
        ld hl,(gfx_width)
        ld de,-24
        add hl,de
        ld de,1
        ld bc,ind_text
        jp txt_print

; ---------------------------------------------------------------------
; drop-down menus
; ---------------------------------------------------------------------
; A = menu: open it
ui_open_menu:
        ld (ui_open),a
        call ui_draw_title
        ld b,0                      ; the menu is in the mode 0 band
        ld hl,ui_drop_body
        jp ui_in_band
ui_drop_body:
        ld a,(ui_open)
        call ui_menu_ptr
        inc hl
        ld a,(hl)
        ld (dd_count),a
        inc hl
        ld (dd_items),hl
        ; width: longest text (+3 with a shortcut) + 2 characters
        xor a
        ld (dd_chars),a
        ld (dd_i),a
.measure:
        ld a,(dd_i)
        ld hl,dd_count
        cp (hl)
        jr nc,.measured
        call dd_item_ptr
        ld a,(hl)
        cp UI_SEPARATOR
        jr z,.next_measure
        push hl
        call ui_msg
        pop hl
        inc hl
        inc hl
        ld c,a
        ld a,(hl)                   ; shortcut?
        or a
        ld a,c
        jr z,.no_key
        add a,3
.no_key:
        ld hl,dd_chars
        cp (hl)
        jr c,.next_measure
        ld (hl),a
.next_measure:
        ld hl,dd_i
        inc (hl)
        jr .measure
.measured:
        ld a,(dd_chars)
        add a,2
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (dd_w),hl
        ld a,(dd_count)             ; height
        ld b,a
        xor a
.height:
        add a,UI_ITEM_H
        djnz .height
        add a,4
        ld (dd_h),a
        ld a,(ui_open)              ; x under the title, kept on screen
        add a,a
        ld e,a
        ld d,0
        ld hl,ui_title_x
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(split_on)             ; title x in mode 1 pixels
        or a
        jr z,.x_mode
        srl d
        rr e
.x_mode:
        ld (dd_x),de
        ld hl,(dd_w)
        add hl,de
        ld a,(ui_shadow_x)
        ld e,a
        ld d,0
        add hl,de                   ; right edge with shadow
        ld de,(gfx_width)
        or a
        sbc hl,de
        jr c,.x_ok
        jr z,.x_ok
        ex de,hl                    ; x -= overflow
        ld hl,(dd_x)
        or a
        sbc hl,de
        ld (dd_x),hl
.x_ok:
        ld hl,(dd_x)                ; save what the menu covers
        ld de,UI_BAR_H
        ld a,(ui_shadow_x)
        ld c,a
        ld b,0
        push hl
        ld hl,(dd_w)
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        ld a,(ui_shadow_y)
        push hl
        ld hl,dd_h
        add a,(hl)
        pop hl
        call ui_save
        ld a,UIP_SHADOW             ; shadow
        ld (ui_fill_pen),a
        ld hl,(dd_x)
        ld a,(ui_shadow_x)
        ld e,a
        ld d,0
        add hl,de
        ld a,(ui_shadow_y)
        add a,UI_BAR_H
        ld e,a
        ld bc,(dd_w)
        ld a,(dd_h)
        call ui_rect
        ld a,UIP_BAR                ; box
        ld (ui_fill_pen),a
        ld hl,(dd_x)
        ld de,UI_BAR_H
        ld bc,(dd_w)
        ld a,(dd_h)
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,(dd_x)
        ld de,UI_BAR_H
        ld bc,(dd_w)
        ld a,(dd_h)
        call ui_frame
        xor a                       ; first item that is not a line
        ld (ui_sel),a
        call dd_item_ptr
        ld a,(hl)
        cp UI_SEPARATOR
        jr nz,.items
        ld a,1
        ld (ui_sel),a
.items:
        xor a
.item:
        ld (dd_i),a
        ld hl,dd_count
        cp (hl)
        jr nc,.drawn
        call ui_draw_item
        ld a,(dd_i)
        inc a
        jr .item
.drawn:
        ld hl,ptr_keys_on           ; cursor keys now move the selection;
        ld a,(hl)                   ; afterwards, what they did before
        ld (ui_keys_was),a
        ld (hl),0
        ret

; A = item -> HL -> its 4 bytes.  Destroys: DE
dd_item_ptr:
        ld hl,(dd_items)
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ret

; A = item: draw it (selected or not)
ui_draw_item:
        ld b,0
        ld hl,ui_item_body
        jp ui_in_band
ui_item_body:
        ld (di_i),a
        ld b,a                      ; y = UI_BAR_H + 2 + item * 10
        ld a,UI_BAR_H + 2
        inc b
        jr .y_first
.y_add:
        add a,UI_ITEM_H
.y_first:
        djnz .y_add
        ld (di_y),a
        ld a,(di_i)
        call dd_item_ptr
        ld (di_ptr),hl
        ld a,(hl)
        cp UI_SEPARATOR
        jr nz,.text
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,(dd_x)
        ld de,4
        add hl,de
        ld a,(di_y)
        add a,4
        ld e,a
        ld d,0
        ld bc,(dd_w)
        push hl
        ld hl,-8
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        ld a,1
        jp ui_rect
.text:
        ld a,(di_i)
        ld hl,ui_sel
        cp (hl)
        ld a,UIP_BAR
        ld bc,UIP_TEXT * 256 + UIP_BAR
        jr nz,.colours
        ld a,UIP_SEL
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        ld (ui_fill_pen),a
        ld (ut_colours),bc
        ld hl,(dd_x)
        inc hl
        inc hl
        ld a,(di_y)
        ld e,a
        ld d,0
        ld bc,(dd_w)
        dec bc
        dec bc
        dec bc
        dec bc
        ld a,UI_ITEM_H
        call ui_rect
        ld a,(ut_colours + 1)
        ld bc,(ut_colours)
        call ui_colours
        ld hl,(di_ptr)
        ld a,(hl)
        call lang_msg
        ld b,h
        ld c,l
        ld hl,(dd_x)
        ld de,8
        add hl,de
        ld a,(di_y)
        inc a
        ld e,a
        ld d,0
        call ui_text_line
        ld hl,(di_ptr)              ; "^K" at the right
        inc hl
        inc hl
        ld a,(hl)
        or a
        ret z
        ld (shortcut_text + 1),a
        ld hl,(dd_x)
        ld bc,(dd_w)
        add hl,bc
        ld de,-24
        add hl,de
        ld a,(di_y)
        inc a
        ld e,a
        ld d,0
        ld bc,shortcut_text
        jp txt_print

ui_close_menu:
        ld a,(ui_open)
        cp UI_NONE
        ret z
        ld b,0
        ld hl,ui_restore
        call ui_in_band
        ld a,(ui_open)
        ld b,a
        ld a,UI_NONE
        ld (ui_open),a
        ld a,b
        call ui_draw_title
        ld a,(ui_keys_was)
        ld (ptr_keys_on),a
        ret

; A = menu: close the open one and open A
ui_switch_menu:
        push af
        call ui_close_menu
        pop af
        jp ui_open_menu

; A = item: select it and redraw both
ui_select_item:
        ld hl,ui_sel
        ld b,(hl)
        ld (hl),a
        ld a,b
        call ui_draw_item
        ld a,(ui_sel)
        jp ui_draw_item

; D = +1 or -1: next selectable item in that direction
ui_move_sel:
        ld a,(ui_sel)
        ld e,a
.next:
        ld a,e
        add a,d
        ld e,a
        cp #FF
        jr nz,.not_before
        ld a,(dd_count)
        dec a
        ld e,a
.not_before:
        ld a,e
        ld hl,dd_count
        cp (hl)
        jr c,.inside
        ld e,0
.inside:
        ld a,e
        push de
        call dd_item_ptr
        pop de
        ld a,(hl)
        cp UI_SEPARATOR
        jr z,.next
        ld a,e
        jp ui_select_item

; A = command of the selected item; the menu is closed
ui_pick_item:
        ld a,(ui_sel)
        call dd_item_ptr
        inc hl
        ld a,(hl)
        push af
        call ui_close_menu
        pop af
        ret

; menu title under (ev_cur x) -> A = menu or UI_NONE
ui_title_hit:
        ld hl,(ui_bar)
        ld b,(hl)
        ld c,0
.title:
        ld a,c
        cp b
        jr nc,.none
        add a,a
        ld e,a
        ld d,0
        ld hl,ui_title_x
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)                   ; DE = title x
        ld hl,(ev_cur + 4)
        or a
        sbc hl,de
        jr c,.next
        push hl
        ld hl,ui_title_w
        ld e,c
        ld d,0
        add hl,de
        ld a,(hl)
        pop hl
        add a,a
        add a,a
        add a,a                     ; width in pixels (< 256)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        jr c,.found
.next:
        inc c
        jr .title
.found:
        ld a,c
        ret
.none:
        ld a,UI_NONE
        ret

; item under (ev_cur x, y) -> A = item or UI_NONE (outside the menu)
ui_item_hit:
        ld hl,(ev_cur + 4)
        ld de,(dd_x)
        or a
        sbc hl,de
        jr c,.none
        ld de,(dd_w)
        or a
        sbc hl,de
        jr nc,.none
        ld hl,(ev_cur + 6)
        ld de,UI_BAR_H + 2
        or a
        sbc hl,de
        jr c,.none
        ld a,h
        or a
        jr nz,.none
        ld a,l
        ld c,0
.row:
        sub UI_ITEM_H
        jr c,.found
        inc c
        jr .row
.found:
        ld a,c
        ld hl,dd_count
        cp (hl)
        ret c
.none:
        ld a,UI_NONE
        ret

; ---------------------------------------------------------------------
; widgets (buttons) and focus
; ---------------------------------------------------------------------
; HL = widget list. Focus goes to the first one.
ui_set_widgets:
        ld (ui_widgets),hl
        xor a
        ld (ui_focus),a
        ret

ui_draw_widgets:
        ld hl,(ui_widgets)
        ld a,(hl)
        or a
        ret z
        ld b,a
        xor a
.widget:
        push af
        push bc
        call ui_draw_widget
        pop bc
        pop af
        inc a
        djnz .widget
        ret

; A = widget -> HL -> its 8 bytes.  Destroys: DE
ui_widget_ptr:
        ld l,a                      ; (in 16 bits: up to 255 widgets)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(ui_widgets)
        add hl,de
        inc hl
        ret

; A = widget: draw the button, focused or not
ui_draw_widget:
        ld (dw_i),a
        call ui_widget_ptr
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (dw_x),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (dw_y),de
        ld a,(hl)
        ld (dw_chars),a
        inc hl
        ld a,(hl)
        ld (dw_msg),a
        ld a,(dw_i)
        ld hl,ui_focus
        cp (hl)
        ld a,UIP_BAR
        ld bc,UIP_TEXT * 256 + UIP_BAR
        jr nz,.colours
        ld a,UIP_SEL
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        ld (ui_fill_pen),a
        ld (ut_colours),bc
        ld a,(dw_chars)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (dw_w),hl
        ld b,h
        ld c,l
        ld hl,(dw_x)
        ld de,(dw_y)
        ld a,UI_BUTTON_H
        call ui_rect
        ld a,UIP_FRAME
        ld (ui_fill_pen),a
        ld hl,(dw_x)
        ld de,(dw_y)
        ld bc,(dw_w)
        ld a,UI_BUTTON_H
        call ui_frame
        ld a,(ut_colours + 1)
        ld bc,(ut_colours)
        call ui_colours
        ld a,(dw_msg)
        call ui_msg                 ; centre the text
        ld b,h
        ld c,l
        ld e,a
        ld a,(dw_chars)
        sub e
        jr nc,.fits
        xor a
.fits:
        add a,a
        add a,a                     ; (chars - length) * 4
        ld l,a
        ld h,0
        ld de,(dw_x)
        add hl,de
        ld de,(dw_y)
        inc de
        inc de
        inc de
        jp ui_text_line

; A = widget to focus
ui_set_focus:
        ld hl,ui_focus
        ld b,(hl)
        ld (hl),a
        cp b
        ret z
        ld a,b
        call ui_draw_widget
        ld a,(ui_focus)
        jp ui_draw_widget

; D = +1 or -1
ui_move_focus:
        ld hl,(ui_widgets)
        ld b,(hl)
        ld a,b
        or a
        ret z
        ld a,(ui_focus)
        add a,d
        cp #FF
        jr nz,.not_before
        ld a,b
        dec a
.not_before:
        cp b
        jr c,ui_set_focus
        xor a
        jr ui_set_focus

; A = command of the focused widget
ui_activate:
        ld hl,(ui_widgets)
        ld a,(hl)
        or a
        ret z
        ld a,(ui_focus)
        call ui_widget_ptr
        ld de,6                     ; x, y, width, text, command
        add hl,de
        ld a,(hl)
        ret

; HL = x, DE = y -> A = widget there or UI_NONE
ui_widget_hit:
        ld (wh_x),hl
        ld (wh_y),de
        ld hl,(ui_widgets)
        ld a,(hl)
        or a
        jr z,.none
        ld b,a
        ld c,0
.widget:
        push bc
        ld a,c
        call ui_widget_ptr
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl                      ; DE = x
        push hl
        ld hl,(wh_x)
        or a
        sbc hl,de
        pop de                      ; DE -> y
        jr c,.next
        push hl                     ; x offset
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)                   ; width in characters
        ld hl,(wh_y)
        or a
        sbc hl,de
        pop de                      ; DE = x offset
        jr c,.next
        push af
        ld a,h                      ; y offset < UI_BUTTON_H ?
        or a
        jr nz,.next_af
        ld a,l
        cp UI_BUTTON_H
        jr nc,.next_af
        pop af
        ld l,a                      ; x offset < width ?
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        jr c,.next
        jr z,.next
        pop bc
        ld a,c
        ret
.next_af:
        pop af
.next:
        pop bc
        inc c
        djnz .widget
.none:
        ld a,UI_NONE
        ret

; ---------------------------------------------------------------------
; ui_event - handle ev_cur. Returns A = command (0 = none).
; ---------------------------------------------------------------------
ui_event:
        ld a,(ev_cur)
        cp EV_LANG
        jr nz,.not_lang
        call ui_draw_indicator
        xor a
        ret
.not_lang:
        ld b,a
        ld a,(ui_open)
        cp UI_NONE
        ld a,b
        jp nz,ui_menu_event
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
        ld hl,(ev_cur + 6)
        ld de,UI_BAR_H
        or a
        sbc hl,de
        jr nc,.body
        call ui_title_hit
        cp UI_NONE
        jr z,.none
        call ui_open_menu
        jr .none
.body:
        ld hl,(ev_cur + 4)
        ld de,(ev_cur + 6)
        call ui_widget_hit
        cp UI_NONE
        jr z,.none
        call ui_set_focus
        jp ui_activate
.key:
        ld a,(ev_cur + 1)
        cp KEY_ESC
        jr nz,.not_esc
        xor a
        call ui_open_menu
        jr .none
.not_esc:
        cp KEY_TAB
        jr nz,.not_tab
        ld d,1
        ld a,(ev_cur + 3)
        and MOD_SHIFT
        jr z,.tab
        ld d,-1
.tab:
        call ui_move_focus
        jr .none
.not_tab:
        cp KEY_RETURN
        jp z,ui_activate
        cp KEY_ENTER
        jp z,ui_activate
        ld a,(ev_cur + 2)
        cp " "
        jp z,ui_activate
        ld a,(ev_cur + 3)           ; CONTROL + letter
        and MOD_CONTROL
        jr z,.none
        ld a,(ev_cur + 2)
        or a
        jr z,.none
        cp 27
        jr nc,.none
        jp ui_find_shortcut

; A = control code 1..26 -> A = command of the item with that shortcut
ui_find_shortcut:
        ld (fs_code),a
        xor a
.menu:
        ld (fs_menu),a
        ld hl,(ui_bar)
        cp (hl)
        jr nc,.none
        call ui_menu_ptr
        inc hl
        ld b,(hl)                   ; items
        inc hl
.item:
        inc hl
        inc hl
        ld a,(hl)                   ; shortcut letter
        inc hl
        inc hl
        or a
        jr z,.next
        and 31
        push hl
        ld hl,fs_code
        cp (hl)
        pop hl
        jr nz,.next
        dec hl                      ; back to the command byte
        dec hl
        dec hl
        ld a,(hl)
        ret
.next:
        djnz .item
        ld a,(fs_menu)
        inc a
        jr .menu
.none:
        xor a
        ret

; event while a menu is open
ui_menu_event:
        cp EV_PTR_MOVE
        jr z,.move
        cp EV_PTR_DOWN
        jr z,.click
        cp EV_KEY_DOWN
        jr z,.key
        cp EV_KEY_REPEAT
        jr z,.key
.none:
        xor a
        ret
.move:
        ld hl,(ev_cur + 6)
        ld de,UI_BAR_H
        or a
        sbc hl,de
        jr nc,.move_items
        call ui_title_hit
        cp UI_NONE
        jr z,.none
        ld hl,ui_open
        cp (hl)
        jr z,.none
        call ui_switch_menu
        jp .none
.move_items:
        call ui_item_hit
        cp UI_NONE
        jr z,.none
        ld hl,ui_sel
        cp (hl)
        jr z,.none
        ld c,a
        call dd_item_ptr
        ld a,(hl)
        cp UI_SEPARATOR
        jr z,.none
        ld a,c
        call ui_select_item
        jp .none
.click:
        ld hl,(ev_cur + 6)
        ld de,UI_BAR_H
        or a
        sbc hl,de
        jr nc,.click_items
        call ui_title_hit
        cp UI_NONE
        jr z,.close
        ld hl,ui_open
        cp (hl)
        jr z,.close
        call ui_switch_menu
        jp .none
.click_items:
        call ui_item_hit
        cp UI_NONE
        jr z,.close
        ld c,a
        call dd_item_ptr
        ld a,(hl)
        cp UI_SEPARATOR
        jr z,.none
        ld a,c
        ld (ui_sel),a
        jp ui_pick_item
.close:
        call ui_close_menu
        jp .none
.key:
        ld a,(ev_cur + 1)
        cp KEY_ESC
        jr z,.close
        cp KEY_RETURN
        jp z,ui_pick_item
        cp KEY_ENTER
        jp z,ui_pick_item
        cp KEY_UP
        jr z,.up
        cp KEY_DOWN
        jr z,.down
        cp KEY_LEFT
        jr z,.left
        cp KEY_RIGHT
        jr z,.right
        ld a,(ev_cur + 2)
        cp " "
        jp z,ui_pick_item
        jp .none
.up:
        ld d,-1
        call ui_move_sel
        jp .none
.down:
        ld d,1
        call ui_move_sel
        jp .none
.left:
        ld a,(ui_open)
        or a
        jr nz,.left_one
        ld hl,(ui_bar)
        ld a,(hl)
.left_one:
        dec a
        call ui_switch_menu
        jp .none
.right:
        ld a,(ui_open)
        inc a
        ld hl,(ui_bar)
        cp (hl)
        jr c,.right_one
        xor a
.right_one:
        call ui_switch_menu
        jp .none

; ---- pens per mode --------------------------------------------------
;                  desk bar text sel seltx shadow frame desktext head
ui_pens_mode1:  db 0,   1,  2,   2,  1,    2,     2,    1,       3
ui_pens_mode0:  db 2,   1,  0,   0,  1,    0,     0,    1,       8
ui_pens_mode2:  db 0,   0,  1,   1,  0,    1,     1,    1,       1

; ---- state ----------------------------------------------------------
ui_pens:        ds UI_PEN_COUNT
uw_x:           dw 0                ; window of the open dialog
uw_y:           dw 0
uw_w:           dw 0
uw_h:           db 0
uw_title:       db 0
ui_shadow_x:    db 4
ui_shadow_y:    db 4
ui_fill_pen:    db 0
ui_r:           dw 0, 0, 0, 0
                db 0
uf_x:           dw 0
uf_y:           dw 0
uf_w:           dw 0
uf_h:           db 0

ui_bar:         dw 0
ui_open:        db UI_NONE
ui_keys_was:    db 0                ; ptr_keys_on before the menu opened
ui_sel:         db 0
ui_title_x      equ GAP1 + 741      ; 2 * 8
ui_title_pad:   db 2
ui_title_off:   db 8
ui_bar_x:       db 8
ui_ind_room:    db 1
uz_arg:         db 0
ui_title_w      equ GAP1 + 757      ; 8
ub_x:           dw 0
ub_i:           db 0
ut_i:           db 0
ut_w:           db 0
ut_x:           dw 0
ut_text:        dw 0
ut_colours:     dw 0
ind_text:       db "EN", 0
str_en:         db "EN"
shortcut_text:  db "^?", 0

dd_count:       db 0
dd_items:       dw 0
dd_chars:       db 0
dd_i:           db 0
dd_x:           dw 0
dd_w:           dw 0
dd_h:           db 0
di_i:           db 0
di_y:           db 0
di_ptr:         dw 0
fs_code:        db 0
fs_menu:        db 0

ui_widgets:     dw ui_no_widgets
ui_focus:       db 0
ui_no_widgets:  db 0
dw_i:           db 0
dw_x:           dw 0
dw_y:           dw 0
dw_w:           dw 0
dw_chars:       db 0
dw_msg:         db 0
wh_x:           dw 0
wh_y:           dw 0

sv_x:           dw 0
sv_y:           dw 0
sv_w:           dw 0
sv_h:           db 0
sv_col:         dw 0
sv_bytes:       dw 0
sv_dir:         db 0
sv_line:        dw 0
sv_buf:         dw 0
