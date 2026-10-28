; =====================================================================
; studio.asm - Studio: block programs edited on the CPC itself
;
; A mixed screen (VOS_SPLIT): the menu bar in mode 1; the stage and the
; sprites in mode 0, 16 colours (lines 12..137); the block palette, the
; script and a status line in mode 1, 48 columns (138..258).
;
;   +----------------------------------------------+  mode 1
;   | STUDIO  EDIT  VIEW  HELP                     |
;   +---------------------+------------------------+  mode 0
;   | stage, half size    | sprites: colour, x y   |
;   +----------+----------+------------------------+  mode 1
;   | palette  | the script, one block a line      |
;   +----------+-----------------------------------+
;   | status: what the keys do                     |
;   +----------------------------------------------+
;
; A program is a list of lines (blocks). "WHEN ..." lines start a
; script for a sprite or the stage; FOREVER, REPEAT and IF open a
; block that END closes, so the script is indented from the lines
; alone. Each line has up to three slots (numbers, variables A..H,
; sprite x, y, random, key held, touching, at an edge, comparisons).
;
; Keys: TAB moves between the script, the palette and the stage.
; Script: UP/DOWN choose the line, LEFT/RIGHT a slot, RETURN adds the
; palette's block below, CLR deletes the line; with a slot chosen,
; typing edits it (the status line says how). Palette: arrows choose,
; RETURN adds. Stage: arrows move the sprite, 1-6 choose one, C colour,
; W/H size. Mouse: a click on a palette block adds it, on a slot
; chooses it, on the chosen slot changes its kind; a click on the stage
; places the sprite.
;
; Files: STUDIO > SAVE writes NAME.VBS (the VBS record below, as a
; binary file); OPEN reads it back. Running the program is the next
; step (M8c: compiling it here to a .BIN).
;
; Built on its own (Makefile), with texts.asm made by tools/mktexts.py:
;   rasm apps/studio/studio.asm -I src -I build -o build/studio
; =====================================================================

        include "api/vos_api.inc"

Y1              equ 12              ; mode 0 from under the menu bar
Y2              equ 138             ; mode 1 again (waits 13 lines)

; mode 1 bands: pens 0..3
P_DESK          equ 0               ; blue
P_PAPER         equ 1               ; white
P_INK           equ 2               ; black
P_SEL           equ 3               ; sky blue
; mode 0 band
Q_BLACK         equ 0
Q_WHITE         equ 1
Q_BLUE          equ 2
Q_LIGHT         equ 3

ROW_H           equ 10
ED_Y            equ Y2              ; editor rows
ED_ROWS         equ 11              ; script rows; then the status line
STATUS_Y        equ ED_Y + ED_ROWS * ROW_H
PAL_W           equ 112             ; palette: 14 characters
SC_X            equ PAL_W           ; script
SC_TX           equ SC_X + 4
SC_COLS         equ 33
SC_W            equ 384 - SC_X

STG_X           equ 1               ; stage preview (mode 0), half size
STG_Y           equ Y1 + 1
STG_W           equ 96
STG_H           equ 124
LIST_X          equ 104             ; sprite list
LIST_Y          equ 26
LIST_H          equ 12

; ---- the program (VBS) ----------------------------------------------
; db "VBS", version; db background pen, sprite count;
; SPR_MAX sprites (dw x, y; db w, h, colour, 0); dw line count; lines.
; A line: db OP_*, then 3 slots of db K_*, dw value.
SPR_MAX         equ 6
SPR_SIZE        equ 8
LINE_SIZE       equ 10
MAX_LINES       equ 200
V_BG            equ 4
V_NSPR          equ 5
V_SPR           equ 6
V_NLINES        equ V_SPR + SPR_MAX * SPR_SIZE
V_LINES         equ V_NLINES + 2
VBS_ROOM        equ 3 * 1024        ; files of up to 3K are read

; slot kinds
K_NONE          equ 0
K_NUM           equ 1               ; signed number
K_VAR           equ 2               ; variable 0..7 (A..H)
K_X             equ 3               ; the script's sprite
K_Y             equ 4
K_RND           equ 5               ; random 1..value
K_KEY           equ 6               ; 1 while key (value) is held
K_TOUCH         equ 7               ; 1 while touching sprite (value)
K_EDGE          equ 8               ; 1 at an edge of the stage
K_CMP           equ 9               ; 0 <, 1 =, 2 >
K_SPR           equ 10              ; 0 the stage, 1..6 a sprite
K_KEYN          equ 11              ; a key (WHEN KEY)
; what a slot may hold
C_NONE          equ 0
C_VALUE         equ 1               ; K_NUM..K_EDGE
C_VAR           equ 2
C_CMP           equ 3               ; K_CMP or K_NONE
C_SPR           equ 4
C_KEYN          equ 5
; block flags
F_HAT           equ 1               ; starts a script
F_OPEN          equ 2               ; opens a block, END closes it
F_ELSE          equ 4
F_END           equ 8
F_COND          equ 16              ; slot 1 compares; none: no slot 2

OP_START        equ 0
OP_FOREVER      equ 3
OP_IF           equ 5
OP_ELSE         equ 6
OP_END          equ 7
OP_SPEED        equ 14
OP_MOVE         equ 15
OP_BOUNCE       equ 16
OP_COUNT        equ 24
OP_INFO         equ 13              ; flags, 3 classes, 3 default slots

FOCUS_SCRIPT    equ 0
FOCUS_PAL       equ 1
FOCUS_STAGE     equ 2

R_SCRIPT        equ 1               ; what refresh draws again
R_PAL           equ 2
R_STAGE         equ 4
R_STATUS        equ 8
R_LINE          equ 16              ; only the cursor's line, old and new

CMD_NEW         equ 1
CMD_OPEN        equ 2
CMD_SAVE        equ 3
CMD_SAVE_AS     equ 4
CMD_BACK        equ 5
CMD_DELETE      equ 6
CMD_ADD_SPRITE  equ 7
CMD_DEL_SPRITE  equ 8
CMD_BG          equ 9

KEY_CLR         equ 16
ERR_BAD_NAME    equ 11              ; system error texts (fs.asm)
ERR_NOT_PROGRAM equ 12
ERR_NOT_FOUND   equ 7

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION

init:
        ld hl,texts
        call VOS_TEXTS
        xor a
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
        ld hl,split
        call VOS_SPLIT
        call VOS_MENU_VIEW
        ld (bar + 5),hl
        call VOS_MENU_HELP
        ld (bar + 7),hl
        ld hl,bar
        call VOS_SET_BAR
        call prog_new
        ; fall through

; ---------------------------------------------------------------------
; redraw - everything (also after the language changes)
; ---------------------------------------------------------------------
redraw:
        ld a,#FF
        ld (rf_parts),a
        ld a,Q_BLUE
        call VOS_CLS
        call VOS_DRAW_BAR
        call draw_stage
        call mode1
        ld a,P_DESK                 ; the whole lower band first
        ld (fill_pen),a
        ld hl,0
        ld de,ED_Y
        ld bc,384
        ld a,259 - ED_Y
        call fill
        call draw_palette
        call draw_script
        call draw_status
        jp mode0

mode0:
        xor a
        jp VOS_MODE
mode1:
        ld a,1
        jp VOS_MODE

; R_* in A: draw those parts again
refresh:
        ld (rf_parts),a
        and R_LINE                  ; the script scrolled: all of it
        jr z,.parts
        ld a,(top)
        ld hl,ds_old_top
        cp (hl)
        jr z,.parts
        ld a,(rf_parts)
        or R_SCRIPT
        ld (rf_parts),a
.parts:
        ld a,(rf_parts)
        and R_STAGE
        call nz,draw_stage
        ld a,(rf_parts)
        and R_SCRIPT + R_LINE + R_PAL + R_STATUS
        ret z
        call mode1
        ld a,(rf_parts)
        and R_PAL
        call nz,draw_palette
        ld a,(rf_parts)
        and R_SCRIPT + R_LINE
        call nz,draw_script
        ld a,(rf_parts)
        and R_STATUS
        call nz,draw_status
        jr mode0

; ---------------------------------------------------------------------
; a new program: one sprite that bounces
; ---------------------------------------------------------------------
prog_new:
        ld hl,new_prog
        ld de,vbs
        ld bc,new_prog_end - new_prog
        ldir
        ld hl,name_none
        ld de,prog_name
        ld bc,9
        ldir
        xor a
        ld (named),a
        ; fall through
editor_home:
        xor a
        ld (cursor),a
        ld (top),a
        ld (spr_sel),a
        ld (focus),a
        ld (msg),a
        ld (awaiting),a
        ld (typing),a
        dec a
        ld (slot),a
        ret

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        push hl
        call VOS_UI_EVENT           ; menus and shortcuts first
        pop hl
        or a
        jp nz,command
        push hl
        call VOS_MENU_OPEN
        pop hl
        ret nz
        ld a,(hl)
        cp VE_PTR_DOWN
        jp z,click
        cp VE_KEY_DOWN
        jr z,key
        cp VE_KEY_REPEAT
        ret nz
key:
        call remember
        inc hl
        ld a,(hl)
        ld (k_code),a
        inc hl
        ld a,(hl)
        ld (k_char),a
        ld a,(k_code)               ; letters and digits by key, so they
        call key_char               ; work with any keyboard language
        ld (k_letter),a
        xor a
        ld (msg),a
        ld a,R_STATUS
        ld (k_parts),a
        call .dispatch
        ld a,(k_parts)
        jp refresh
.dispatch:
        ld a,(awaiting)
        or a
        jp nz,key_chosen
        ld a,(k_code)
        cp 68                       ; TAB
        jr nz,.focus
        ld a,(focus)
        inc a
        cp 3
        jr c,.tab
        xor a
.tab:
        ld (focus),a
        ld a,R_SCRIPT + R_PAL + R_STAGE + R_STATUS
        jp parts
.focus:
        ld a,(focus)
        cp FOCUS_PAL
        jp z,pal_key
        cp FOCUS_STAGE
        jp z,stage_key
        ; fall through
script_key:
        ld a,(k_code)
        or a                        ; UP
        jr nz,.not_up
        ld a,(cursor)
        or a
        ret z
        dec a
        jr .line
.not_up:
        cp VK_DOWN
        jr nz,.not_down
        ld a,(cursor)
        inc a
        ld hl,(vbs + V_NLINES)
        cp l
        ret nc
.line:
        ld (cursor),a
        call no_slot
        call show_cursor
        ld a,R_LINE
        jp parts
.not_down:
        cp VK_RIGHT
        jr nz,.not_right
        call slot_next
        jr .slot
.not_right:
        cp VK_LEFT
        jr nz,.not_left
        call slot_prev
.slot:
        xor a
        ld (typing),a
        ld a,R_LINE
        jp parts
.not_left:
        cp VK_RETURN
        jr z,.return
        cp VK_ENTER
        jr nz,.not_return
.return:
        ld a,(slot)
        inc a
        jp z,insert_block           ; no slot: add the palette's block
        call slot_class
        cp C_KEYN
        jr z,.await
        call slot_ptr
        ld a,(hl)
        cp K_KEY
        ret nz
.await:
        ld a,1
        ld (awaiting),a
        ld a,R_LINE
        jp parts
.not_return:
        cp KEY_CLR
        jp z,delete_line
        cp VK_DEL
        jr nz,.not_del
        ld a,(slot)
        inc a
        jp z,delete_line
        jp slot_backspace
.not_del:
        ld a,(slot)
        inc a
        ret z
        jp slot_char

; the cursor's line and the first line shown, before the event
remember:
        ld a,(cursor)
        ld (ds_old),a
        ld a,(top)
        ld (ds_old_top),a
        ret

; A = parts to draw again (with the status line)
parts:
        ld hl,k_parts
        or (hl)
        ld (hl),a
        ret

; the key for a K_KEY or K_KEYN slot
key_chosen:
        xor a
        ld (awaiting),a
        call slot_ptr
        inc hl
        ld a,(k_code)
        ld (hl),a
        inc hl
        ld (hl),0
        ld a,R_LINE
        jr parts

; ---- the palette ----------------------------------------------------
pal_key:
        ld a,(k_code)
        or a                        ; UP
        jr nz,.not_up
        ld a,(pal)
        or a
        ret z
        dec a
        jr .entry
.not_up:
        cp VK_DOWN
        jr nz,.not_down
        call cat_size
        ld b,a
        ld a,(pal)
        inc a
        cp b
        ret nc
.entry:
        ld (pal),a
        ld a,R_PAL
        jr parts
.not_down:
        cp VK_LEFT
        jr nz,.not_left
        ld a,(cat)
        or a
        jr nz,.prev
        ld a,CATS
.prev:
        dec a
        jr .cat
.not_left:
        cp VK_RIGHT
        jr nz,.not_right
        ld a,(cat)
        inc a
        cp CATS
        jr c,.cat
        xor a
.cat:
        ld (cat),a
        xor a
        ld (pal),a
        ld a,R_PAL
        jr parts
.not_right:
        cp VK_RETURN
        jp z,insert_block
        cp VK_ENTER
        jp z,insert_block
        cp VK_SPACE
        jp z,insert_block
        ret

; A = blocks in the current category
cat_size:
        ld a,(cat)
        ld e,a
        ld d,0
        ld hl,cat_first + 1
        add hl,de
        ld a,(hl)
        dec hl
        sub (hl)
        ret

; A = the palette's block
pal_op:
        call cat_base
        ld hl,pal
        add a,(hl)
        ret

; A = the first block of the category (keeps BC)
cat_base:
        ld a,(cat)
        ld e,a
        ld d,0
        ld hl,cat_first
        add hl,de
        ld a,(hl)
        ret

; ---- the stage ------------------------------------------------------
stage_key:
        ld a,(vbs + V_NSPR)
        or a
        ret z
        ld a,(k_letter)
        cp "1"
        jr c,.not_digit
        cp "6" + 1
        jr nc,.not_digit
        sub "1"
        ld hl,vbs + V_NSPR
        cp (hl)
        ret nc
        ld (spr_sel),a
        jr .changed
.not_digit:
        call spr_ptr                ; HL -> the chosen sprite
        ld a,(k_letter)
        cp "C"
        jr nz,.not_colour
        ld de,6
        add hl,de
        ld a,(hl)
        inc a
        and 15
        jr nz,.colour
        inc a
.colour:
        ld (hl),a
        jr .changed
.not_colour:
        cp "W"
        jr z,.width
        cp "H"
        jr nz,.not_size
        inc hl
.width:
        ld de,4
        add hl,de
        ld a,(hl)
        add a,2
        cp 33
        jr c,.size
        ld a,2
.size:
        ld (hl),a
        jr .changed
.not_size:
        ld a,(k_code)               ; arrows: 4 pixels
        ld de,4
        cp VK_RIGHT
        jr z,.move_x
        ld de,-4
        cp VK_LEFT
        jr z,.move_x
        inc hl
        inc hl
        cp VK_DOWN
        ld de,4
        jr z,.move_y
        or a                        ; UP
        ret nz
        ld de,-4
.move_y:
        ld bc,#0C00 + 259 - 12      ; 12..258
        jr .move
.move_x:
        ld bc,#0000 + 192           ; 0..191
.move:
        call add_clamp
.changed:
        ld a,R_STAGE
        jp parts

; HL -> word, DE = delta, B = low, C = count: word = clamp(word + DE,
; B, B + C - 1)
add_clamp:
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        add hl,de
        bit 7,h
        jr nz,.low
        ld e,b
        ld d,0
        or a
        sbc hl,de
        jr c,.low
        ld e,c
        sbc hl,de                   ; carry is clear
        jr c,.in
        ld l,c
        ld h,0
        dec hl
        jr .base
.in:
        add hl,de
        jr .base
.low:
        ld hl,0
.base:
        ld e,b
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; HL -> the chosen sprite
spr_ptr:
        ld a,(spr_sel)
spr_ptr_a:
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,vbs + V_SPR
        add hl,de
        ret

; ---- clicks ---------------------------------------------------------
click:
        ld de,4
        add hl,de
        ld e,(hl)                   ; x, in pixels of the band
        inc hl
        ld d,(hl)
        inc hl
        ld (click_x),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (click_y),de
        call remember
        xor a
        ld (msg),a
        ld (awaiting),a
        ld a,R_STATUS
        ld (k_parts),a
        call .where
        ld a,(k_parts)
        jp refresh
.where:
        ld hl,(click_y)
        ld de,Y2
        or a
        sbc hl,de
        jp nc,click_lower
        ld hl,(click_y)                 ; the stage, a sprite's row
        ld de,STG_Y
        sbc hl,de
        ret c
        ld a,l
        ld (k_row),a
        ld hl,(click_x)
        ld de,STG_X + STG_W
        or a
        sbc hl,de
        jr nc,.list
        ld a,(vbs + V_NSPR)         ; place the sprite there
        or a
        ret z
        ld a,(k_row)
        cp STG_H
        ret nc
        ld hl,(click_x)                 ; x = (px - STG_X) * 2
        ld a,h
        or l
        ret z
        dec hl
        add hl,hl
        ld (click_x),hl
        ld a,(k_row)                ; y = row * 2 + 12
        ld l,a
        ld h,0
        add hl,hl
        ld de,Y1
        add hl,de
        ld (click_y),hl
        call spr_ptr
        ld de,(click_x)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(click_y)
        ld (hl),e
        inc hl
        ld (hl),d
        jr .stage
.list:
        ld a,(k_row)                ; rows from LIST_Y
        sub LIST_Y - STG_Y
        ret c
        ld c,0
.row:
        sub LIST_H
        jr c,.found
        inc c
        jr .row
.found:
        ld a,c
        ld hl,vbs + V_NSPR
        cp (hl)
        ret nc
        ld (spr_sel),a
.stage:
        ld a,FOCUS_STAGE
        ld b,R_STAGE
        jr click_focus

; A = focus, B = parts: and draw the parts whose focus look changes
click_focus:
        ld hl,focus
        cp (hl)
        ld (hl),a
        ld a,b
        jr z,.same
        or R_SCRIPT + R_PAL + R_STAGE
.same:
        jp parts

click_lower:
        ld a,l                      ; row in the editor band
        ld c,0
.row:
        sub ROW_H
        jr c,.found
        inc c
        jr .row
.found:
        ld a,c
        cp ED_ROWS
        ret nc                      ; the status line
        ld (k_row),a
        ld hl,(click_x)
        ld de,PAL_W
        or a
        sbc hl,de
        jr nc,click_script
        ld a,(k_row)                ; the palette
        or a
        jr nz,.block
        ld a,(click_x)                  ; the heading: category < or >
        cp PAL_W / 2
        ld a,VK_LEFT
        jr c,.cat
        ld a,VK_RIGHT
.cat:
        ld (k_code),a
        call pal_key
        jr .pal
.block:
        dec a
        ld b,a
        call cat_size
        cp b
        ret c
        ret z
        ld a,b
        ld (pal),a
        call insert_block
.pal:
        ld a,FOCUS_PAL
        ld b,R_PAL
        jr click_focus

click_script:
        ld a,(top)
        ld hl,k_row
        add a,(hl)
        ld hl,vbs + V_NLINES
        cp (hl)
        ret nc
        ld hl,cursor
        cp (hl)
        ld (hl),a
        push af
        call nz,no_slot
        ld a,(cursor)               ; where the slots are on this line
        call level_of
        ld a,(cursor)
        call render_line
        pop af
        ld hl,(click_x)                 ; column
        ld de,SC_TX
        or a
        sbc hl,de
        jr c,.none
        srl h
        rr l
        srl l
        srl l
        ld a,l
        ld (k_col),a
        ld c,0                      ; the slot there
.slot:
        ld hl,slot_col
        ld b,0
        add hl,bc
        ld a,(hl)
        cp #FF
        jr z,.next
        ld d,a
        ld a,(k_col)
        sub d
        jr c,.next
        inc hl                      ; slot_len follows slot_col
        inc hl
        inc hl
        cp (hl)
        jr c,.hit
.next:
        inc c
        ld a,c
        cp 3
        jr c,.slot
.none:
        call no_slot
        jr .script
.hit:
        ld a,(slot)                 ; the chosen slot again: next kind
        cp c
        ld a,c
        ld (slot),a
        call z,cycle_kind
        xor a
        ld (typing),a
.script:
        ld a,FOCUS_SCRIPT
        ld b,R_LINE
        jp click_focus

; ---------------------------------------------------------------------
; commands
; ---------------------------------------------------------------------
command:
        cp CMD_NEW
        jr z,do_new
        cp CMD_OPEN
        jp z,do_open
        cp CMD_SAVE
        jp z,do_save
        cp CMD_SAVE_AS
        jp z,do_save_as
        cp CMD_BACK
        jp z,VOS_EXIT
        cp CMD_DELETE
        jr z,do_delete
        cp CMD_ADD_SPRITE
        jr z,do_add_sprite
        cp CMD_DEL_SPRITE
        jr z,do_del_sprite
        cp CMD_BG
        jr z,do_bg
        jp VOS_COMMAND              ; VIEW and HELP menus

do_new:
        ld hl,dlg_new
        call VOS_DIALOG
        or a
        ret nz
        call prog_new
        jp redraw

do_delete:
        xor a
        ld (k_parts),a
        call delete_line
        ld a,(k_parts)
        or R_STATUS
        jp refresh

do_add_sprite:
        ld hl,vbs + V_NSPR
        ld a,(hl)
        cp SPR_MAX
        jr c,.room
        ld a,T_M_FULL
        ld (msg),a
        ld a,R_STATUS
        jp refresh
.room:
        inc (hl)
        ld (spr_sel),a
        push af
        call spr_ptr
        pop af
        ld b,a                      ; x = 16 + 28 * n
        ld de,16
.x:
        ld a,b
        or a
        jr z,.x_done
        ld a,e
        add a,28
        ld e,a
        dec b
        jr .x
.x_done:
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),60                  ; y
        inc hl
        ld (hl),0
        inc hl
        ld (hl),8                   ; w, h
        inc hl
        ld (hl),8
        inc hl
        ld a,(spr_sel)
        add a,4                     ; a colour of its own
        ld (hl),a
        inc hl
        ld (hl),0
        jr do_stage

do_del_sprite:
        ld hl,vbs + V_NSPR          ; the last one
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ld a,(spr_sel)
        cp (hl)
        jr c,do_stage
        ld a,(hl)
        or a
        jr z,do_stage
        dec a
        ld (spr_sel),a
        jr do_stage

do_bg:
        ld hl,vbs + V_BG
        ld a,(hl)
        inc a
        and 15
        ld (hl),a
do_stage:
        ld a,R_STAGE
        jp refresh

do_save:
        ld a,(named)
        or a
        jr z,do_save_as
        jr write_file

do_save_as:
        ld hl,prog_name
        ld de,name_buf
        ld bc,9
        ldir
        ld a,T_I_NAME
        ld hl,name_buf
        ld c,8
        call VOS_INPUT
        ret c
        ld hl,name_buf              ; letters and digits, in capitals
        ld b,0
.check:
        ld a,(hl)
        or a
        jr z,.end
        cp "a"
        jr c,.upper
        cp "z" + 1
        jr nc,.bad
        sub "a" - "A"
        ld (hl),a
.upper:
        cp "0"
        jr c,.bad
        cp "9" + 1
        jr c,.ok
        cp "A"
        jr c,.bad
        cp "Z" + 1
        jr nc,.bad
.ok:
        inc hl
        inc b
        jr .check
.end:
        ld a,b
        or a
        jr z,.bad
        ld hl,name_buf
        ld de,prog_name
        ld bc,9
        ldir
        ld a,1
        ld (named),a
        jr write_file
.bad:
        ld a,ERR_BAD_NAME
        jp VOS_ERROR

write_file:
        call make_fcb
        ld hl,(vbs + V_NLINES)      ; bytes: V_LINES + lines * 10
        call times10
        ld bc,V_LINES
        add hl,bc
        ld b,h
        ld c,l
        xor a
        ld hl,fcb
        ld de,vbs
        call VOS_SAVE
        jp c,VOS_ERROR
        ld a,T_M_SAVED
        ld (msg),a
        ld a,R_STAGE + R_STATUS     ; the name under the sprites
        jp refresh

; fcb = prog_name, padded with spaces, "VBS"
make_fcb:
        ld hl,fcb
        ld b,8
.space:
        ld (hl)," "
        inc hl
        djnz .space
        ld (hl),"V"
        inc hl
        ld (hl),"B"
        inc hl
        ld (hl),"S"
        ld hl,prog_name
        ld de,fcb
.copy:
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr .copy

do_open:
        xor a
        call VOS_CATALOG
        jp c,VOS_ERROR
        or a
        ld a,ERR_NOT_FOUND
        jp z,VOS_ERROR
        ld (cat_list),hl
        ld a,T_O_TITLE
        call VOS_FILE_PICK
        ret c
        ld l,a                      ; HL -> its entry (16 bytes)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cat_list)
        add hl,de
        ld (cat_list),hl
        ld de,8                     ; a .VBS of up to 3K
        add hl,de
        ld de,vbs_ext
        ld b,3
.ext:
        ld a,(hl)
        and #7F
        ex de,hl
        cp (hl)
        ex de,hl
        jr nz,.bad
        inc hl
        inc de
        djnz .ext
        inc hl
        ld a,(hl)                   ; size in K
        cp VBS_ROOM / 1024 + 1
        jr nc,.bad
        xor a
        ld hl,(cat_list)
        ld de,vbs
        call VOS_LOAD
        jr c,.error
        ld hl,vbs                   ; "VBS", 1
        ld de,new_prog
        ld b,4
.magic:
        ld a,(de)
        cp (hl)
        jr nz,.broken
        inc hl
        inc de
        djnz .magic
        ld a,(vbs + V_NSPR)
        cp SPR_MAX + 1
        jr nc,.broken
        ld hl,(vbs + V_NLINES)
        ld de,MAX_LINES + 1
        or a
        sbc hl,de
        jr nc,.broken
        ld hl,(cat_list)            ; its name, without the spaces
        ld de,prog_name
        ld b,8
.name:
        ld a,(hl)
        cp " "
        jr z,.named
        ld (de),a
        inc hl
        inc de
        djnz .name
.named:
        xor a
        ld (de),a
        inc a
        ld (named),a
        call editor_home
        jp redraw
.broken:
        call prog_new
        call redraw
.bad:
        ld a,ERR_NOT_PROGRAM
.error:
        jp VOS_ERROR

; ---------------------------------------------------------------------
; editing lines
; ---------------------------------------------------------------------
insert_block:
        call pal_op
        ld (ib_op),a
        call op_ptr
        ld a,(hl)
        and F_OPEN                  ; FOREVER, REPEAT, IF: and an END
        ld b,1
        jr z,.room
        inc b
.room:
        ld hl,(vbs + V_NLINES)
        ld a,l
        add a,b
        cp MAX_LINES + 1
        jr c,.fits
        ld a,T_M_FULL
        ld (msg),a
        ret
.fits:
        ld a,(vbs + V_NLINES)       ; below the cursor's line
        or a
        jr z,.at
        ld a,(cursor)
        inc a
.at:
        ld (ib_at),a
        ld (cursor),a
        ld a,(ib_op)
        call put_line
        ld a,(ib_op)
        call op_ptr
        ld a,(hl)
        and F_OPEN
        jr z,.owner
        ld a,(ib_at)
        inc a
        ld (ib_at),a
        ld a,OP_END
        call put_line
.owner:
        ld a,(ib_op)                ; a script for the chosen sprite
        call op_ptr
        ld a,(hl)
        and F_HAT
        jr z,.done
        ld a,(vbs + V_NSPR)
        or a
        jr z,.done
        ld a,(cursor)
        call line_ptr
        ld a,(spr_sel)
        inc a
        inc hl
        inc hl
        ld (hl),a
.done:
        call no_slot
        call show_cursor
        ld a,R_SCRIPT
        jp parts

; A = op: a new line at ib_at, with the op's default slots
put_line:
        push af
        ld a,(ib_at)                ; make room: lines at ib_at.. up one
        call line_ptr
        push hl
        ld hl,(vbs + V_NLINES)
        ld a,l
        call line_ptr               ; HL -> after the last line
        pop de
        push de
        or a
        sbc hl,de                   ; bytes to move
        ld b,h
        ld c,l
        pop hl
        ld a,b
        or c
        jr z,.moved
        add hl,bc                   ; last byte + 1
        dec hl
        ld d,h
        ld e,l
        push bc
        ld bc,LINE_SIZE
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        lddr
.moved:
        ld hl,vbs + V_NLINES
        inc (hl)
        ld a,(ib_at)
        call line_ptr
        pop af
        ld (hl),a
        inc hl
        push hl
        call op_ptr
        ld bc,4                     ; past flags and classes
        add hl,bc
        pop de
        ld bc,9
        ldir
        ret

delete_line:
        ld a,(vbs + V_NLINES)
        or a
        ret z
        ld a,(cursor)               ; an opening line: its END (and an
        call line_ptr               ; IF's ELSE) go too
        ld a,(hl)
        ld (dl_op),a
        call op_ptr
        ld a,(hl)
        and F_OPEN
        jr z,.one
        ld a,#FF
        ld (dl_else),a
        ld (dl_end),a
        ld a,(cursor)
        ld c,0                      ; depth
.scan:
        inc a
        ld hl,vbs + V_NLINES
        cp (hl)
        jr nc,.scanned
        ld (dl_at),a
        call line_ptr
        ld a,(hl)
        call op_ptr
        ld a,(hl)
        bit 0,a                     ; F_HAT: another script
        jr nz,.scanned
        bit 1,a                     ; F_OPEN
        jr z,.not_open
        inc c
        jr .again
.not_open:
        bit 3,a                     ; F_END
        jr z,.not_end
        ld a,c
        or a
        jr z,.end
        dec c
        jr .again
.not_end:
        bit 2,a                     ; F_ELSE
        jr z,.again
        ld a,c
        or a
        jr nz,.again
        ld a,(dl_op)
        cp OP_IF
        jr nz,.again
        ld a,(dl_at)
        ld (dl_else),a
.again:
        ld a,(dl_at)
        jr .scan
.end:
        ld a,(dl_at)
        ld (dl_end),a
.scanned:
        ld a,(dl_end)               ; the highest first
        cp #FF
        call nz,remove_line
        ld a,(dl_else)
        cp #FF
        call nz,remove_line
.one:
        ld a,(cursor)
        call remove_line
        ld a,(cursor)               ; still on a line
        ld hl,vbs + V_NLINES
        cp (hl)
        jr c,.ok
        ld a,(hl)
        or a
        jr z,.ok
        dec a
        ld (cursor),a
.ok:
        call no_slot
        call show_cursor
        ld a,R_SCRIPT
        jp parts

; A = line: remove it
remove_line:
        push af
        inc a
        call line_ptr               ; from the next line
        push hl
        ld hl,(vbs + V_NLINES)
        ld a,l
        call line_ptr
        pop de
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop af
        push bc
        call line_ptr
        ex de,hl                    ; DE -> the line, HL -> the next
        ld hl,LINE_SIZE
        add hl,de
        pop bc
        ld a,b
        or c
        jr z,.moved
        ldir
.moved:
        ld hl,vbs + V_NLINES
        dec (hl)
        ret

; the cursor's line on the screen
show_cursor:
        ld a,(cursor)
        ld hl,top
        cp (hl)
        jr nc,.below
        ld (hl),a
        ret
.below:
        sub ED_ROWS - 1
        ret c
        cp (hl)
        ret c
        ret z
        ld (hl),a
        ret

no_slot:
        ld a,#FF
        ld (slot),a
        xor a
        ld (typing),a
        ld (awaiting),a
        ret

; ---- slots ----------------------------------------------------------
; HL -> the chosen slot of the cursor's line (kind, value)
slot_ptr:
        ld a,(cursor)
        call line_ptr
        inc hl
        ld a,(slot)
        ld b,a
        add a,a
        add a,b
        ld e,a
        ld d,0
        add hl,de
        ret

; A = the class of the chosen slot
slot_class:
        ld a,(slot)
        ld c,a
; C = slot of the cursor's line -> A = its class
class_of:
        ld a,(cursor)
        call line_ptr
        ld a,(hl)
        call op_ptr
        inc hl
        ld b,0
        add hl,bc
        ld a,(hl)
        ret

; C = slot of the cursor's line -> carry if it is shown
slot_shown:
        push bc
        call class_of
        pop bc
        or a
        ret z                       ; no slot (carry clear)
        ld a,c
        cp 2
        scf
        ret nz
        ld a,(cursor)               ; slot 2 of a comparison with none
        call line_ptr
        ld a,(hl)
        inc hl
        inc hl
        inc hl
        inc hl
        ld b,(hl)                   ; kind of slot 1
        call op_ptr
        ld a,(hl)
        and F_COND
        scf
        ret z
        ld a,b
        cp K_NONE + 1
        ccf
        ret

slot_next:
        ld a,(slot)
        ld c,a
.next:
        inc c
        ld a,c
        cp 3
        ret nc
        push bc
        call slot_shown
        pop bc
        jr nc,.next
        ld a,c
        ld (slot),a
        ret

slot_prev:
        ld a,(slot)
        ld c,a
        inc a
        ret z
.prev:
        dec c
        ld a,c
        cp #FF
        jr z,.set
        push bc
        call slot_shown
        pop bc
        jr nc,.prev
.set:
        ld a,c
        ld (slot),a
        ret

; a key typed into the chosen slot
slot_char:
        call slot_class
        ld (sc_class),a
        call slot_ptr
        ld (sc_ptr),hl
        ld a,(sc_class)
        cp C_CMP
        jr nz,.not_cmp
        ld a,(k_code)
        cp VK_SPACE
        ld b,K_NONE
        jr z,.set_cmp
        ld a,(k_char)
        ld c,0
        cp "<"
        jr z,.cmp
        inc c
        cp #3D                      ; "="
        jr z,.cmp
        inc c
        cp ">"
        ret nz
.cmp:
        ld b,K_CMP
.set_cmp:
        ld a,b
        ld de,0
        ld e,c
        jp set_slot_typed
.not_cmp:
        cp C_SPR
        jr nz,.not_spr
        ld a,(k_letter)
        sub "0"
        ret c
        ld hl,vbs + V_NSPR
        cp (hl)
        jr z,.spr
        ret nc
.spr:
        ld e,a
        ld d,0
        ld a,K_SPR
        jp set_slot
.not_spr:
        cp C_VAR
        jr z,.var
        cp C_VALUE
        ret nz
        ld a,(k_letter)             ; a value
        cp "0"
        jr c,.not_digit
        cp "9" + 1
        jp c,slot_digit
.not_digit:
        ld a,(k_char)
        cp "-"
        jr nz,.not_minus
        ld hl,(sc_ptr)
        ld a,(hl)
        cp K_NUM
        ret nz
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        call negate_de
        ld a,K_NUM
        jp set_slot_typed
.not_minus:
        ld a,(k_letter)
        cp "X"
        ld b,K_X
        jr z,.kind
        cp "Y"
        ld b,K_Y
        jr z,.kind
        cp "Z"
        ld b,K_EDGE
        jr z,.kind
        ld de,10
        cp "R"
        ld b,K_RND
        jr z,.kind_de
        ld de,1
        cp "T"
        ld b,K_TOUCH
        jr z,.kind_de
        ld de,VK_SPACE
        cp "K"
        ld b,K_KEY
        jr nz,.var
        ld a,1
        ld (awaiting),a
        jr .kind_de
.kind:
        ld de,0
.kind_de:
        ld a,b
        jp set_slot
.var:
        ld a,(k_letter)             ; A..H
        sub "A"
        ret c
        cp 8
        ret nc
        ld e,a
        ld d,0
        ld a,K_VAR
        jp set_slot

; a digit (in k_letter) into the chosen value slot
slot_digit:
        sub "0"
        ld (sd_digit),a
        ld hl,(sc_ptr)
        ld a,(hl)
        cp K_TOUCH
        jr nz,.not_touch
        ld a,(sd_digit)
        or a
        ret z
        cp SPR_MAX + 1
        ret nc
        ld e,a
        ld d,0
        ld a,K_TOUCH
        jr set_slot
.not_touch:
        cp K_RND
        jr z,.number
        ld a,K_NUM
.number:
        ld (sd_kind),a
        ld a,(typing)               ; the first digit: a new number
        or a
        jr z,.first
        ld hl,(sc_ptr)
        ld a,(hl)
        ld b,a
        ld a,(sd_kind)
        cp b
        jr nz,.first
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d                      ; negative: the digit makes it more so
        ld (sd_sign),a
        bit 7,d
        call nz,negate_de
        ex de,hl
        ld de,1000                  ; at most 4 digits
        or a
        sbc hl,de
        ret nc
        add hl,de
        call times10
        ld a,(sd_digit)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld a,(sd_sign)
        bit 7,a
        call nz,negate_de
        jr .set
.first:
        ld a,(sd_digit)
        ld e,a
        ld d,0
.set:
        ld a,(sd_kind)
set_slot_typed:
        ld hl,typing
        ld (hl),1
        jr set_value
; A = kind, DE = value: the chosen slot
set_slot:
        ld hl,typing
        ld (hl),0
set_value:
        ld hl,(sc_ptr)
        ld (hl),a
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,R_LINE
        jp parts

; DEL: the last digit of a number
slot_backspace:
        call slot_ptr
        ld (sc_ptr),hl
        ld a,(hl)
        cp K_NUM
        jr z,.number
        cp K_RND
        ret nz
.number:
        ld (sd_kind),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        ld (sd_sign),a
        bit 7,d
        call nz,negate_de
        ex de,hl
        ld de,0                     ; DE = HL / 10
        ld bc,10
.div:
        or a
        sbc hl,bc
        jr c,.divided
        inc de
        jr .div
.divided:
        ld a,(sd_sign)
        bit 7,a
        call nz,negate_de
        ld a,(sd_kind)
        jr set_slot_typed

; the next kind for a click on the chosen slot
cycle_kind:
        call slot_class
        ld (sc_class),a
        call slot_ptr
        ld (sc_ptr),hl
        ld a,(sc_class)
        cp C_KEYN
        jr nz,.not_key
        ld a,1
        ld (awaiting),a
        ret
.not_key:
        cp C_VAR
        jr nz,.not_var
        inc hl
        ld a,(hl)
        inc a
        and 7
        ld (hl),a
        ret
.not_var:
        cp C_SPR
        jr nz,.not_spr
        inc hl
        ld a,(hl)
        inc a
        ld b,a
        ld a,(vbs + V_NSPR)
        cp b
        ld a,b
        jr nc,.spr
        xor a
.spr:
        ld (hl),a
        ret
.not_spr:
        cp C_CMP
        jr nz,.value
        ld a,(hl)                   ; none, <, =, >, none
        cp K_NONE
        jr nz,.cmp
        ld (hl),K_CMP
        inc hl
        ld (hl),0
        ret
.cmp:
        inc hl
        ld a,(hl)
        inc a
        ld (hl),a
        cp 3
        ret c
        dec hl
        ld (hl),K_NONE
        ret
.value:
        ld a,(hl)                   ; NUM .. EDGE, then NUM again
        inc a
        cp K_EDGE + 1
        jr c,.kind
        ld a,K_NUM
.kind:
        ld (hl),a
        sub K_NUM                   ; its first value
        ld e,a
        ld d,0
        push hl
        ld hl,first_values
        add hl,de
        ld a,(hl)
        pop hl
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        ret

; ---------------------------------------------------------------------
; drawing: the stage and the sprite list (mode 0)
; ---------------------------------------------------------------------
draw_stage:
        ld a,Q_WHITE                ; frame and background
        ld (fill_pen),a
        ld hl,0
        ld de,Y1
        ld bc,STG_W + 2
        ld a,Y2 - Y1
        call fill
        ld a,(vbs + V_BG)
        ld (fill_pen),a
        ld hl,STG_X
        ld de,STG_Y
        ld bc,STG_W
        ld a,STG_H
        call fill
        xor a
.sprite:
        ld hl,vbs + V_NSPR
        cp (hl)
        jp nc,draw_list
        push af
        call draw_preview
        pop af
        inc a
        jr .sprite

; A = sprite: at half size, clipped to the preview
draw_preview:
        call spr_ptr_a
        ld e,(hl)                   ; px = x / 2
        inc hl
        ld d,(hl)
        inc hl
        srl d
        rr e
        ld a,d
        or a
        ret nz
        ld a,e
        cp STG_W
        ret nc
        ld (dp_x),a
        ld e,(hl)                   ; py = (y - 12) / 2
        inc hl
        ld d,(hl)
        inc hl
        ex de,hl
        ld bc,Y1
        or a
        sbc hl,bc
        ret c
        srl h
        rr l
        ld a,h
        or a
        ret nz
        ld a,l
        cp STG_H
        ret nc
        ld (dp_y),a
        ex de,hl
        ld a,(hl)                   ; w / 2, at least 1, clipped
        inc hl
        srl a
        jr nz,.w
        inc a
.w:
        ld b,a
        ld a,(dp_x)
        add a,b
        cp STG_W + 1
        jr c,.w_ok
        ld a,STG_W
        ld b,a
        ld a,(dp_x)
        ld c,a
        ld a,b
        sub c
        ld b,a
.w_ok:
        ld a,(hl)                   ; h / 2
        inc hl
        srl a
        jr nz,.h
        inc a
.h:
        ld c,a
        ld a,(dp_y)
        add a,c
        cp STG_H + 1
        jr c,.h_ok
        ld a,(dp_y)
        ld c,a
        ld a,STG_H
        sub c
        ld c,a
.h_ok:
        ld a,(hl)                   ; colour
        ld (fill_pen),a
        ld a,c
        ld (dp_h),a
        ld c,b
        ld b,0
        ld a,(dp_x)
        add a,STG_X
        ld l,a
        ld h,0
        ld a,(dp_y)
        add a,STG_Y
        ld e,a
        ld d,0
        ld a,(dp_h)
        jp fill

draw_list:
        ld a,Q_BLUE
        ld (fill_pen),a
        ld hl,STG_W + 2
        ld de,Y1
        ld bc,192 - STG_W - 2
        ld a,Y2 - Y1
        call fill
        ld a,(focus)                ; heading, lit with the focus
        cp FOCUS_STAGE
        ld c,Q_BLUE
        jr nz,.heading
        ld c,Q_LIGHT
        ld a,c
        ld (fill_pen),a
        ld hl,LIST_X - 4
        ld de,STG_Y
        ld bc,192 - LIST_X + 4
        ld a,LIST_H
        call fill
        ld c,Q_LIGHT
.heading:
        ld a,Q_WHITE
        call VOS_COLOURS
        ld a,T_W_SPRITES
        ld hl,LIST_X
        ld de,STG_Y + 2
        call print_msg
        xor a
.row:
        ld hl,vbs + V_NSPR
        cp (hl)
        jr nc,.rows_done
        push af
        call draw_list_row
        pop af
        inc a
        jr .row
.rows_done:
        ld a,(vbs + V_NSPR)         ; size of the chosen one
        or a
        jr z,.stage
        call spr_ptr
        ld de,4
        add hl,de
        ld de,lbuf
        ld a,"W"
        ld (de),a
        inc de
        ld a,(hl)
        push hl
        call num_a
        ld a," "
        ld (de),a
        inc de
        ld a,"H"
        ld (de),a
        inc de
        pop hl
        inc hl
        ld a,(hl)
        call num_a
        xor a
        ld (de),a
        call list_colours
        ld hl,LIST_X
        ld de,LIST_Y + SPR_MAX * LIST_H + 2
        ld bc,lbuf
        call VOS_PRINT
.stage:
        ld a,T_W_STAGE              ; "STAGE n": its colour
        call VOS_MSG
        ld de,lbuf
        call append
        ld a," "
        ld (de),a
        inc de
        ld a,(vbs + V_BG)
        call num_a
        xor a
        ld (de),a
        call list_colours
        ld hl,LIST_X
        ld de,LIST_Y + SPR_MAX * LIST_H + 14
        ld bc,lbuf
        call VOS_PRINT
        ld hl,prog_name             ; the file
        ld de,lbuf
        call append
        ld hl,vbs_dot_ext
        call append
        xor a
        ld (de),a
        call list_colours
        ld hl,LIST_X
        ld de,LIST_Y + SPR_MAX * LIST_H + 26
        ld bc,lbuf
        jp VOS_PRINT

list_colours:
        ld a,Q_WHITE
        ld c,Q_BLUE
        jp VOS_COLOURS

; A = sprite: its row, a colour swatch and x y
draw_list_row:
        ld (dl_row),a
        ld b,a                      ; y = LIST_Y + row * LIST_H
        ld a,LIST_Y
        inc b
        jr .y_first
.y:
        add a,LIST_H
.y_first:
        djnz .y
        ld (dl_y),a
        ld a,(spr_sel)
        ld b,a
        ld a,(dl_row)
        cp b
        ld a,Q_BLUE
        jr nz,.bg
        ld a,Q_LIGHT
.bg:
        ld (dl_bg),a
        ld (fill_pen),a
        ld hl,LIST_X - 4
        ld a,(dl_y)
        ld e,a
        ld d,0
        ld bc,192 - LIST_X + 4
        ld a,LIST_H
        call fill
        ld a,(dl_row)
        call spr_ptr_a
        push hl
        ld de,6
        add hl,de
        ld a,(hl)
        ld (fill_pen),a
        ld hl,LIST_X
        ld a,(dl_y)
        add a,2
        ld e,a
        ld d,0
        ld bc,8
        ld a,8
        call fill
        pop hl
        ld e,(hl)                   ; "x y"
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld de,lbuf
        call num_str
        ld a," "
        ld (de),a
        inc de
        pop hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call num_str
        xor a
        ld (de),a
        ld a,(dl_bg)
        ld c,a
        ld a,Q_WHITE
        call VOS_COLOURS
        ld hl,LIST_X + 12
        ld a,(dl_y)
        add a,2
        ld e,a
        ld d,0
        ld bc,lbuf
        jp VOS_PRINT

; ---------------------------------------------------------------------
; drawing: palette, script, status line (mode 1)
; ---------------------------------------------------------------------
draw_palette:
        ld a,(focus)                ; heading: < category >
        cp FOCUS_PAL
        ld a,P_DESK
        ld b,P_PAPER
        jr nz,.heading
        ld a,P_SEL
        ld b,P_INK
.heading:
        ld (fill_pen),a
        ld c,a
        ld a,b
        call VOS_COLOURS
        ld hl,0
        ld de,ED_Y
        ld bc,PAL_W
        ld a,ROW_H
        call fill
        ld hl,0
        ld de,ED_Y + 1
        ld a,"<"
        call VOS_CHAR
        ld hl,PAL_W - 8
        ld de,ED_Y + 1
        ld a,">"
        call VOS_CHAR
        ld a,(cat)
        add a,T_C_EVENTS
        ld hl,12
        ld de,ED_Y + 1
        call print_msg
        ld a,1                      ; the blocks
.row:
        ld (dp_row),a
        call draw_pal_row
        ld a,(dp_row)
        inc a
        cp ED_ROWS
        jr c,.row
        ret

; dp_row (1..): a block of the category, or nothing
draw_pal_row:
        call row_y
        ld (dp_y16),de
        call cat_size
        ld b,a
        ld a,(dp_row)
        dec a
        cp b
        jr nc,.empty
        ld b,a                      ; B = the block in the category
        ld a,(pal)
        cp b
        ld c,P_DESK
        ld a,P_PAPER
        jr nz,.colours
        ld c,P_SEL
        ld a,P_INK
.colours:
        ld (dp_ink),a
        ld a,c
        ld (fill_pen),a
        push bc
        ld hl,0
        ld de,(dp_y16)
        ld bc,PAL_W
        ld a,ROW_H
        call fill
        ld a,(fill_pen)
        ld c,a
        ld a,(dp_ink)
        call VOS_COLOURS
        pop bc
        call cat_base               ; its name without the slots
        add a,b
        call op_name
        ld a,13
        call clip_lbuf
        ld hl,4
        ld de,(dp_y16)
        inc de
        ld bc,lbuf
        jp VOS_PRINT
.empty:
        ld a,P_DESK
        ld (fill_pen),a
        ld hl,0
        ld de,(dp_y16)
        ld bc,PAL_W
        ld a,ROW_H
        jp fill

; dp_row -> DE = its y
row_y:
        ld a,(dp_row)
        ld b,a
        ld hl,ED_Y
        ld de,ROW_H
        inc b
        jr .first
.next:
        add hl,de
.first:
        djnz .next
        ex de,hl
        ret

draw_script:
        call lv_reset               ; the levels down to the first row
        ld a,(top)
        or a
        jr z,.rows
        ld b,a
        xor a
.skip:
        push af
        push bc
        call line_ptr
        ld a,(hl)
        call lv_step
        pop bc
        pop af
        inc a
        djnz .skip
.rows:
        xor a
.row:
        ld (dp_row),a
        ld hl,top
        add a,(hl)
        ld (ds_line),a
        ld hl,vbs + V_NLINES
        cp (hl)
        jr nc,.blank
        call line_ptr
        ld a,(hl)
        call lv_step
        ld a,(rf_parts)             ; only the cursor's lines?
        and R_SCRIPT
        jr nz,.draw
        ld a,(ds_line)
        ld hl,cursor
        cp (hl)
        jr z,.draw
        ld hl,ds_old
        cp (hl)
        jr nz,.next
.draw:
        call draw_line
        jr .next
.blank:
        ld a,(rf_parts)
        and R_SCRIPT
        jr z,.next
        call row_y
        ld a,P_PAPER
        ld (fill_pen),a
        ld hl,SC_X
        ld bc,SC_W
        ld a,ROW_H
        call fill
.next:
        ld a,(dp_row)
        inc a
        cp ED_ROWS
        jr c,.row
        ret

; ds_line on row dp_row, at level lv_line
draw_line:
        call row_y
        ld (dp_y16),de
        ld a,(cursor)               ; background: the cursor's line lit
        ld b,a
        ld a,(ds_line)
        cp b
        ld a,P_PAPER
        jr nz,.bg
        ld a,P_SEL
.bg:
        ld (fill_pen),a
        ld hl,SC_X
        ld bc,SC_W
        ld a,ROW_H
        call fill
        ld a,(ds_line)              ; hats in blue
        call line_ptr
        ld a,(hl)
        call op_ptr
        ld a,(hl)
        and F_HAT
        ld a,P_INK
        jr z,.ink
        ld a,P_DESK
.ink:
        ld b,a
        ld a,(fill_pen)
        ld c,a
        ld a,b
        call VOS_COLOURS
        ld a,(ds_line)
        call render_line
        ld a,SC_COLS
        call clip_lbuf
        ld hl,SC_TX
        ld de,(dp_y16)
        inc de
        ld bc,lbuf
        call VOS_PRINT
        ld a,(cursor)               ; the chosen slot in black
        ld b,a
        ld a,(ds_line)
        cp b
        ret nz
        ld a,(focus)
        cp FOCUS_SCRIPT
        ret nz
        ld a,(slot)
        cp 3
        ret nc
        ld e,a
        ld d,0
        ld hl,slot_col
        add hl,de
        ld a,(hl)
        cp SC_COLS
        ret nc
        ld (dl_col),a
        ld de,slot_len - slot_col
        add hl,de
        ld b,(hl)
        ld a,b
        or a
        ret z
        ld a,(dl_col)               ; its text, clipped
        ld e,a
        ld d,0
        ld hl,lbuf
        add hl,de
        ld de,tbuf
.copy:
        ld a,(hl)
        or a
        jr z,.copied
        ld (de),a
        inc hl
        inc de
        djnz .copy
.copied:
        xor a
        ld (de),a
        ld a,P_PAPER
        ld c,P_INK
        call VOS_COLOURS
        ld a,(dl_col)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SC_TX
        add hl,de
        ld de,(dp_y16)
        inc de
        ld bc,tbuf
        jp VOS_PRINT

draw_status:
        ld a,P_INK
        ld (fill_pen),a
        ld hl,0
        ld de,STATUS_Y
        ld bc,384
        ld a,ROW_H
        call fill
        ld a,P_PAPER
        ld c,P_INK
        call VOS_COLOURS
        call status_text
        ld hl,4
        ld de,STATUS_Y + 1
        jp print_msg

; -> A = the status line's text
status_text:
        ld a,(msg)
        or a
        ret nz
        ld a,(focus)
        cp FOCUS_PAL
        ld a,T_H_PAL
        ret z
        ld a,(focus)
        cp FOCUS_STAGE
        ld a,T_H_STAGE
        ret z
        ld a,(awaiting)
        or a
        ld a,T_H_AWAIT
        ret nz
        ld a,(slot)
        cp 3
        ld a,T_H_LINE
        ret nc
        call slot_class
        ld e,a
        ld d,0
        ld hl,class_help
        add hl,de
        ld a,(hl)
        ret

; ---------------------------------------------------------------------
; texts of lines
; ---------------------------------------------------------------------
; levels (indentation), line by line
lv_reset:
        xor a
        ld (lv_cur),a
        ld (lv_base),a
        ret

; A = op of the next line -> lv_line = its level
lv_step:
        call op_ptr
        ld a,(hl)
        ld hl,lv_cur
        bit 0,a                     ; F_HAT
        jr z,.not_hat
        ld (hl),1
        ld a,1
        ld (lv_base),a
        xor a
        jr .line
.not_hat:
        bit 1,a                     ; F_OPEN
        jr z,.not_open
        ld a,(hl)
        inc (hl)
        jr .line
.not_open:
        bit 2,a                     ; F_ELSE: one level out
        jr z,.not_else
        ld a,(lv_base)
        cp (hl)
        ld a,(hl)
        jr nc,.line
        dec a
        jr .line
.not_else:
        bit 3,a                     ; F_END
        jr z,.other
        ld a,(lv_base)
        cp (hl)
        jr nc,.other
        dec (hl)
.other:
        ld a,(hl)
.line:
        cp 9                        ; at most 8 columns in
        jr c,.ok
        ld a,8
.ok:
        ld (lv_line),a
        ret

; A = line -> lv_line = its level
level_of:
        ld b,a
        inc b
        call lv_reset
        xor a
.line:
        push af
        push bc
        call line_ptr
        ld a,(hl)
        call lv_step
        pop bc
        pop af
        inc a
        djnz .line
        ret

; A = line -> lbuf: indentation (lv_line), the block's text with its
; slots; slot_col / slot_len: where each slot is (#FF: not shown)
render_line:
        ld (rl_line),a
        call line_ptr
        ld (rl_ptr),hl
        ld hl,slot_col
        ld b,3
.clear:
        ld (hl),#FF
        inc hl
        djnz .clear
        ld hl,slot_len
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld de,lbuf
        ld a,(lv_line)
        or a
        jr z,.text
        ld b,a
.indent:
        ld a," "
        ld (de),a
        inc de
        djnz .indent
.text:
        ld (rl_out),de
        ld hl,(rl_ptr)
        ld a,(hl)
        add a,T_OP_START
        call VOS_MSG
.char:
        ld a,(hl)
        inc hl
        or a
        jr z,.end
        cp #7E                      ; "~"
        jr z,.slot
        ld de,(rl_out)
        ld (de),a
        inc de
        ld (rl_out),de
        jr .char
.end:
        ld de,(rl_out)
        xor a
        ld (de),a
        ret
.slot:
        ld a,(hl)
        inc hl
        sub "0"
        push hl
        call render_slot
        pop hl
        jr .char

; A = slot of rl_line: its text at rl_out, if it is shown
render_slot:
        ld (rs_slot),a
        ld c,a
        ld a,(cursor)               ; slot_shown works on the cursor's
        push af                     ; line
        ld a,(rl_line)
        ld (cursor),a
        call slot_shown
        pop bc
        ld a,b
        ld (cursor),a
        ret nc
        ld hl,(rl_out)              ; its column
        ld de,lbuf
        or a
        sbc hl,de
        ld a,(rs_slot)
        ld e,a
        ld d,0
        ld a,l
        ld hl,slot_col
        add hl,de
        ld (hl),a
        ld hl,(rl_ptr)              ; HL -> kind, value
        inc hl
        add hl,de
        add hl,de
        add hl,de
        ld a,(hl)
        ld (rs_kind),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (rs_value),de
        ld de,(rl_out)
        call .text
        ld (rl_out),de
        ld hl,(rl_out)              ; its length
        ld a,(rs_slot)
        ld c,a
        ld b,0
        push hl
        ld hl,slot_col
        add hl,bc
        ld a,(hl)
        pop hl
        ld de,lbuf
        or a
        sbc hl,de
        sub l
        neg
        jr nz,.length
        ld a,(rl_line)              ; an empty slot that is chosen: "_"
        ld b,a
        ld a,(cursor)
        cp b
        jr nz,.length0
        ld a,(rs_slot)
        ld b,a
        ld a,(slot)
        cp b
        jr nz,.length0
        ld de,(rl_out)
        ld a,"_"
        ld (de),a
        inc de
        ld (rl_out),de
        ld a,1
        jr .length
.length0:
        xor a
.length:
        ld b,a
        ld a,(rs_slot)
        ld e,a
        ld d,0
        ld hl,slot_len
        add hl,de
        ld (hl),b
        ret
.text:
        ld a,(rl_line)              ; waiting for a key: "?"
        ld b,a
        ld a,(cursor)
        cp b
        jr nz,.kind
        ld a,(rs_slot)
        ld b,a
        ld a,(slot)
        cp b
        jr nz,.kind
        ld a,(awaiting)
        or a
        jr z,.kind
        ld a,"?"
        ld (de),a
        inc de
        ret
.kind:
        ld hl,(rs_value)
        ld a,(rs_kind)
        cp K_NUM
        jp z,num_str
        cp K_VAR
        jr nz,.not_var
        ld a,l
        add a,"A"
        ld (de),a
        inc de
        ret
.not_var:
        cp K_X
        ld c,"X"
        jr z,.letter
        cp K_Y
        ld c,"Y"
        jr nz,.not_xy
.letter:
        ld a,c
        ld (de),a
        inc de
        ret
.not_xy:
        cp K_RND
        ld c,T_W_RND
        jr z,.word_number
        cp K_TOUCH
        ld c,T_W_TOUCH
        jr z,.word_number
        cp K_EDGE
        ld c,T_W_EDGE
        jr z,.word
        cp K_CMP
        jr nz,.not_cmp
        ld de,cmp_chars
        add hl,de
        ld a,(hl)
        ld de,(rl_out)
        ld (de),a
        inc de
        ret
.not_cmp:
        cp K_SPR
        jr nz,.not_spr
        ld a,l
        or a
        ld c,T_W_STAGE
        jr z,.word
        ld c,T_W_SPRITE
        jr .word_number
.not_spr:
        cp K_KEY
        jr nz,.not_key
        push de
        ld a,T_W_KEY
        call VOS_MSG
        pop de
        call append
        ld a," "
        ld (de),a
        inc de
        jr .key
.not_key:
        cp K_KEYN
        ret nz                      ; K_NONE
.key:
        ld a,(rs_value)
        jp key_name
.word:
        push de
        ld a,c
        call VOS_MSG
        pop de
        jp append
.word_number:
        push de
        ld a,c
        call VOS_MSG
        pop de
        call append
        ld a," "
        ld (de),a
        inc de
        ld hl,(rs_value)
        jp num_str

; A = op -> lbuf: its text without the slots (palette)
op_name:
        add a,T_OP_START
        call VOS_MSG
        ld de,lbuf
        ld c,0                      ; the last character put
.char:
        ld a,(hl)
        inc hl
        or a
        jr z,.end
        cp #7E                      ; "~"
        jr nz,.keep
        inc hl
        jr .char
.keep:
        cp " "                      ; one space between words
        jr nz,.put
        cp c
        jr z,.char
.put:
        ld (de),a
        inc de
        ld c,a
        jr .char
.end:
        ld a,c                      ; no space at the end
        cp " "
        jr nz,.zero
        dec de
.zero:
        xor a
        ld (de),a
        ret

; A = key number, DE -> out: its name
key_name:
        ld hl,key_names
.named:
        ld c,(hl)
        inc hl
        inc c
        jr z,.char
        dec c
        cp c
        jr z,append
.skip:
        ld c,(hl)
        inc hl
        inc c
        dec c
        jr nz,.skip
        jr .named
.char:
        call key_char
        or a
        jr z,.number
        ld (de),a
        inc de
        ret
.number:
        ld a,"#"
        ld (de),a
        inc de
        ld a,(rs_value)
        jr num_a

; A = key number -> A = its letter, digit or sign (capitals), 0: none
; (keeps DE)
key_char:
        cp 80
        jr nc,.none
        push de
        ld hl,key_chars
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        pop de
        ret
.none:
        xor a
        ret

; ---------------------------------------------------------------------
; small helpers
; ---------------------------------------------------------------------
; HL = x, DE = y, BC = w, A = h: a rectangle in fill_pen
fill:
        ld (rc),hl
        ld (rc + 2),de
        ld (rc + 4),bc
        ld (rc + 6),a
        xor a
        ld (rc + 7),a
        ld a,(fill_pen)
        ld (rc + 8),a
        push ix
        ld ix,rc
        call VOS_RECT
        pop ix
        ret

; A = text, HL = x, DE = y
print_msg:
        push hl
        push de
        call VOS_MSG
        ld b,h
        ld c,l
        pop de
        pop hl
        jp VOS_PRINT

; HL -> text, DE -> out: copy without the zero, DE after it
append:
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr append

; A = characters: cut lbuf there
clip_lbuf:
        ld hl,lbuf
        ld b,a
.len:
        ld a,(hl)
        or a
        ret z
        inc hl
        djnz .len
        ld (hl),0
        ret

; A = 0..255, DE -> out
num_a:
        ld l,a
        ld h,0
; HL = signed number, DE -> out: its digits, DE after them
num_str:
        bit 7,h
        jr z,.positive
        ld a,"-"
        ld (de),a
        inc de
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.positive:
        ld (ns_out),de
        xor a
        ld (ns_started),a
        ld de,tens
.digit:
        ld a,(de)
        ld c,a
        inc de
        ld a,(de)
        ld b,a
        inc de
        or c
        jr z,.done
        ld a,"0" - 1
.count:
        inc a
        or a
        sbc hl,bc
        jr nc,.count
        add hl,bc
        ld (ns_digit),a
        ld a,c                      ; the ones: always
        dec a
        or b
        jr z,.put
        ld a,(ns_started)
        or a
        jr nz,.put
        ld a,(ns_digit)
        cp "0"
        jr z,.digit
.put:
        push de
        ld de,(ns_out)
        ld a,(ns_digit)
        ld (de),a
        inc de
        ld (ns_out),de
        pop de
        ld a,1
        ld (ns_started),a
        jr .digit
.done:
        ld de,(ns_out)
        ret

; DE = -DE
negate_de:
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
        ret

; HL = HL * 10
times10:
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ret

; A = line -> HL -> it
line_ptr:
        ld l,a
        ld h,0
        call times10
        ld de,vbs + V_LINES
        add hl,de
        ret

; A = op -> HL -> its OP_INFO bytes (keeps BC, DE)
op_ptr:
        push bc
        push de
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        add hl,de                   ; * 13
        ld de,ops
        add hl,de
        pop de
        pop bc
        ret

; ---------------------------------------------------------------------
; data
; ---------------------------------------------------------------------
palette:        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 0
split:          dw Y1, Y2
                db 1, 26, 0, 11     ; mode 1 bands, as on the Desktop
                db 0, 26, 1, 2      ; mode 0 band, pens 0..3

bar:            db 4
                dw menu_studio, menu_edit, 0, 0
menu_studio:    db T_STUDIO, 6
                db T_NEW, CMD_NEW, "N", 0
                db T_OPEN, CMD_OPEN, "O", 0
                db T_SAVE, CMD_SAVE, "S", 0
                db T_SAVE_AS, CMD_SAVE_AS, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
menu_edit:      db T_EDIT, 4
                db T_DELETE, CMD_DELETE, 0, 0
                db T_ADD_SPRITE, CMD_ADD_SPRITE, 0, 0
                db T_DEL_SPRITE, CMD_DEL_SPRITE, 0, 0
                db T_BG, CMD_BG, 0, 0

dlg_new:        db T_STUDIO, T_D_NEW, 2, T_B_YES, T_B_NO

; blocks: flags, the classes of slots 0..2, default slots (kind, value)
ops:
        db F_HAT,  C_SPR, 0, 0,             K_SPR, 0, 0, 0, 0, 0, 0, 0, 0             ; WHEN START
        db F_HAT,  C_SPR, C_KEYN, 0,        K_SPR, 0, 0, K_KEYN, VK_SPACE, 0, 0, 0, 0 ; WHEN KEY
        db F_HAT,  C_SPR, 0, 0,             K_SPR, 0, 0, 0, 0, 0, 0, 0, 0             ; WHEN CLICKED
        db F_OPEN, 0, 0, 0,                 0, 0, 0, 0, 0, 0, 0, 0, 0                 ; FOREVER
        db F_OPEN, C_VALUE, 0, 0,           K_NUM, 10, 0, 0, 0, 0, 0, 0, 0            ; REPEAT
        db F_OPEN + F_COND, C_VALUE, C_CMP, C_VALUE
        db                                  K_KEY, VK_SPACE, 0, K_NONE, 0, 0, K_NUM, 0, 0 ; IF
        db F_ELSE, 0, 0, 0,                 0, 0, 0, 0, 0, 0, 0, 0, 0                 ; ELSE
        db F_END,  0, 0, 0,                 0, 0, 0, 0, 0, 0, 0, 0, 0                 ; END
        db 0,      C_VALUE, 0, 0,           K_NUM, 25, 0, 0, 0, 0, 0, 0, 0            ; WAIT
        db F_COND, C_VALUE, C_CMP, C_VALUE
        db                                  K_KEY, VK_SPACE, 0, K_NONE, 0, 0, K_NUM, 0, 0 ; WAIT UNTIL
        db 0,      0, 0, 0,                 0, 0, 0, 0, 0, 0, 0, 0, 0                 ; STOP
        db 0,      C_VALUE, C_VALUE, 0,     K_NUM, 96, 0, K_NUM, 120, 0, 0, 0, 0      ; GO TO
        db 0,      C_VALUE, 0, 0,           K_NUM, 4, 0, 0, 0, 0, 0, 0, 0             ; CHANGE X
        db 0,      C_VALUE, 0, 0,           K_NUM, 4, 0, 0, 0, 0, 0, 0, 0             ; CHANGE Y
        db 0,      C_VALUE, C_VALUE, 0,     K_NUM, 2, 0, K_NUM, 2, 0, 0, 0, 0         ; SPEED
        db 0,      0, 0, 0,                 0, 0, 0, 0, 0, 0, 0, 0, 0                 ; MOVE
        db 0,      0, 0, 0,                 0, 0, 0, 0, 0, 0, 0, 0, 0                 ; BOUNCE
        db 0,      C_VALUE, 0, 0,           K_NUM, 8, 0, 0, 0, 0, 0, 0, 0             ; COLOUR
        db 0,      0, 0, 0,                 0, 0, 0, 0, 0, 0, 0, 0, 0                 ; SHOW
        db 0,      0, 0, 0,                 0, 0, 0, 0, 0, 0, 0, 0, 0                 ; HIDE
        db 0,      C_VALUE, C_VALUE, C_VALUE
        db                                  K_VAR, 0, 0, K_NUM, 8, 0, K_NUM, 20, 0    ; PRINT
        db 0,      C_VALUE, C_VALUE, 0,     K_NUM, 60, 0, K_NUM, 10, 0, 0, 0, 0       ; NOTE
        db 0,      C_VAR, C_VALUE, 0,       K_VAR, 0, 0, K_NUM, 0, 0, 0, 0, 0         ; SET
        db 0,      C_VAR, C_VALUE, 0,       K_VAR, 0, 0, K_NUM, 1, 0, 0, 0, 0         ; CHANGE
        assert $ - ops == OP_COUNT * OP_INFO

CATS            equ 5
cat_first:      db 0, 3, 11, 17, 22, OP_COUNT
class_help:     db T_H_LINE, T_H_VALUE, T_H_VAR, T_H_CMP, T_H_SPR, T_H_KEYN
first_values:   db 0, 0, 0, 0, 10, VK_SPACE, 1, 0   ; K_NUM .. K_EDGE
cmp_chars:      db "<=>"
tens:           dw 10000, 1000, 100, 10, 1, 0

; key numbers -> names, then letters, digits and signs
key_names:      db 0, "UP", 0, 1, "RIGHT", 0, 2, "DOWN", 0, 8, "LEFT", 0
                db 6, "ENTER", 0, 9, "COPY", 0, 16, "CLR", 0
                db 18, "RETURN", 0, 47, "SPACE", 0, 66, "ESC", 0
                db 68, "TAB", 0, 79, "DEL", 0
                db 15, "F0", 0, 13, "F1", 0, 14, "F2", 0, 5, "F3", 0
                db 20, "F4", 0, 12, "F5", 0, 4, "F6", 0, 10, "F7", 0
                db 11, "F8", 0, 3, "F9", 0
                db #FF
key_chars:      db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0       ; 0..15
                db 0, "[", 0, "]", 0, 0, "\\", 0, "^-@P;:/.09OILKM,87"  ; 16..41
                db "UYHJN", 0, "65RTGFBV43EWSDCX12", 0, "Q", 0, "A", 0, "Z" ; 42..71
                db 0, 0, 0, 0, 0, 0, 0, 0                               ; 72..79
        assert $ - key_chars == 80

vbs_ext:        db "VBS"
vbs_dot_ext:    db ".VBS", 0
name_none:      db "NONAME", 0, 0, 0

; the program after NEW: sprite 1 bounces
new_prog:       db "VBS", 1, 0, 1
                dw 88, 120 : db 8, 8, 8, 0
                ds (SPR_MAX - 1) * SPR_SIZE
                dw 6
                db OP_START,   K_SPR, 1, 0, 0, 0, 0, 0, 0, 0
                db OP_SPEED,   K_NUM, 2, 0, K_NUM, 2, 0, 0, 0, 0
                db OP_FOREVER, 0, 0, 0, 0, 0, 0, 0, 0, 0
                db OP_MOVE,    0, 0, 0, 0, 0, 0, 0, 0, 0
                db OP_BOUNCE,  0, 0, 0, 0, 0, 0, 0, 0, 0
                db OP_END,     0, 0, 0, 0, 0, 0, 0, 0, 0
new_prog_end:

        include "studio_texts.asm"

; ---- state ----------------------------------------------------------
cursor:         db 0                ; the script's line
top:            db 0                ; the first line on the screen
slot:           db #FF              ; the cursor line's slot, #FF: none
typing:         db 0                ; digits go on the number typed
awaiting:       db 0                ; the next key is the slot's key
focus:          db 0
cat:            db 0                ; palette: category, block in it
pal:            db 0
spr_sel:        db 0
msg:            db 0                ; status line text, 0: the keys
named:          db 0                ; prog_name chosen by the user
prog_name:      ds 9
name_buf:       ds 11
fcb:            ds 11
cat_list:       dw 0

k_code:         db 0
k_char:         db 0
k_letter:       db 0
k_parts:        db 0
click_x:            dw 0
click_y:            dw 0
k_row:          db 0
k_col:          db 0
rf_parts:       db 0
ib_op:          db 0
ib_at:          db 0
dl_op:          db 0
dl_at:          db 0
dl_end:         db 0
dl_else:        db 0
dl_row:         db 0
dl_y:           db 0
dl_bg:          db 0
dl_col:         db 0
sc_class:       db 0
sc_ptr:         dw 0
sd_digit:       db 0
sd_kind:        db 0
sd_sign:        db 0
dp_x:           db 0
dp_y:           db 0
dp_h:           db 0
dp_row:         db 0
dp_ink:         db 0
dp_y16:         dw 0
ds_line:        db 0
ds_old:         db 0
ds_old_top:     db 0
lv_cur:         db 0
lv_base:        db 0
lv_line:        db 0
rl_line:        db 0
rl_ptr:         dw 0
rl_out:         dw 0
rs_slot:        db 0
rs_kind:        db 0
rs_value:       dw 0
slot_col:       ds 3
slot_len:       ds 3
ns_out:         dw 0
ns_started:     db 0
ns_digit:       db 0
fill_pen:       db 0
rc:             dw 0, 0, 0, 0
                db 0
lbuf:           ds 96
tbuf:           ds 40
vbs:            ds VBS_ROOM
studio_end:
        assert studio_end <= VOS_APP_ADDR + #4000
        save "build/STUDIO.BIN", VOS_APP_ADDR, studio_end - VOS_APP_ADDR
