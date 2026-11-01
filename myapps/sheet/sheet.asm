; =====================================================================
; sheet.asm - SHEET, a spreadsheet (made with the SDK): an example of
; VOS_EXT, VX_CALC (API 24), the formula engine CALC.SYS.
;
; Mode 1, 48 columns. A sheet has 16 columns (A-P) and 64 rows; the
; screen shows 5 columns and 19 rows of it, and the cursor's cell with
; its text on the first line. ^M (PAGE) switches to the page: mode 2
; (API 25), 96 columns, black on white, 10 columns of the sheet with
; lines between them. A cell holds up to 40 characters: a
; number (12, -3.5), text, or a formula after "=" (=SUM(B2:B9)*2):
; see src/api/vos_api.inc for what formulas have.
;   ARROWS move, RETURN changes the cell, typing starts a new text,
;   DEL or CLR empties it. After each change every formula is worked out again.
;   SHEET menu: NEW SHEET ^N, OPEN ^O, SAVE ^S, SAVE AS ^A, OTHER DRIVE
;   ^W, PAGE ^M, ABOUT, BACK ^Q
; The cells' texts are kept here; their values (CALC_NONE for text or
; nothing) in the data bank, from GRID, as CALC.SYS reads them: they
; are worked out again whenever the data bank may have been lost (a 6128
; shares it). A sheet is a text file NAME.VSH, a line a cell: "B3 =B1*2".
;   make app NAME=sheet    build/SHEET.BIN
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
HEAD            equ 3
COLS            equ 48              ; mode 1
COLS2           equ 96              ; the page, mode 2
N_COLS          equ 16              ; the sheet
N_ROWS          equ 64
VIS_COLS        equ 5               ; on the screen (mode 1)
VIS_COLS2       equ 10              ; on the page
VIS_ROWS        equ 19
CELL_W          equ 9               ; a column: 8 characters and a space
NUM_W           equ 3               ; the rows' numbers
TOP_Y           equ 14
HEAD_Y          equ 30
ROWS_Y          equ 42
SAID_Y          equ 238
HINT_Y          equ 249
TOP_TEXT        equ 4               ; the cell's text on the first line
TOP_FILE        equ 35              ; and the file's name
CELL_MAX        equ 40              ; characters in a cell
MAX_PASS        equ 10              ; passes to work the formulas out
GRID            equ #7000           ; the values, in the data bank
FILE            equ #4000           ; a file, in the data bank, up to
FILE_MAX        equ #3000           ; GRID
CHUNK           equ 128             ; read and written that much a time
LINE_MAX        equ 63
HEAP_MAX        equ 6400            ; the cells' texts

        assert NUM_W + VIS_COLS2 * CELL_W <= COLS2

CMD_NEW         equ VC_APP + 1      ; menu items: commands
CMD_OPEN        equ VC_APP + 2
CMD_SAVE        equ VC_APP + 3
CMD_SAVE_AS     equ VC_APP + 4
CMD_DRIVE       equ VC_APP + 5
CMD_ABOUT       equ VC_APP + 6
CMD_BACK        equ VC_APP + 7
CMD_PAGE        equ VC_APP + 8

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start, an empty sheet; 2: back (its values worked out
; again: the data bank may have been another's)
init:
        push af
        ld hl,texts
        call VOS_TEXTS
        call set_mode
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        ld a,VX_DATA                ; the data bank its own, if it can be
        call VOS_EXT
        pop af
        cp 2
        jr z,.back
        ld a,(VOS_SELF)             ; files on its own drive at first
        ld (fdrive),a
        call new_sheet
.back:
        call recalc
        call redraw
        ; fall through

; a file to open from the Desktop or the Commander (VOS_OPEN)
open_arg:
        ld hl,VOS_OPEN
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        call discard_ok
        ret nz
        ld a,(VOS_OPEN + 1)
        ld (fdrive),a
        ld hl,VOS_OPEN + 2
        ld de,name_tmp
        ld bc,11
        ldir
        call load_file
        jp redraw

; an empty sheet, NONAME, the cursor at A1
new_sheet:
        ld hl,#FFFF
        ld (heap),hl
        ld hl,heap
        ld (heap_end),hl
        ld hl,noname
        ld de,fname
        ld bc,11
        ldir
        xor a
        ld (modified),a
        ; fall through
home:
        xor a
        ld (cur_c),a
        ld (cur_r),a
        ld (left),a
        ld (top),a
        ret

; C = CALC_* call, HL as it wants (DE: the block)
calc:
        ld de,cb
        ld a,VX_CALC
        jp VOS_EXT

; ---------------------------------------------------------------------
; the cells: entries of dw index (row * 16 + column), db length, the
; text, in the order of their indexes, then #FFFF
; ---------------------------------------------------------------------
; DE = index -> HL -> its entry, Z; or NZ, HL -> where it would go
find:
        ld hl,heap
.next:
        inc hl
        ld a,(hl)
        dec hl
        cp d
        jr c,.skip
        ret nz                      ; after it
        ld a,(hl)
        cp e
        ret z
        jr nc,.after
.skip:
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        ld b,0
        add hl,bc
        jr .next
.after:
        or 1                        ; NZ
        ret

; DE = index, HL -> text, 0 (none: the cell empty) -> carry: no room
set_cell:
        ld (sc_txt),hl
        ld (sc_idx),de
        call find
        ld (sc_at),hl
        jr nz,.add
        inc hl                      ; the old entry out
        inc hl
        ld a,(hl)
        add a,3
        ld c,a
        ld b,0
        push bc
        ld hl,(sc_at)
        add hl,bc
        ex de,hl                    ; DE -> after it
        ld hl,(heap_end)
        inc hl
        inc hl
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ex de,hl
        ld de,(sc_at)
        ldir
        pop bc
        ld hl,(heap_end)
        or a
        sbc hl,bc
        ld (heap_end),hl
.add:
        ld hl,(sc_txt)
        call length
        or a
        ret z
        ld (sc_len),a
        add a,3
        ld c,a
        ld b,0                      ; BC = the entry's size
        ld hl,(heap_end)            ; room for it?
        add hl,bc
        inc hl
        inc hl
        ld de,heap + HEAP_MAX + 1
        or a
        sbc hl,de
        ccf
        ret c
        ld hl,(heap_end)            ; what is after it up by its size
        inc hl
        push hl
        add hl,bc
        ex de,hl
        pop hl
        push bc
        push hl
        ld bc,(sc_at)
        or a
        sbc hl,bc
        inc hl
        ld b,h
        ld c,l
        pop hl
        lddr
        pop bc
        ld hl,(heap_end)
        add hl,bc
        ld (heap_end),hl
        ld hl,(sc_at)               ; the entry
        ld de,(sc_idx)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(sc_len)
        ld (hl),a
        inc hl
        ex de,hl
        ld hl,(sc_txt)
        ld c,a
        ld b,0
        ldir
        or a
        ret

; HL -> text, 0 -> A = its length, CELL_MAX at most; HL kept
length:
        push hl
        ld b,0
.char:
        ld a,(hl)
        or a
        jr z,.end
        inc hl
        inc b
        ld a,b
        cp CELL_MAX
        jr c,.char
.end:
        ld a,b
        pop hl
        ret

; HL -> an entry -> its text in ctext, 0; A = its length
entry_text:
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld de,ctext
        ld c,a
        ld b,0
        or a
        jr z,.end
        ldir
.end:
        ex de,hl
        ld (hl),0
        ret

; cur_c, cur_r -> DE = the cursor's index
cur_index:
        ld a,(cur_c)
        ld c,a
        ld a,(cur_r)
        ; fall through
; C = column, A = row -> DE = the index
index:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or c
        ld e,a
        ld d,h
        ret

; DE = index -> HL = its value's place in the data bank
val_at:
        ex de,hl
        add hl,hl
        add hl,hl
        ld de,GRID
        add hl,de
        ret

; DE = index -> val (4 bytes)
get_val:
        call val_at
        ld de,val
        ld bc,4
        jp VOS_BANK_GET
; DE = index: val there
put_val:
        call val_at
        ex de,hl
        ld hl,val
        ld bc,4
        jp VOS_BANK_PUT

; ---------------------------------------------------------------------
; the values: numbers, text (CALC_NONE), then the formulas, worked out
; again and again while any changes (MAX_PASS at most: those that still
; change are CALC_BAD, a cell that uses itself)
; ---------------------------------------------------------------------
recalc:
        ld a,T_WORKING
        call say_now
        ld hl,fbuf                  ; the grid: CALC_NONE everywhere
        ld b,CHUNK / 4
.none:
        ld (hl),CALC_NONE_LO
        inc hl
        ld (hl),0
        inc hl
        ld (hl),CALC_NONE_HI & 255
        inc hl
        ld (hl),CALC_NONE_HI >> 8
        inc hl
        djnz .none
        ld de,GRID
.clear:
        push de
        ld hl,fbuf
        ld bc,CHUNK
        call VOS_BANK_PUT
        pop hl
        ld de,CHUNK
        add hl,de
        ex de,hl
        ld a,d
        cp #80                      ; up to #7FFF
        jr c,.clear
        ld hl,heap                  ; numbers (text stays CALC_NONE)
.number:
        call at_end
        jr z,.formulas
        push hl
        call entry_text
        ld a,(ctext)
        cp 61                       ; "="
        jr z,.next
        ld hl,ctext
        ld c,CALC_NUMBER
        call calc
        jr nc,.is_num
        cp CALC_ERR_NO_SYS
        jr z,.no_sys
        jr .next
.is_num:
        ld (val),hl
        ld (val + 2),de
        pop hl
        push hl
        call put_entry
.next:
        pop hl
        call next_entry
        jr .number
.no_sys:
        pop hl
        call VOS_ERROR
        jp say_clear
.formulas:
        xor a
        ld (pass),a
.pass:
        ld hl,pass
        inc (hl)
        xor a
        ld (changed),a
        ld hl,heap
.formula:
        call at_end
        jr z,.passed
        push hl
        call entry_text
        ld a,(ctext)
        cp 61                       ; "="
        jr nz,.not
        ld hl,ctext
        ld c,CALC_EVAL
        call calc                   ; -> CB_RESULT (CALC_BAD: an error)
        jr nc,.evaluated
        cp CALC_ERR_NO_SYS
        jr z,.no_sys
.evaluated:
        pop hl
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        call get_val
        ld hl,cb + CB_RESULT        ; the same?
        ld de,val
        ld b,4
.same:
        ld a,(de)
        cp (hl)
        jr nz,.changed
        inc hl
        inc de
        djnz .same
        jr .not
.changed:
        ld a,1
        ld (changed),a
        ld hl,cb + CB_RESULT
        ld de,val
        ld bc,4
        ldir
        ld a,(pass)                 ; the last pass: still changing
        cp MAX_PASS
        jr c,.put
        ld hl,CALC_BAD_LO
        ld (val),hl
        ld hl,CALC_NONE_HI
        ld (val + 2),hl
.put:
        pop hl
        push hl
        call put_entry
.not:
        pop hl
        call next_entry
        jr .formula
.passed:
        ld a,(changed)
        or a
        jr z,say_clear
        ld a,(pass)
        cp MAX_PASS
        jr c,.pass
        ; fall through
say_clear:
        xor a
        ; fall through
; A = text (0: none): on the last line now
say_now:
        ld hl,0
        ld de,SAID_Y
        ld c,COLS
        jp print_label

; HL -> an entry: val as its value
put_entry:
        ld e,(hl)
        inc hl
        ld d,(hl)
        jp put_val

; HL -> an entry -> Z: it is the end (#FFFF)
at_end:
        inc hl
        ld a,(hl)
        dec hl
        inc a
        ret
; HL -> an entry -> HL -> the next one
next_entry:
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        ld b,0
        add hl,bc
        ret

; ---------------------------------------------------------------------
; the screen
; ---------------------------------------------------------------------
redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        ld a,T_HINT
        ld hl,0
        ld de,HINT_Y
        ld c,COLS
        call print_label
        call draw_said
        ; fall through
draw_all:
        call draw_top
        call draw_head
        ; fall through
draw_rows:
        xor a
.row:
        push af
        call draw_row
        pop af
        inc a
        cp VIS_ROWS
        jr c,.row
        ret

; what was said last, once
draw_said:
        ld a,(said)
        push af
        xor a
        ld (said),a
        pop af
        jr say_now

; the first line: "B3  =B1*2" and "A:NAME.VSH"
draw_top:
        call blank_line
        ld a,(cur_c)
        add a,"A"
        ld (line),a
        ld a,(cur_r)
        inc a
        ld de,line + 1
        call put_num
        call cur_index
        call find
        jr nz,.place
        call entry_text
        ld hl,ctext
        ld de,line + TOP_TEXT
        ld b,TOP_FILE - TOP_TEXT - 1
.char:
        ld a,(hl)
        or a
        jr z,.place
        ld (de),a
        inc hl
        inc de
        djnz .char
.place:
        ld de,line + TOP_FILE
        ld a,(fdrive)
        add a,"A"
        ld (de),a
        inc de
        ld a,":"
        ld (de),a
        inc de
        ld hl,fname
        ld b,8
.name:
        ld a,(hl)
        inc hl
        cp " "
        jr z,.skip
        ld (de),a
        inc de
.skip:
        djnz .name
        ld a,"."
        ld (de),a
        inc de
        ld bc,3
        ldir
        ld a,HEAD + VOS_BOLD
        ld c,BG
        call VOS_COLOURS
        ld hl,0
        ld de,TOP_Y
        ld bc,line
        jp VOS_PRINT

; the columns' letters
draw_head:
        call blank_line
        ld a,(vcols)
        ld b,a
        ld hl,line + NUM_W + 4
        ld a,(left)
        add a,"A"
.col:
        ld (hl),a
        inc a
        ld de,CELL_W
        add hl,de
        djnz .col
        ld a,HEAD + VOS_BOLD
        ld c,BG
        call VOS_COLOURS
        ld hl,0
        ld de,HEAD_Y
        ld bc,line
        jp VOS_PRINT

; A = a row on the screen: its number, its cells, the cursor's inverted
draw_row:
        ld (srow),a
        call blank_line
        ld a,(srow)
        ld hl,top
        add a,(hl)
        ld (row),a
        cp N_ROWS
        jr nc,.print                ; after the last: empty
        inc a
        ld de,line
        cp 10
        jr nc,.two
        inc de
.two:
        call put_num
        ld a,(left)
        ld (col),a
        ld de,line + NUM_W
.cell:
        push de
        call cell_show
        pop de
        ld hl,CELL_W
        add hl,de
        ex de,hl
        ld a,(col)
        inc a
        ld (col),a
        ld hl,left
        sub (hl)
        ld hl,vcols
        cp (hl)
        jr c,.cell
.print:
        call colours
        ld a,(srow)
        call row_y
        ld hl,0
        ld bc,line
        call VOS_PRINT
        call draw_grid
        ld a,(row)                  ; its number
        cp N_ROWS
        ret nc
        ld hl,line
        ld de,lbuf
        ld bc,NUM_W
        ldir
        xor a
        ld (de),a
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
        ld a,(srow)
        call row_y
        ld hl,0
        ld bc,lbuf
        call VOS_PRINT
        ld a,(row)                  ; the cursor's cell
        ld hl,cur_r
        cp (hl)
        ret nz
        ld a,(cur_c)
        ld hl,left
        sub (hl)
        ld e,a                      ; * CELL_W + NUM_W
        add a,a
        add a,a
        add a,a
        add a,e
        add a,NUM_W
        ld l,a
        ld h,0
        push hl
        ld de,line
        add hl,de
        ld de,lbuf
        ld bc,CELL_W - 1
        ldir
        xor a
        ld (de),a
        ld a,BG
        ld c,INK
        call VOS_COLOURS
        ld a,(srow)
        call row_y
        pop hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,lbuf
        jp VOS_PRINT

; the page: a line between the cells of the row srow
draw_grid:
        ld a,(pmode)
        cp 2
        ret nz
        ld a,(srow)
        call row_y
        ld (grid_rect + 2),de
        ld ix,grid_rect
        ld hl,NUM_W * 8 - 4         ; in the space before each cell
        ld a,(vcols)
        inc a
        ld b,a
.line:
        push bc
        push hl
        ld (ix+0),l
        ld (ix+1),h
        call VOS_RECT
        pop hl
        ld de,CELL_W * 8
        add hl,de
        pop bc
        djnz .line
        ret

; left: the cursor's column on the screen, and the last one at most P
fit_left:
        ld a,(cur_c)
        ld hl,left
        cp (hl)
        jr nc,.not_left
        ld (hl),a
        jr .max
.not_left:
        ld b,a
        ld a,(vcols)
        dec a
        ld c,a
        ld a,b
        sub c
        jr c,.max
        cp (hl)
        jr c,.max
        ld (hl),a
.max:
        ld a,(vcols)
        ld b,a
        ld a,N_COLS
        sub b
        cp (hl)
        ret nc
        ld (hl),a
        ret

; the mode of pmode: its palette, its columns
set_mode:
        ld a,(pmode)
        call VOS_MODE
        ld hl,palette
        ld bc,COLS * 256 + VIS_COLS
        ld a,(pmode)
        cp 2
        jr nz,.set
        ld hl,palette2
        ld bc,COLS2 * 256 + VIS_COLS2
.set:
        ld a,b
        ld (ncols),a
        ld a,c
        ld (vcols),a
        jp VOS_PALETTE

; A = row on the screen -> DE = its y
row_y:
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,a                     ; * 10
        add a,ROWS_Y
        ld e,a
        ld d,0
        ret

; col, row: the cell as 8 characters at DE (a number on the right; one
; too long "########"; text on the left)
cell_show:
        push de
        ld a,(col)
        ld c,a
        ld a,(row)
        call index
        push de
        call get_val
        pop de
        ld hl,(val + 2)             ; CALC_NONE: text or nothing
        ld bc,CALC_NONE_HI
        or a
        sbc hl,bc
        jr nz,.number
        ld hl,(val)
        ld a,h
        or l
        jr nz,.number
        call find
        pop de
        ret nz
        push de
        call entry_text
        pop de
        ld hl,ctext
        ld b,CELL_W - 1
.text:
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        djnz .text
        ret
.number:
        ld hl,val
        ld de,cb + CB_RESULT
        ld bc,4
        ldir
        ld hl,ntext
        ld c,CALC_TEXT
        call calc                   ; -> A = its length
        pop de
        ld c,a
        cp CELL_W
        jr nc,.long
        ld a,CELL_W - 1             ; on the right
        sub c
        add a,e
        ld e,a
        jr nc,.at
        inc d
.at:
        ld b,0
        ld hl,ntext
        ld a,c
        or a
        ret z
        ldir
        ret
.long:
        ld a,"#"
        ld b,CELL_W - 1
.hash:
        ld (de),a
        inc de
        djnz .hash
        ret

; A = 1..99 -> its digits at DE, DE after them
put_num:
        ld b,"0" - 1
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,10 + "0"
        ld c,a
        ld a,b
        cp "0"
        jr z,.one
        ld (de),a
        inc de
.one:
        ld a,c
        ld (de),a
        inc de
        ret

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        push hl
        call VOS_UI_EVENT           ; menus and CONTROL+letter first
        pop hl
        or a
        jp nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(hl)
        cp VE_KEY_DOWN
        jr z,.key
        cp VE_KEY_REPEAT
        ret nz
.key:
        inc hl
        ld a,(hl)                   ; the key, its character
        inc hl
        ld c,(hl)
        push af
        ld a,(cur_r)
        ld (prev_r),a
        pop af
        ld hl,cur_c
        cp VK_RIGHT
        jr z,.right
        cp VK_LEFT
        jr z,.left
        inc hl                      ; cur_r
        cp VK_DOWN
        jr z,.down
        cp VK_UP
        jr z,.up
        cp VK_RETURN
        jr z,.edit
        cp VK_ENTER
        jr z,.edit
        cp VK_DEL
        jr z,.clear
        cp 16                       ; CLR
        jr z,.clear
        ld a,c                      ; a character: a new text from it
        cp " "
        ret c
        cp 127
        ret z
        ld (input),a
        xor a
        ld (input + 1),a
        jp edit_cell
.right:
        ld a,(hl)
        cp N_COLS - 1
        ret nc
        inc (hl)
        jr moved
.left:
.up:
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jr moved
.down:
        ld a,(hl)
        cp N_ROWS - 1
        ret nc
        inc (hl)
        jr moved
.edit:
        call cur_index              ; its text to change
        call find
        ld hl,input
        ld (hl),0
        jr nz,.edit_it
        call entry_text
        ld hl,ctext
        ld de,input
        ld bc,CELL_MAX + 1
        ldir
.edit_it:
        jp edit_cell
.clear:
        call cur_index
        ld hl,empty
        call set_cell
        jp changed_cell

; the cursor moved: the screen after it (scrolled: all of it; else
; the row it was on and the one it is on)
moved:
        ld hl,(left)                ; left, top
        ld (was),hl
        call fit_left               ; a column on the screen
.rows:
        ld a,(cur_r)
        ld hl,top
        cp (hl)
        jr nc,.not_up
        ld (hl),a
        jr .shown
.not_up:
        sub VIS_ROWS - 1
        jr c,.shown
        cp (hl)
        jr c,.shown
        ld (hl),a
.shown:
        ld hl,(was)
        ld de,(left)
        or a
        sbc hl,de
        jp nz,draw_all
        call draw_top
        ld a,(prev_r)
        ld hl,top
        sub (hl)
        call draw_row
        ld a,(cur_r)
        ld hl,top
        sub (hl)
        jp draw_row

; input: the cursor's new text (a formula: a wrong one asked again)
edit_cell:
        ld a,T_EDIT_T
        ld hl,input
        ld c,CELL_MAX
        call VOS_INPUT
        ret c
        ld hl,input                 ; without spaces after it
        call length
        ld e,a
        ld d,0
.trim:
        ld a,e
        or a
        jr z,.trimmed
        ld hl,input - 1
        add hl,de
        ld a,(hl)
        cp " "
        jr nz,.trimmed
        ld (hl),0
        dec e
        jr .trim
.trimmed:
        ld a,(input)
        cp 61                       ; "="
        jr nz,.store
        ld hl,input
        ld c,CALC_EVAL
        call calc
        jr nc,.store
        cp CALC_ERR_SYNTAX
        jr nz,.store                ; (a cell's error: it shows "#ERR")
        call VOS_ERROR
        jr edit_cell
.store:
        call cur_index
        ld hl,input
        call set_cell
        jr nc,.set
        ld hl,dlg_full
        jp VOS_DIALOG
.set:
        ld hl,cur_r                 ; then the cell below
        ld a,(hl)
        cp N_ROWS - 1
        jr nc,changed_cell
        inc (hl)
        ld a,(hl)
        ld hl,top
        sub VIS_ROWS - 1
        jr c,changed_cell
        cp (hl)
        jr c,changed_cell
        ld (hl),a
        ; fall through
changed_cell:
        ld a,1
        ld (modified),a
        call recalc
        jp draw_all

; ---------------------------------------------------------------------
; the menu
; ---------------------------------------------------------------------
; A = command
command:
        cp CMD_NEW
        jr nz,.not_new
        call discard_ok
        ret nz
        call new_sheet
        call recalc
        jp redraw
.not_new:
        cp CMD_OPEN
        jp z,open
        cp CMD_SAVE
        jp z,save_it
        cp CMD_SAVE_AS
        jp z,save_as
        cp CMD_DRIVE
        jr nz,.not_drive
        ld a,(fdrive)               ; A: <-> B:
        xor 1
        ld (fdrive),a
        jp draw_top
.not_drive:
        cp CMD_PAGE
        jr nz,.not_page
        ld hl,pmode                 ; mode 1 <-> the page, mode 2
        ld a,(hl)
        xor 3
        ld (hl),a
        call set_mode
        call fit_left
        jp redraw
.not_page:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        call discard_ok
        ret nz
        jp VOS_EXIT

; -> Z: nothing changed, or the changes may go
discard_ok:
        ld a,(modified)
        or a
        ret z
        ld hl,dlg_discard
        call VOS_DIALOG
        or a                        ; YES is button 0
        ret

; ---------------------------------------------------------------------
; files: text, a line "B3 text" a cell, through the data bank
; ---------------------------------------------------------------------
; OPEN: a .VSH file of fdrive
open:
        call discard_ok
        ret nz
        ld a,(fdrive)
        or VOS_CAT_EXT
        ld hl,ext_vsh
        call VOS_CATALOG
        jp c,VOS_ERROR
        or a
        jr nz,.pick
        ld hl,dlg_no_files
        jp VOS_DIALOG
.pick:
        ld (cat),hl
        ld a,T_PICK_T
        call VOS_FILE_PICK
        ret c
        ld l,a                      ; HL -> its entry (16 bytes)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cat)
        add hl,de
        ld de,name_tmp
        ld bc,11
        ldir
        call load_file
        jp redraw

; name_tmp on fdrive into the data bank, then its lines into cells
load_file:
        ld a,(fdrive)
        or VOS_DATA
        ld hl,name_tmp
        ld de,FILE
        call VOS_LOAD
        jr nc,.loaded
        call VOS_ERROR
        jp recalc                   ; (the data bank lost)
.loaded:
        ld hl,FILE_MAX
        or a
        sbc hl,bc
        jr nc,.fits
        ld hl,dlg_big
        call VOS_DIALOG
        jp recalc
.fits:
        ld hl,FILE                  ; UTF-8 into the V-OS set
        ld e,VOS_DATA
        ld a,VX_UTF8
        call VOS_EXT                ; -> BC
        ld (flen),bc
        call new_sheet
        ld hl,name_tmp
        ld de,fname
        ld bc,11
        ldir
        ld hl,0
        ld (fpos),hl
        xor a
        ld (fb_n),a
        ld (fb_i),a
.line:
        call read_line
        jr c,.read
        call line_cell
        jr nc,.line
        ld hl,dlg_full              ; no room: as much as fitted
        call VOS_DIALOG
.read:
        jp recalc

; lbuf: "B3 text" -> that cell; carry: no room
line_cell:
        ld hl,lbuf
        ld c,CALC_CELL
        call calc                   ; -> D = column, E = row, A
        ccf
        ret nc                      ; not a cell: no line of a sheet
        ld c,a
        ld a,d                      ; outside the sheet: none either
        cp N_COLS
        ret nc
        ld a,e
        cp N_ROWS
        ret nc
        ld b,0
        ld hl,lbuf
        add hl,bc
        ld a,(hl)
        cp " "
        jr nz,.text
        inc hl
.text:
        push hl
        ld c,d
        ld a,e
        call index
        pop hl
        jp set_cell

; the next line of the file into lbuf (without CR, LF; LINE_MAX
; characters at most) -> carry: none left
read_line:
        ld de,lbuf
        ld b,0                      ; its characters
.byte:
        call get_byte
        jr c,.end
        cp 26                       ; the end-of-file mark
        jr z,.eof
        cp 13
        jr z,.byte
        cp 10
        jr z,.done
        ld c,a
        ld a,b
        cp LINE_MAX
        jr nc,.byte
        ld a,c
        ld (de),a
        inc de
        inc b
        jr .byte
.eof:
        ld hl,(flen)                ; nothing after it
        ld (fpos),hl
        xor a
        ld (fb_n),a
        ld (fb_i),a
.end:
        ld a,b                      ; at the end: a last line?
        or a
        scf
        ret z
.done:
        xor a
        ld (de),a
        ret

; -> A = the next byte of the file; carry: the end
get_byte:
        ld a,(fb_i)
        ld hl,fb_n
        cp (hl)
        jr c,.have
        push de                     ; the next chunk
        push bc
        ld hl,(flen)
        ld de,(fpos)
        or a
        sbc hl,de                   ; bytes left
        ld a,h
        or a
        jr nz,.chunk
        ld a,l
        cp CHUNK
        jr c,.some
.chunk:
        ld a,CHUNK
.some:
        ld (fb_n),a
        or a
        jr z,.none
        ld c,a
        ld b,0
        ld hl,FILE
        add hl,de
        push bc
        ld de,fbuf
        call VOS_BANK_GET
        pop bc
        ld hl,(fpos)
        add hl,bc
        ld (fpos),hl
        pop bc
        pop de
        xor a
.have:
        ld l,a
        inc a
        ld (fb_i),a
        ld h,0
        push de
        ld de,fbuf
        add hl,de
        pop de
        ld a,(hl)
        or a                        ; no carry
        ret
.none:
        pop bc
        pop de
        scf
        ret

; SAVE: NONAME asks for a name first
save_it:
        ld hl,fname
        ld de,noname
        ld b,11
.same:
        ld a,(de)
        cp (hl)
        jr nz,write
        inc hl
        inc de
        djnz .same
        ; fall through
; SAVE AS: a name (8 characters), .VSH
save_as:
        ld a,T_NAME_T
        ld c,8
        call ask_name               ; -> name_buf
        ret c
        ld hl,name_buf
        ld de,fname
        ld bc,8
        ldir
        ld hl,ext_vsh
        ld bc,3
        ldir
        ; fall through
; the cells as lines into the data bank, then to the disc
write:
        ld hl,0
        ld (fpos),hl
        xor a
        ld (fb_n),a
        ld hl,heap
.entry:
        call at_end
        jr z,.save
        push hl
        ld a,(hl)                   ; its name: column, row
        and N_COLS - 1
        add a,"A"
        call put_byte
        ld a,(hl)                   ; the row: index / 16
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld c,a
        inc hl
        ld a,(hl)
        add a,a
        add a,a
        add a,a
        add a,a
        or c
        inc a
        ld de,ntext
        call put_num                ; -> DE after it
        ld hl,ntext
.digit:
        ld a,(hl)
        call put_byte
        inc hl
        ld a,l
        cp e
        jr nz,.digit
        ld a," "
        call put_byte
        pop hl
        push hl
        inc hl
        inc hl
        ld b,(hl)
.char:
        inc hl
        ld a,(hl)
        call put_byte
        djnz .char
        ld a,13
        call put_byte
        ld a,10
        call put_byte
        pop hl
        call next_entry
        jr .entry
.save:
        call flush
        ld a,(fdrive)
        or VOS_DATA
        ld hl,fname
        ld de,FILE
        ld bc,(fpos)
        call VOS_SAVE
        jr nc,.saved
        call VOS_ERROR
        call recalc
        jp draw_all
.saved:
        xor a
        ld (modified),a
        ld a,T_SAVED
        ld (said),a
        call recalc                 ; (the data bank may be lost)
        call draw_said
        jp draw_top

; A: one more byte of the file (HL, DE, BC kept)
put_byte:
        push hl
        push de
        push bc
        ld hl,fb_n
        ld e,(hl)
        inc (hl)
        ld d,0
        ld hl,fbuf
        add hl,de
        ld (hl),a
        ld a,(fb_n)
        cp CHUNK
        call z,flush
        pop bc
        pop de
        pop hl
        ret
; fbuf's bytes into the data bank
flush:
        ld a,(fb_n)
        or a
        ret z
        ld c,a
        ld b,0
        ld hl,(fpos)
        push hl
        add hl,bc
        ld (fpos),hl
        pop hl
        ld de,FILE
        add hl,de
        ex de,hl
        ld hl,fbuf
        call VOS_BANK_PUT
        xor a
        ld (fb_n),a
        ret

; A = title, C = length -> name_buf: what was typed, in capitals,
; padded with spaces; carry: nothing
ask_name:
        ld hl,input
        ld (hl),0
        push bc
        call VOS_INPUT
        pop bc
        ret c
        ld hl,input
        ld a,(hl)
        or a
        scf
        ret z
        ld de,name_buf
        ld b,c
.char:
        ld a,(hl)
        or a
        jr z,.pad
        cp "."
        jr z,.pad
        cp "a"
        jr c,.cap
        cp "z" + 1
        jr nc,.cap
        sub 32
.cap:
        ld (de),a
        inc hl
        inc de
        djnz .char
        or a
        ret
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
        or a
        ret

; ---------------------------------------------------------------------
; little things
; ---------------------------------------------------------------------
; line: ncols spaces, 0
blank_line:
        ld a,(ncols)
        ld b,a
        ld hl,line
.space:
        ld (hl)," "
        inc hl
        djnz .space
        ld (hl),0
        ret

colours:
        ld a,INK
        ld c,BG
        jp VOS_COLOURS

; A = text (0: none), HL = x, DE = y, C = width: it, then spaces
print_label:
        push hl
        push de
        push bc
        ld hl,empty
        or a
        call nz,VOS_MSG
        pop bc
        ld b,c
        ld de,lbuf
.copy:
        ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .copy
        jr .end
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
.end:
        xor a
        ld (de),a
        call colours
        pop de
        pop hl
        ld bc,lbuf
        jp VOS_PRINT

; ---- data -----------------------------------------------------------
; black, white, blue, bright yellow (mode 1: pens 0..3), the border
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1
; the page: white paper, black ink (pens 2, 3 are 0, 1)
palette2:       db 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0
                db 13
grid_rect:      dw 0, 0, 1, 10
                db INK
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 10
                db T_NEW, CMD_NEW, "N", 0
                db T_OPEN, CMD_OPEN, "O", 0
                db T_SAVE, CMD_SAVE, "S", 0
                db T_SAVE_AS, CMD_SAVE_AS, "A", 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_DRIVE, CMD_DRIVE, "W", 0
                db T_PAGE, CMD_PAGE, "M", 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_discard:    db T_MENU, T_DISCARD, 2, VM_YES, VM_NO
dlg_no_files:   db T_MENU, T_NO_FILES, 1, VM_OK
dlg_full:       db T_MENU, T_FULL, 1, VM_OK
dlg_big:        db T_MENU, T_BIG, 1, VM_OK
ext_vsh:        db "VSH"
noname:         db "NONAME  VSH"
empty:          db 0
        include "app_texts.asm"     ; texts, from texts.txt

cb:             db 0, 0, 0, 0, N_COLS, N_ROWS
                dw GRID
                db VOS_DATA, 0
fdrive:         db 0
fname:          ds 11
name_tmp:       ds 11
name_buf:       ds 8
modified:       db 0
said:           db 0                ; a text for the last line, once
pmode:          db 1                ; 1, or 2: the page (^M)
ncols:          db COLS             ; the characters of a line
vcols:          db VIS_COLS         ; the sheet's columns on the screen
cur_c:          db 0
cur_r:          db 0
left:           db 0                ; the first column, row on the screen
top:            db 0
was:            dw 0
prev_r:         db 0
srow:           db 0
row:            db 0
col:            db 0
pass:           db 0
changed:        db 0
cat:            dw 0
val:            ds 4
sc_txt:         dw 0
sc_idx:         dw 0
sc_at:          dw 0
sc_len:         db 0
flen:           dw 0
fpos:           dw 0
fb_n:           db 0
fb_i:           db 0
ntext:          ds CALC_TEXT_MAX + 2
input:          ds CELL_MAX + 2
ctext:          ds CELL_MAX + 1
line:           ds COLS2 + 1
lbuf:           ds LINE_MAX + 1
fbuf:           ds CHUNK
heap_end:       dw 0
heap:           ds HEAP_MAX + 2
sheet_end:
