; =====================================================================
; database.asm - DATABASE, a small Access on V-OS databases (made with
; the SDK): an example of VOS_EXT, VX_DB (API 22, DB_ALPHA of 23).
;
; Mode 1, 48 columns. A database is one NAME.VDB on a drive (A: or B:,
; OTHER DRIVE), opened from the menu, or from the Desktop by its type.
;   the list    the table in use, a record a row, its fields in columns
;               (as many as fit); UP, DOWN choose a record, LEFT, RIGHT
;               a screen; RETURN opens the form; TAB the next table;
;               with a key field, typing goes to the records that start
;               so (DB_FIND), DEL takes a letter back
;   the form    a field a row; UP, DOWN choose one, RETURN changes it;
;               ^S saves the record (a new one is added), ^B goes back
;               to the list without saving
;   DATABASE menu: NEW DATABASE ^N, OPEN A DATABASE ^O, NEW TABLE ^T,
;   ADD A RECORD ^A, DELETE THE RECORD ^D, SAVE THE RECORD ^S, BACK TO
;   THE LIST ^B, OTHER DRIVE ^W, PRINT ^P (VX_PRINT, API 30: the table
;   as the list shows it, every record), PRINT LETTERS ^L, IMPORT CSV,
;   ABOUT, BACK ^Q
; PRINT LETTERS prints a .TXT of the drive (a letter written in NOTEPAD)
; once a record of the table in use, a page each: a field's name in
; braces, {NAME}, becomes what the record has in it.
; IMPORT CSV adds a record for each line of a .CSV (from a PC, or SHEET's
; drive), into the table in use: its fields in order, by commas or
; semicolons (the first line says which), "quoted" fields may hold them,
; "" is a quote; a text cut to its field's length, a number its digits
; (0..65535). A first line that starts with the first field's name is
; the heads: left out. The file comes through the data bank.
; A new table asks its name, then its fields: a name, TEXT or NUMBER
; (0..65535), a text's length (1..40); then whether the first field is
; its key. Text is DB_ALPHA: sorted and found without case or accents.
;   make app NAME=database    build/DATABASE.BIN
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
HEAD            equ 3
COLS            equ 48
N_ROWS          equ 18              ; records on the screen
TOP_Y           equ 14
HEAD_Y          equ 32
LIST_Y          equ 46
FORM_Y          equ 44
FORM_H          equ 16
MID_Y           equ 120
SAID_Y          equ 238
HINT_Y          equ 249
TEXT_MAX        equ 40              ; a text field's length at most
TYPED_X         equ 30              ; what was typed to find: its column
TYPED_MAX       equ COLS - TYPED_X - 1
VALUE_X         equ FIELD_LEN + 2   ; a value's column in the form
COL_MAX         equ 16              ; and in a column of the list
INFO_SIZE       equ 124             ; DB_INFO
FIELD_LEN       equ 8
REC_MAX         equ 255

CMD_NEW_DB      equ VC_APP + 1      ; menu items: commands
CMD_OPEN_DB     equ VC_APP + 2
CMD_NEW_TABLE   equ VC_APP + 3
CMD_ADD         equ VC_APP + 4
CMD_DELETE      equ VC_APP + 5
CMD_SAVE        equ VC_APP + 6
CMD_LIST        equ VC_APP + 7
CMD_DRIVE       equ VC_APP + 8
CMD_ABOUT       equ VC_APP + 9
CMD_BACK        equ VC_APP + 10
CMD_PRINT       equ VC_APP + 11
CMD_CSV         equ VC_APP + 12
CMD_LETTERS     equ VC_APP + 13
CSV_DATA        equ #4000           ; IMPORT CSV: the file, in the data bank
CSV_MAX         equ #4000

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start (a .VDB from the Desktop, maybe); 2: back, its
; database open again (another program may have opened its own)
init:
        push af
        ld hl,texts
        call VOS_TEXTS
        ld a,1
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        pop af
        cp 2
        jr z,.back
        ld a,(VOS_SELF)             ; its own drive at first
        ld (db_file),a
        xor a
        ld (db_ok),a
        ld (mode),a
        ld hl,VOS_OPEN              ; a database to open?
        ld a,(hl)
        or a
        jr z,.shown
        ld (hl),0
        ld hl,VOS_OPEN + 1
        ld de,db_file
        ld bc,12
        ldir
        call open_file
        jr .shown
.back:
        ld a,(db_ok)
        or a
        jr z,.shown
        call reopen
.shown:
        jp redraw

; db_file open again, its table in use -> db_ok
reopen:
        xor a
        ld (db_ok),a
        ld c,DB_OPEN
        ld de,db_file
        call vdb
        jp c,VOS_ERROR
        ld a,1
        ld (db_ok),a
        ld a,(tbl)
        jp use_table

; db_file -> open, its first table in use; carry: not open (said)
open_file:
        xor a
        ld (db_ok),a
        ld (mode),a
        ld c,DB_OPEN
        ld de,db_file
        call vdb
        jr nc,.open
        call VOS_ERROR
        scf
        ret
.open:
        or a                        ; Latin-1, of V-OS 0.15: say so
        ld a,DB_ERR_ALPHABET
        call nz,VOS_ERROR
        ld a,1
        ld (db_ok),a
        xor a
        ; fall through
; A = table: in use, its fields laid out, the list from its first
; record (no table: tables = 0)
use_table:
        ld (tbl),a
        xor a
        ld (typed_n),a
        ld (sel),a
        ld (nrows),a
        ld a,(tbl)
        ld e,a
        ld c,DB_INFO
        ld hl,info
        call vdb
        jr c,.none
        ld (tables),a
        ld a,(tbl)
        ld e,a
        ld c,DB_USE
        call vdb
        jr c,.none
        call layout
        jp fill_first
.none:
        xor a
        ld (tables),a
        ret

; info -> f_off, col_x, col_w: each field's place in a record and its
; column in the list (#FF: it does not fit)
layout:
        ld ix,info + DB_T_FIELD
        ld a,(info + DB_T_FIELDS)
        ld b,a
        ld c,0                      ; the record's offset
        ld e,0                      ; the column
        ld hl,0                     ; the field
.field:
        push hl
        ld a,l
        ld (fld),a
        ld hl,f_off
        call at_fld
        ld (hl),c
        ld a,c
        add a,(ix + 9)
        ld c,a
        ld a,(ix + 8)               ; its width: a number 5, text up to
        cp DB_NUMBER                ; COL_MAX
        ld a,5
        jr z,.width
        ld a,(ix + 9)
        cp COL_MAX
        jr c,.width
        ld a,COL_MAX
.width:
        cp 4
        jr nc,.wide
        ld a,4
.wide:
        ld d,a
        ld hl,col_w
        call at_fld
        ld (hl),d
        ld hl,col_x                 ; does it fit?
        call at_fld
        ld a,e
        add a,d
        cp COLS + 1
        ld a,#FF
        jr nc,.x
        ld a,e
.x:
        ld (hl),a
        inc a
        jr z,.next
        ld a,e
        add a,d
        inc a
        ld e,a
.next:
        push de
        ld de,10
        add ix,de
        pop de
        pop hl
        inc l
        djnz .field
        ret

; HL -> a table of 10 bytes -> HL -> its byte for fld
at_fld:
        push de
        ld a,(fld)
        ld e,a
        ld d,0
        add hl,de
        pop de
        ret

; C = DB_* call, DE, HL as it wants
vdb:
        ld a,VX_DB
        jp VOS_EXT

; ---------------------------------------------------------------------
; the list: rids of the records on the screen. The table's cursor is
; always at the last of them, so DB_NEXT gives the one after it.
; ---------------------------------------------------------------------
fill_first:
        ld c,DB_FIRST
        ld hl,rbuf
        call vdb
        jr fill_from
; with what was typed: DB_FIND
fill_find:
        call key_typed              ; -> HL -> the key, E = its bytes
        ld c,DB_FIND
        call vdb
        jr nc,fill_from
        ld c,DB_LAST                ; after the last: the last one
        ld hl,rbuf
        call vdb
        ; fall through
; carry, or DE = the first record (the cursor there): the rows from it
fill_from:
        ld a,0
        ld (nrows),a
        ret c
fill_rest:
        ld (cur_rid),de
        ld hl,nrows
        ld a,(hl)
        inc (hl)
        add a,a
        ld l,a
        ld h,0
        ld bc,rids
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(nrows)
        cp N_ROWS
        ret z
        ld c,DB_NEXT
        ld hl,rbuf
        call vdb
        ret c
        jr fill_rest

; the record after the last row: the rows up by one; Z: none
scroll_down:
        ld a,(nrows)
        cp N_ROWS
        ret nz                      ; (Z if none, as there are fewer)
        ld c,DB_NEXT
        ld hl,rbuf
        call vdb
        jr c,.none
        push de
        ld hl,rids + 2
        ld de,rids
        ld bc,(N_ROWS - 1) * 2
        ldir
        pop de
        ld (rids + (N_ROWS - 1) * 2),de
        ld (cur_rid),de
        or 1
        ret
.none:
        xor a
        ret

; A = rows to go up (the cursor at the last row): DB_PREV that many
; times past the first row, as far as there are records, then the rows
; from where it stopped
scroll_up:
        ld b,a
        ld a,(nrows)
        add a,b
        dec a
        ld b,a                      ; PREVs from the last row
        ld de,(rids)
        ld (cur_rid),de
.prev:
        push bc
        ld c,DB_PREV
        ld hl,rbuf
        call vdb
        pop bc
        jr c,.top
        ld (cur_rid),de
        djnz .prev
.top:
        ld de,(cur_rid)
        xor a
        ld (nrows),a
        jp fill_rest

; -> HL -> the key typed (in key_buf, as in a record), E = its bytes
; (a number: 0, all of it)
key_typed:
        ld a,(info + DB_T_KEY)
        dec a
        ld (fld),a
        call fld_type
        cp DB_NUMBER
        jr z,.number
        ld hl,typed
        ld de,key_buf
        ld bc,TEXT_MAX
        ldir
        ld hl,key_buf
        ld a,(typed_n)
        ld e,a
        ret
.number:
        ld hl,typed
        ld a,(typed_n)
        call parse                  ; -> DE (too big: 65535)
        ld (key_buf),de
        ld hl,key_buf
        ld e,0
        ret

; fld -> A = its type; fld_len: A = its length
fld_type:
        call fld_desc
        ld a,(hl)
        ret
fld_len:
        call fld_desc
        inc hl
        ld a,(hl)
        ret
; -> HL -> fld's type in info (DE kept)
fld_desc:
        push de
        ld a,(fld)
        ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de                   ; * 10
        ld de,info + DB_T_FIELD + FIELD_LEN
        add hl,de
        pop de
        ret

; ---------------------------------------------------------------------
; the screen
; ---------------------------------------------------------------------
redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        call draw_hint
        call draw_top
        ld a,(db_ok)
        or a
        ld a,T_NONE_OPEN
        jr z,.middle
        ld a,(tables)
        or a
        ld a,T_NO_TABLE
        jr z,.middle
        ld a,(mode)
        or a
        jp nz,draw_form
        call draw_head
        call draw_rows
        jp draw_said
.middle:
        ld hl,0
        ld de,MID_Y
        ld c,COLS
        jp print_label

draw_hint:
        ld a,(mode)
        or a
        ld a,T_HINT_LIST
        jr z,.hint
        ld a,T_HINT_FORM
.hint:
        ld hl,0
        ld de,HINT_Y
        ld c,COLS
        jp print_label

; the first line: "B:NAME.VDB  TABLE NAME  FIND: abc_"
draw_top:
        call blank_line
        ld a,(db_ok)
        or a
        jr z,.drive
        ld de,line
        ld hl,db_file
        call put_place
        ld a,(tables)
        or a
        jr z,.print
        ld hl,line + 14             ; the table's name
        ex de,hl
        ld hl,info + DB_T_NAME
        ld bc,8
        ldir
        ld a,(mode)                 ; the list: what was typed
        or a
        jr nz,.print
        ld a,(info + DB_T_KEY)
        or a
        jr z,.print
        ld hl,line + TYPED_X
        ld a,(typed_n)
        ld b,a
        ld de,typed
        inc b
        jr .type
.char:
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
.type:
        djnz .char
        ld (hl),"_"
        jr .print
.drive:
        ld a,(db_file)              ; no database: the drive
        ld de,line
        call vos_drive_text
.print:
        ld a,HEAD + VOS_BOLD
        ld c,BG
        call VOS_COLOURS
        ld hl,0
        ld de,TOP_Y
        ld bc,line
        call VOS_PRINT
        ld a,(mode)
        or a
        ret nz
        ld a,(tables)
        or a
        ret z
        ld a,(info + DB_T_KEY)
        or a
        ret z
        ld a,T_FIND                 ; "FIND:" before what was typed
        ld hl,(TYPED_X - 6) * 8
        ld de,TOP_Y
        ld c,5
        jp print_label

; DE -> line, HL -> db drive, 11-byte name: "A:NAME.VDB"
put_place:
        ld a,(hl)
        call vos_drive_text
        inc hl
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
        ret

; the columns' heads: each field's name, as much as its column has
draw_head:
        call head_line
        ld a,HEAD + VOS_UNDERLINE
        ld c,BG
        call VOS_COLOURS
        ld hl,0
        ld de,HEAD_Y
        ld bc,line
        jp VOS_PRINT

; the fields' names over their columns, in line
head_line:
        call blank_line
        xor a
        ld (fld),a
.field:
        ld hl,col_x
        call at_fld
        ld a,(hl)
        cp #FF
        jr z,.next
        ld e,a
        ld d,0
        ld hl,line
        add hl,de
        push hl
        ld hl,col_w
        call at_fld
        ld a,(hl)
        cp FIELD_LEN
        jr c,.width
        ld a,FIELD_LEN
.width:
        ld b,a
        call fld_desc               ; -> HL -> its type, after its name
        ld de,-FIELD_LEN
        add hl,de
        pop de
.copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .copy
.next:
        ld a,(fld)
        inc a
        ld (fld),a
        ld hl,info + DB_T_FIELDS
        cp (hl)
        jr c,.field
        ret

; every row
draw_rows:
        ld a,(nrows)
        or a
        jr nz,.rows
        ld a,T_EMPTY                ; none
        ld hl,0
        ld de,LIST_Y
        ld c,COLS
        call print_label
        ld a,1
        jr .blank
.rows:
        xor a
.row:
        push af
        call draw_row
        pop af
        inc a
        ld hl,nrows
        cp (hl)
        jr c,.row
.blank:
        cp N_ROWS                   ; the rest empty
        ret nc
        push af
        call blank_line
        call colours
        pop af
        push af
        call row_y
        ld hl,0
        ld bc,line
        call VOS_PRINT
        pop af
        inc a
        jr .blank

; A = row: its record, inverted if chosen
draw_row:
        ld (row),a
        add a,a
        ld l,a
        ld h,0
        ld de,rids
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld c,DB_GET
        ld hl,rbuf
        call vdb
        jp c,VOS_ERROR
        call row_line
        ld a,(row)                  ; chosen: inverted
        ld hl,sel
        cp (hl)
        jr nz,.plain
        ld a,BG
        ld c,INK
        call VOS_COLOURS
        jr .print
.plain:
        call colours
.print:
        ld a,(row)
        call row_y
        ld hl,0
        ld bc,line
        jp VOS_PRINT

; the record in rbuf in line, its fields in their columns
row_line:
        call blank_line
        xor a
        ld (fld),a
.field:
        ld hl,col_x
        call at_fld
        ld a,(hl)
        cp #FF
        jr z,.next
        ld e,a
        ld d,0
        ld hl,line
        add hl,de
        ex de,hl                    ; DE -> its column
        ld hl,col_w
        call at_fld
        ld b,(hl)
        call value                  ; -> HL -> it, as text, C long
        ld a,c
        cp b
        jr nc,.copy
        ld b,c
.copy:
        ld a,b
        or a
        jr z,.next
.char:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .char
.next:
        ld a,(fld)
        inc a
        ld (fld),a
        ld hl,info + DB_T_FIELDS
        cp (hl)
        jr c,.field
        ret

; A = row -> DE = its y
row_y:
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,a                     ; * 10
        add a,LIST_Y
        ld e,a
        ld d,0
        ret

; fld of the record in rbuf -> HL -> it as text, C = its length (a
; number: 5 digits in num_buf)
value:
        push de
        push bc
        ld hl,f_off
        call at_fld
        ld e,(hl)
        ld d,0
        ld hl,rbuf
        add hl,de
        push hl
        call fld_type
        pop hl
        cp DB_NUMBER
        jr nz,.text
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,num_buf
        call number
        ld hl,num_buf
        ld a,5
        jr .done
.text:
        push hl
        call fld_len
        pop hl
.done:
        pop bc
        ld c,a
        pop de
        ret

; what was said last (once), or the count of records
draw_said:
        ld a,(said)
        or a
        jr z,.count
        ld hl,said
        ld (hl),0
        ld hl,0
        ld de,SAID_Y
        ld c,COLS
        jp print_label
.count:
        ld c,DB_COUNT
        call vdb
        ret c
        ld de,num_buf
        call number
        ld a,T_COUNT
        ld hl,0
        ld de,SAID_Y
        ld c,COLS
        call print_label
        ld a,HEAD + VOS_BOLD
        ld c,BG
        call VOS_COLOURS
        ld hl,10 * 8
        ld de,SAID_Y
        ld bc,num_buf
        jp VOS_PRINT

; ---------------------------------------------------------------------
; the form: frec, a field a row
; ---------------------------------------------------------------------
draw_form:
        ld a,(fnew)                 ; "NEW RECORD" or "RECORD"
        or a
        ld a,T_REC
        jr z,.title
        ld a,T_NEW_REC
.title:
        ld hl,0
        ld de,HEAD_Y
        ld c,COLS
        call print_label
        xor a
.field:
        push af
        call draw_field
        pop af
        inc a
        ld hl,info + DB_T_FIELDS
        cp (hl)
        jr c,.field
        jp draw_said

; A = field: its name, its value (inverted if chosen)
draw_field:
        ld (fld),a
        call blank_line
        call fld_desc               ; its name
        ld bc,-FIELD_LEN
        add hl,bc
        ld de,line
        ld bc,FIELD_LEN
        ldir
        ld a,":"
        ld (line + FIELD_LEN),a
        call colours
        call field_y
        ld hl,0
        ld bc,line
        call VOS_PRINT
        call blank_line             ; its value
        ld hl,frec
        ld de,rbuf
        ld bc,REC_MAX
        ldir
        call value
        ld b,0
        ld de,line
        ld a,c
        or a
        jr z,.shown
        ldir
.shown:
        xor a                       ; as much as the row has
        ld (line + COLS - VALUE_X),a
        ld a,(fld)
        ld hl,fsel
        cp (hl)
        jr nz,.plain
        ld a,BG
        ld c,INK
        call VOS_COLOURS
        jr .print
.plain:
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
.print:
        call field_y
        ld hl,VALUE_X * 8
        ld bc,line
        jp VOS_PRINT

; fld -> DE = its row's y in the form
field_y:
        ld a,(fld)
        add a,a
        add a,a
        add a,a
        add a,a                     ; * 16
        add a,FORM_Y
        ld e,a
        ld d,0
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
        ld a,(db_ok)
        or a
        ret z
        ld a,(tables)
        or a
        ret z
        inc hl
        ld a,(hl)                   ; the key, its character
        inc hl
        ld c,(hl)
        ld b,a
        ld a,(mode)
        or a
        jp nz,form_key
        ; the list
        ld a,b
        cp VK_DOWN
        jr z,.down
        cp VK_UP
        jr z,.up
        cp VK_RIGHT
        jp z,.page_down
        cp VK_LEFT
        jp z,.page_up
        cp VK_RETURN
        jp z,form_open
        cp VK_ENTER
        jp z,form_open
        cp VK_TAB
        jp z,.table
        cp VK_DEL
        jr z,.del
        ld a,(info + DB_T_KEY)      ; a key field: typing finds
        or a
        ret z
        ld a,c
        cp " "
        ret c
        ld a,(typed_n)
        cp TYPED_MAX
        ret nc
        ld e,a
        ld d,0
        ld hl,typed
        add hl,de
        ld (hl),c
        inc a
        jr .typed
.del:
        ld a,(typed_n)
        or a
        ret z
        dec a
.typed:
        ld (typed_n),a
        xor a
        ld (sel),a
        call fill_find_or_first
        call draw_top
        jp draw_rows
.down:
        ld a,(sel)
        inc a
        ld hl,nrows
        cp (hl)
        jr nc,.scroll_down
        ld (sel),a
        dec a
        call draw_row
        ld a,(sel)
        jp draw_row
.scroll_down:
        call scroll_down
        ret z
        jp draw_rows
.up:
        ld a,(sel)
        or a
        jr z,.scroll_up
        dec a
        ld (sel),a
        inc a
        call draw_row
        ld a,(sel)
        jp draw_row
.scroll_up:
        ld a,(nrows)
        or a
        ret z
        ld a,1
        call scroll_up
        jp draw_rows
.page_down:
        ld b,N_ROWS
.more:
        push bc
        call scroll_down
        pop bc
        jr z,.paged
        djnz .more
.paged:
        jp draw_rows
.page_up:
        ld a,(nrows)
        or a
        ret z
        ld a,N_ROWS
        call scroll_up
        jp draw_rows
.table:
        ld a,(tbl)                  ; TAB: the next table
        inc a
        ld hl,tables
        cp (hl)
        jr c,.use
        xor a
.use:
        call use_table
        jp redraw

fill_find_or_first:
        ld a,(typed_n)
        or a
        jp z,fill_first
        jp fill_find

; the form: B = key
form_key:
        ld a,b
        cp VK_DOWN
        jr z,.down
        cp VK_UP
        jr z,.up
        cp VK_RETURN
        jr z,edit_field
        cp VK_ENTER
        jr z,edit_field
        ret
.down:
        ld a,(fsel)
        inc a
        ld hl,info + DB_T_FIELDS
        cp (hl)
        ret nc
        jr .choose
.up:
        ld a,(fsel)
        or a
        ret z
        dec a
.choose:
        ld hl,fsel
        ld b,(hl)
        ld (hl),a
        ld a,b
        call draw_field
        ld a,(fsel)
        jp draw_field

; RETURN in the form: the chosen field's new value asked
edit_field:
        ld a,(fsel)
        ld (fld),a
        ld hl,frec                  ; what it is now, as text
        ld de,rbuf
        ld bc,REC_MAX
        ldir
        call value                  ; -> HL, C
.lead:
        ld a,c                      ; without spaces before
        or a
        jr z,.copy
        ld a,(hl)
        cp " "
        jr nz,.copy
        inc hl
        dec c
        jr .lead
.copy:
        ld b,0
        ld de,input
        push bc
        ld a,c
        or a
        jr z,.copied
        ldir
.copied:
        pop bc
.trim:
        ld a,c                      ; or after
        or a
        jr z,.end
        ld hl,input - 1
        add hl,bc
        ld a,(hl)
        cp " "
        jr nz,.end
        dec c
        jr .trim
.end:
        ld hl,input
        add hl,bc
        ld (hl),0
        call fld_type
        cp DB_NUMBER
        ld c,5
        jr z,.ask
        call fld_len
        ld c,a
.ask:
        ld a,T_VALUE_T
        ld hl,input
        call VOS_INPUT
        ret c
        ld hl,f_off                 ; DE -> it in frec
        call at_fld
        ld e,(hl)
        ld d,0
        ld hl,frec
        add hl,de
        ex de,hl
        call fld_type
        cp DB_NUMBER
        jr z,.number
        call fld_len
        ld b,a
        ld hl,input
        call copy_pad
        jr .done
.number:
        push de
        ld hl,input
        call digits                 ; -> A = how many
        call parse
        pop hl
        jr c,.bad
        ld (hl),e
        inc hl
        ld (hl),d
.done:
        ld a,(fsel)
        jp draw_field
.bad:
        ld hl,dlg_not_num
        jp VOS_DIALOG

; RETURN in the list: the chosen record in the form
form_open:
        ld a,(nrows)
        or a
        ret z
        ld a,(sel)
        add a,a
        ld l,a
        ld h,0
        ld de,rids
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (frid),de
        ld c,DB_GET
        ld hl,frec
        call vdb
        jp c,VOS_ERROR
        xor a
        ld (fnew),a
        ; fall through
form_show:
        xor a
        ld (fsel),a
        ld a,1
        ld (mode),a
        jp redraw

; ADD A RECORD: an empty one in the form (spaces, numbers 0)
add_rec:
        call have_table
        ret c
        call rec_clear
        ld a,1
        ld (fnew),a
        jr form_show

; frec: its texts spaces, its numbers 0
rec_clear:
        ld hl,frec
        ld b,REC_MAX
.space:
        ld (hl)," "
        inc hl
        djnz .space
        xor a
        ld (fld),a
.field:
        call fld_type
        cp DB_NUMBER
        jr nz,.next
        ld hl,f_off
        call at_fld
        ld e,(hl)
        ld d,0
        ld hl,frec
        add hl,de
        ld (hl),0
        inc hl
        ld (hl),0
.next:
        ld a,(fld)
        inc a
        ld (fld),a
        ld hl,info + DB_T_FIELDS
        cp (hl)
        jr c,.field
        ret

; SAVE THE RECORD: DB_ADD or DB_PUT, then the list there
save_rec:
        ld a,(mode)
        or a
        ret z
        ld a,(fnew)
        or a
        ld c,DB_ADD
        jr nz,.call
        ld c,DB_PUT
.call:
        ld de,(frid)
        ld hl,frec
        call vdb
        jp c,VOS_ERROR
        ld a,(fnew)                 ; a new one: its rid
        or a
        jr z,.list
        ld (frid),de
.list:
        ld a,T_SAVED
        ld (said),a
        ; fall through
; the list, from the record of the form on
list_at:
        xor a
        ld (mode),a
        ld (sel),a
        ld (typed_n),a
        ld a,(info + DB_T_KEY)      ; with a key: from its key
        or a
        jr z,.first
        ld a,(info + DB_T_KEY)
        dec a
        ld (fld),a
        ld hl,f_off
        call at_fld
        ld e,(hl)
        ld d,0
        ld hl,frec
        add hl,de
        ld c,DB_FIND
        ld e,0
        call vdb
        call fill_from
        jp redraw
.first:
        call fill_first
        jp redraw

; DELETE THE RECORD: the chosen one (or the form's), when YES
del_rec:
        call have_table
        ret c
        ld a,(mode)
        or a
        jr nz,.form
        ld a,(nrows)
        or a
        ret z
        ld a,(sel)
        add a,a
        ld l,a
        ld h,0
        ld de,rids
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (frid),de
        jr .ask
.form:
        ld a,(fnew)
        or a
        ret nz
.ask:
        ld hl,dlg_del
        call VOS_DIALOG
        or a
        ret nz
        ld c,DB_DEL
        ld de,(frid)
        call vdb
        jp c,VOS_ERROR
        ld a,T_DELETED
        ld (said),a
        xor a
        ld (mode),a
        ld (sel),a
        call fill_find_or_first
        jp redraw

; carry: no table to work on
have_table:
        ld a,(db_ok)
        or a
        scf
        ret z
        ld a,(tables)
        or a
        scf
        ret z
        or a
        ret

; ---------------------------------------------------------------------
; the menu
; ---------------------------------------------------------------------
; A = command
command:
        cp CMD_NEW_DB
        jp z,new_db
        cp CMD_OPEN_DB
        jp z,open_db
        cp CMD_NEW_TABLE
        jp z,new_table
        cp CMD_ADD
        jp z,add_rec
        cp CMD_DELETE
        jp z,del_rec
        cp CMD_SAVE
        jp z,save_rec
        cp CMD_PRINT
        jp z,print_table
        cp CMD_LETTERS
        jp z,letters
        cp CMD_CSV
        jp z,import_csv
        cp CMD_LIST
        jr nz,.not_list
        ld a,(mode)
        or a
        ret z
        jp list_at
.not_list:
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,db_file               ; A: -> B: -> DISK
        call vos_next_drive
        xor a
        ld (db_ok),a
        ld c,DB_CLOSE
        call vdb
        jp redraw
.not_drive:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        ld c,DB_CLOSE
        call vdb
        jp VOS_EXIT

; PRINT: the table in use, the fields' names and then every record, as
; the list shows them; then a new page, and the list from its start
; again (the table's cursor moved)
print_table:
        call have_table
        ret c
        ld hl,db_file + 1
        ld bc,0                     ; a printout of this file: a heading
        ld e,c                      ; on each page (API 31)
        ld a,VX_PRINT
        call VOS_EXT
        call head_line
        call pr_line
        ret c
        ld c,DB_FIRST
        ld hl,rbuf
        call vdb
.rec:
        jr c,.end                   ; no more
        call row_line
        call pr_line
        jr c,.back
        ld c,DB_NEXT
        ld hl,rbuf
        call vdb
        jr .rec
.end:
        ld hl,form_feed
        ld bc,1
        call pr_send
.back:
        call fill_find_or_first
        xor a
        ld (sel),a
        jp redraw

; line, without the spaces at its end, and CR LF -> the printer; carry:
; it is not ready (said)
pr_line:
        ld hl,line + COLS
        ld b,COLS
.trim:
        dec hl
        ld a,(hl)
        cp " "
        jr nz,.end
        djnz .trim
        dec hl                      ; all spaces: an empty line
.end:
        inc hl
        ld (hl),13
        inc hl
        ld (hl),10
        inc hl
        ld de,line
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,line
pr_send:
        ld e,0
        ld a,VX_PRINT
        call VOS_EXT
        ret nc
        call VOS_ERROR
        scf
        ret

; ---------------------------------------------------------------------
; IMPORT CSV
; ---------------------------------------------------------------------
import_csv:
        call have_table
        ret c
        ld hl,ext_csv
        ld de,dlg_no_files
        ld a,T_PICK_CSV
        call pick_load
        ret c
        ld hl,0
        ld (cv_at),hl
        ld (cv_n),hl
        call csv_sep
        ld hl,0
        ld (cv_at),hl
        xor a
        ld (cv_col),a
        ld (cv_row),a
        call rec_clear
        call csv_records
        push af
        call fill_find_or_first     ; the list again, from its start
        xor a
        ld (sel),a
        ld a,T_IMPORTED
        ld (said),a
        call redraw
        pop af
        ret nc
        jp VOS_ERROR

; HL -> an extension, DE -> the dialog when the drive has none, A = the
; list's title: a file of db_file's drive with it, chosen, into the data
; bank (CSV_DATA, cv_len bytes, in the V-OS set) -> carry: not
pick_load:
        push af
        push de
        ld a,(db_file)
        or VOS_CAT_EXT
        call VOS_CATALOG
        pop de
        jr c,.error
        or a
        jr nz,.pick
        pop af
        ex de,hl
        call VOS_DIALOG
        scf
        ret
.error:
        pop de
        call VOS_ERROR
        scf
        ret
.pick:
        ld (cat),hl
        pop af
        call VOS_FILE_PICK
        ret c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cat)
        add hl,de
        ld de,name_csv
        ld bc,11
        ldir
        ld a,(db_file)
        or VOS_DATA
        ld hl,name_csv
        ld de,CSV_DATA
        call VOS_LOAD
        jr c,.load_error
        ld (cv_len),bc
        ld hl,CSV_DATA              ; UTF-8 into the V-OS set
        ld e,VOS_DATA
        ld a,VX_UTF8
        call VOS_EXT
        ld (cv_len),bc
        or a
        ret
.load_error:
        call VOS_ERROR
        scf
        ret

; ---------------------------------------------------------------------
; PRINT LETTERS
; ---------------------------------------------------------------------
letters:
        call have_table
        ret c
        ld hl,ext_txt
        ld de,dlg_no_txt
        ld a,T_PICK_TXT
        call pick_load
        ret c
        ld hl,0                     ; no headings on letters
        ld bc,0
        ld e,c
        ld a,VX_PRINT
        call VOS_EXT
        ld c,DB_FIRST
        ld hl,rbuf
        call vdb
.rec:
        jr c,.end                   ; no more
        call letter
        jr c,.back
        ld hl,form_feed             ; a page each
        ld bc,1
        call pr_send
        jr c,.back
        ld c,DB_NEXT
        ld hl,rbuf
        call vdb
        jr .rec
.end:
        ld a,T_PRINTED
        ld (said),a
.back:
        call fill_find_or_first
        xor a
        ld (sel),a
        jp redraw

; the letter (in the data bank) with rbuf's fields -> the printer, a
; piece of COLS at a time through line; carry: not ready
letter:
        ld hl,0
        ld (cv_at),hl
        xor a
        ld (lt_n),a
.byte:
        call csv_byte
        jp c,lt_flush
        cp 26                       ; the end of a text
        jp z,lt_flush
        cp "{"
        jr z,.field
        call lt_put
        jr nc,.byte
        ret
.field:
        ld de,lt_name               ; its name, up to "}"
        ld b,0
.name:
        call csv_byte
        jp c,lt_flush
        cp "}"
        jr z,.named
        ld c,a
        ld a,b
        cp FIELD_LEN
        jr nc,.name                 ; longer: the rest left out
        ld a,c
        ld (de),a
        inc de
        inc b
        jr .name
.named:
        ld a,b
        ld (lt_len),a
        call lt_field
        jr c,.literal
        call value                  ; HL -> it, C long: without the
.lead:                              ; spaces around it
        ld a,c
        or a
        jr z,.byte
        ld a,(hl)
        cp " "
        jr nz,.trail
        inc hl
        dec c
        jr .lead
.trail:
        ld a,c
        or a
        jr z,.byte
        push hl
        ld e,c
        ld d,0
        add hl,de
        dec hl
        ld a,(hl)
        pop hl
        cp " " + 1
        jr nc,.copy
        dec c
        jr .trail
.copy:
        ld a,(hl)
        call lt_put
        ret c
        inc hl
        dec c
        jr nz,.copy
        jr .byte
.literal:                           ; no such field: as it is
        ld a,"{"
        call lt_put
        ret c
        ld hl,lt_name
        ld a,(lt_len)
        ld c,a
        or a
        jr z,.close
.lit:
        ld a,(hl)
        call lt_put
        ret c
        inc hl
        dec c
        jr nz,.lit
.close:
        ld a,"}"
        call lt_put
        ret c
        jp .byte

; A -> line; full: to the printer. Carry: not ready. HL, BC, DE kept
lt_put:
        push hl
        push de
        ld hl,lt_n
        ld e,(hl)
        ld d,0
        inc (hl)
        ld hl,line
        add hl,de
        ld (hl),a
        pop de
        pop hl
        ld a,(lt_n)
        cp COLS
        ccf
        ret nc
        ; fall through
; what is in line -> the printer. Carry: not ready
lt_flush:
        push hl
        push de
        push bc
        ld a,(lt_n)
        ld c,a
        ld b,0
        or a
        ld hl,line
        call nz,pr_send
        ld a,0
        ld (lt_n),a
        pop bc
        pop de
        pop hl
        ret

; lt_name (lt_len letters) -> fld, the field of that name (without
; case); carry: none
lt_field:
        ld a,(info + DB_T_FIELDS)
        ld b,a
        xor a
.field:
        ld (fld),a
        push bc
        call fld_desc               ; HL -> its type, after its name
        ld de,-FIELD_LEN
        add hl,de
        ld de,lt_name
        ld a,(lt_len)
        ld c,a                      ; its letters left
        ld b,FIELD_LEN
.char:
        ld a," "                    ; past them: spaces (or 0s) there
        inc c
        dec c
        jr z,.have
        ld a,(de)
        inc de
        dec c
.have:
        call lt_upper
        ld (lt_ch),a
        ld a,(hl)
        or a
        jr nz,.not0
        ld a," "
.not0:
        call lt_upper
        push hl
        ld hl,lt_ch
        cp (hl)
        pop hl
        jr nz,.no
        inc hl
        djnz .char
        pop bc
        or a
        ret
.no:
        pop bc
        ld a,(fld)
        inc a
        djnz .field
        scf
        ret

lt_upper:
        cp "a"
        ret c
        cp "z" + 1
        ret nc
        sub " "
        ret

; the fields of the file, a record a line (DB_ADD) -> carry, A = error
csv_records:
.field:
        ld de,input
        ld b,0                      ; its characters
        ld c,0                      ; 1: inside quotes
.byte:
        call csv_byte
        jr c,.last
        cp 26
        jr z,.last
        cp 13
        jr z,.byte
        cp 34
        jr nz,.not_quote
        ld a,c
        or a
        jr nz,.quoted
        ld a,b
        or a
        jr nz,.char_q
        inc c
        jr .byte
.quoted:
        call csv_byte               ; "" a quote, else they end
        jr c,.last
        cp 34
        jr z,.char_q
        ld c,0
        jr .plain
.char_q:
        ld a,34
        jr .char
.not_quote:
        bit 0,c
        jr nz,.char
.plain:
        cp 10
        jr z,.row_end
        ld hl,cv_sep
        cp (hl)
        jr z,.field_end
.char:
        ld l,a
        ld a,b
        cp TEXT_MAX
        jr nc,.byte
        ld a,l
        ld (de),a
        inc de
        inc b
        jr .byte
.field_end:
        call csv_field
        ld hl,cv_col
        inc (hl)
        jr .field
.row_end:
        call csv_field
        call csv_add
        ret c
        jr .field
.last:
        ld a,b
        or a
        jr nz,.one
        ld a,(cv_col)               ; nothing on the last line
        or a
        ret z
.one:
        call csv_field
        ; fall through
; the record of the line, unless it is the heads -> carry, A = error
csv_add:
        xor a
        ld (cv_col),a
        ld hl,cv_row
        ld a,(hl)
        inc (hl)
        or a
        jr nz,.add
        ld a,(cv_head)
        or a
        jr nz,.next
.add:
        ld c,DB_ADD
        ld hl,frec
        call vdb
        ret c
.next:
        call rec_clear
        or a
        ret

; input (B characters): the field cv_col of frec; on the first line,
; the first field says whether it is the heads (cv_head)
csv_field:
        xor a
        ld (de),a
        ld a,(cv_col)
        or a
        jr nz,.not_first
        ld a,(cv_row)
        or a
        jr nz,.not_first
        call csv_heads
.not_first:
        ld a,(cv_col)
        ld hl,info + DB_T_FIELDS
        cp (hl)
        ret nc                      ; more than the fields: left out
        ld (fld),a
        ld hl,f_off
        call at_fld
        ld e,(hl)
        ld d,0
        ld hl,frec
        add hl,de
        push hl
        call fld_type
        pop de
        cp DB_NUMBER
        jr z,.number
        push de
        call fld_len
        pop de
        ld c,a                      ; up to its length (spaces after)
        ld hl,input
.text:
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        dec c
        jr nz,.text
        ret
.number:
        push de
        ld hl,input                 ; its digits only
        ld de,num_buf
        ld b,0
.digit:
        ld a,(hl)
        inc hl
        or a
        jr z,.digits
        cp "0"
        jr c,.digit
        cp "9" + 1
        jr nc,.digit
        ld c,a
        ld a,b
        cp 5
        jr nc,.digit
        ld a,c
        ld (de),a
        inc de
        inc b
        jr .digit
.digits:
        ld hl,num_buf
        ld a,b
        call parse                  ; -> DE (65535 if too big)
        jr nc,.got
        ld a,b                      ; none: 0
        or a
        jr nz,.got
        ld de,0
.got:
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; input: the first field's name? -> cv_head
csv_heads:
        xor a
        ld (cv_head),a
        ld (fld),a
        call fld_desc               ; -> HL -> its type, its name before
        ld de,-FIELD_LEN
        add hl,de
        ld de,input
        ld b,FIELD_LEN
.char:
        ld a,(hl)
        cp " "
        jr z,.end
        ld c,a
        ld a,(de)
        or a
        ret z
        call upper
        cp c
        ret nz
        inc hl
        inc de
        djnz .char
.end:
        ld a,1
        ld (cv_head),a
        ret

; A -> a capital, if a small Latin letter
upper:
        cp "a"
        ret c
        cp "z" + 1
        ret nc
        sub 32
        ret

; -> A = the next byte of the file (data bank); carry at its end.
; Keeps BC, DE
csv_byte:
        push bc
        push de
        ld hl,(cv_at)
        ld de,(cv_len)
        or a
        sbc hl,de
        jr nc,.end
        ld hl,(cv_at)
        ld de,CSV_DATA
        add hl,de
        ld de,cv_one
        ld bc,1
        call VOS_BANK_GET
        ld hl,(cv_at)
        inc hl
        ld (cv_at),hl
        ld a,(cv_one)
        or a
        jr .back
.end:
        scf
.back:
        pop de
        pop bc
        ret

; cv_sep: ";" if the first line has one before any ",", else ","
csv_sep:
        ld a,","
        ld (cv_sep),a
.byte:
        call csv_byte
        ret c
        cp 10
        ret z
        cp ","
        ret z
        cp ";"
        jr nz,.byte
        ld (cv_sep),a
        ret

; NEW DATABASE: its name, DB_CREATE, then its first table
new_db:
        ld a,T_DB_NAME_T
        ld c,8
        call ask_name               ; -> name_buf, 8 characters
        ret c
        ld hl,name_buf
        ld de,db_file + 1
        ld bc,8
        ldir
        ld hl,ext_vdb
        ld bc,3
        ldir
        xor a
        ld (db_ok),a
        ld (tables),a
        ld (mode),a
        ld c,DB_CREATE
        ld de,db_file
        call vdb
        jp c,VOS_ERROR
        ld a,1
        ld (db_ok),a
        call redraw
        jr new_table

; OPEN A DATABASE: the .VDB files of the drive, one chosen
open_db:
        ld a,(db_file)
        or VOS_CAT_EXT
        ld hl,ext_vdb
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
        ld de,db_file + 1
        ld bc,11
        ldir
        call open_file
        jp redraw

; NEW TABLE: its name, its fields, its key
new_table:
        ld a,(db_ok)
        or a
        ret z
        ld a,T_TABLE_T
        ld c,8
        call ask_name
        ret c
        ld hl,name_buf
        ld de,tdef
        ld bc,8
        ldir
        xor a
        ld (tdef + 8),a             ; fields
        ld (tdef + 9),a             ; key
        ld (rlen),a
.field:
        ld a,(tdef + 8)
        cp 10
        jp z,.fields
        ld a,T_FIELD_T
        ld c,8
        call ask_name
        jp c,.fields                ; none: no more
        ld a,(tdef + 8)             ; DE -> its place
        ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld de,tdef + 10
        add hl,de
        ex de,hl
        ld hl,name_buf
        ld bc,8
        ldir
        push de
        ld hl,dlg_type              ; TEXT, NUMBER, CANCEL
        call VOS_DIALOG
        pop de
        cp 2
        ret z
        or a
        jr z,.text
        ld a,DB_NUMBER
        ld (de),a
        inc de
        ld a,2
        ld (de),a
        jr .add
.text:
        push de
        ld hl,input
        ld (hl),0
        ld a,T_LEN_T
        ld c,2
        call VOS_INPUT
        pop de
        ret c
        push de
        ld hl,input
        call digits
        call parse
        pop hl
        jr c,.text_bad
        ld a,d
        or a
        jr nz,.text_bad
        ld a,e
        or a
        jr z,.text_bad
        cp TEXT_MAX + 1
        jr nc,.text_bad
        ld (hl),DB_ALPHA
        inc hl
        ld (hl),a
        ex de,hl
        jr .add
.text_bad:
        ex de,hl
        push de
        ld hl,dlg_len
        call VOS_DIALOG
        pop de
        jr .text
.add:
        ld a,(de)                   ; the record's length so far
        ld hl,rlen
        add a,(hl)
        jr c,.too_long
        ld (hl),a
        ld hl,tdef + 8
        inc (hl)
        jp .field
.too_long:
        ld a,DB_ERR_DEF
        jp VOS_ERROR
.fields:
        ld a,(tdef + 8)
        or a
        ret z
        ld hl,dlg_key               ; the first field its key?
        call VOS_DIALOG
        or a
        jr nz,.table
        inc a
        ld (tdef + 9),a
.table:
        ld c,DB_TABLE
        ld de,tdef
        call vdb
        jp c,VOS_ERROR
        call use_table
        jp redraw

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
; HL -> text, 0; DE -> room for B characters: it, then spaces
copy_pad:
        ld a,(hl)
        or a
        jr z,.space
        ld (de),a
        inc hl
        inc de
        djnz copy_pad
        ret
.space:
        ld a," "
        ld (de),a
        inc de
        djnz .space
        ret

; HL -> text, 0 -> A = its length, HL kept
digits:
        push hl
        ld b,0
.len:
        ld a,(hl)
        or a
        jr z,.done
        inc hl
        inc b
        jr .len
.done:
        pop hl
        ld a,b
        ret

; HL -> A characters -> DE = the number they say; carry: not a number
; from 0 to 65535 (DE = 65535 if too big)
parse:
        ld de,0
        or a
        scf
        ret z
        ld b,a
.digit:
        ld a,(hl)
        inc hl
        sub "0"
        cp 10
        ccf
        ret c
        push hl
        ld h,d                      ; DE * 10 + A
        ld l,e
        add hl,hl
        jr c,.big
        add hl,hl
        jr c,.big
        add hl,de
        jr c,.big
        add hl,hl
        jr c,.big
        ld e,a
        ld d,0
        add hl,de
        jr c,.big
        ex de,hl
        pop hl
        djnz .digit
        or a
        ret
.big:
        pop hl
        ld de,65535
        scf
        ret

; HL = number -> 5 digits at DE, leading zeros as spaces, then 0
number:
        ld bc,-10000
        call .digit
        ld bc,-1000
        call .digit
        ld bc,-100
        call .digit
        ld c,-10
        call .digit
        ld c,b
        call .digit
        xor a
        ld (de),a
        dec de                      ; leading zeros: spaces
        dec de
        dec de
        dec de
        dec de
        ld b,4
.zero:
        ld a,(de)
        cp "0"
        ret nz
        ld a," "
        ld (de),a
        inc de
        djnz .zero
        ret
.digit:
        ld a,"0" - 1
.more:
        inc a
        add hl,bc
        jr c,.more
        sbc hl,bc
        ld (de),a
        inc de
        ret

; line: 48 spaces, 0
blank_line:
        ld hl,line
        ld b,COLS
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

; A = text, HL = x, DE = y, C = width: it, then spaces to the width
print_label:
        push hl
        push de
        push bc
        call VOS_MSG
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
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 16
                db T_NEW_DB, CMD_NEW_DB, "N", 0
                db T_OPEN_DB, CMD_OPEN_DB, "O", 0
                db T_NEW_TABLE, CMD_NEW_TABLE, "T", 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_ADD, CMD_ADD, "A", 0
                db T_DELETE, CMD_DELETE, "D", 0
                db T_SAVE, CMD_SAVE, "S", 0
                db T_LIST, CMD_LIST, "B", 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_DRIVE, CMD_DRIVE, "W", 0
                db T_PRINT, CMD_PRINT, "P", 0
                db T_LETTERS, CMD_LETTERS, "L", 0
                db T_CSV, CMD_CSV, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_no_txt:     db T_MENU, T_NO_TXT, 1, VM_OK
dlg_type:       db T_TYPE_T, T_TYPE_TEXT, 3, T_TEXT, T_NUMBER, T_CANCEL
dlg_key:        db T_TABLE_T, T_KEY_TEXT, 2, VM_YES, VM_NO
dlg_del:        db T_MENU, T_DEL_Q, 2, VM_YES, VM_NO
dlg_not_num:    db T_MENU, T_NOT_NUM, 1, VM_OK
dlg_len:        db T_MENU, T_LEN_T, 1, VM_OK
dlg_no_files:   db T_MENU, T_NO_FILES, 1, VM_OK
ext_vdb:        db "VDB"
ext_csv:        db "CSV"
ext_txt:        db "TXT"
lt_name:        ds FIELD_LEN        ; PRINT LETTERS: {NAME}
lt_len:         db 0
lt_ch:          db 0
lt_n:           db 0                ; the bytes in line
name_csv:       ds 11
cv_len:         dw 0                ; IMPORT CSV: its bytes, the next one,
cv_at:          dw 0
cv_n:           dw 0
cv_one:         db 0
cv_sep:         db ","              ; the separator,
cv_col:         db 0                ; the field and the line,
cv_row:         db 0
cv_head:        db 0                ; 1: the first line is the heads
form_feed:      db 12

        include "api/vos_drive.inc"
        include "app_texts.asm"     ; texts, from texts.txt

db_ok:          db 0                ; db_file open
db_file:        db 0, "NONAME  VDB"
tables:         db 0                ; in it
tbl:            db 0                ; the one in use
mode:           db 0                ; 0 the list, 1 the form
said:           db 0                ; a text for the last line, once
info:           ds INFO_SIZE        ; DB_INFO of tbl
f_off:          ds 10               ; each field's offset in a record
col_x:          ds 10               ; its column in the list (#FF: none)
col_w:          ds 10               ; and its width
fld:            db 0
row:            db 0
nrows:          db 0
sel:            db 0
rids:           ds N_ROWS * 2
cur_rid:        dw 0
typed_n:        db 0
typed:          ds TEXT_MAX
key_buf:        ds TEXT_MAX
fnew:           db 0                ; the form: a new record
fsel:           db 0
frid:           dw 0
cat:            dw 0
rlen:           db 0
name_buf:       ds 8
num_buf:        ds 6
input:          ds TEXT_MAX + 2
line:           ds COLS + 2         ; (and CR LF to print)
lbuf:           ds COLS + 1
tdef:           ds 10 + 10 * 10
frec:           ds REC_MAX
rbuf:           ds REC_MAX
