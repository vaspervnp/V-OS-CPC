; =====================================================================
; streets.asm - STREETS, a street index on a V-OS database (made with
; the SDK): an example of VOS_EXT, VX_DB (API 22).
;
; Mode 1. Its streets are in STREETS.VDB on its own drive: a table of
; records of name (24 characters, the key: DB_ALPHA, so in any case and
; with or without accents), area (16) and post code (a number). The
; first time it makes the file, with some streets of Athens. Typing
; finds: the streets whose names start with what was typed (DB_FIND
; with that many bytes, then DB_NEXT), DEL takes a letter back.
;   STREETS menu: ADD A STREET ^A, DELETE THE FIRST ^D, ABOUT, BACK ^Q
;   make app NAME=streets     build/STREETS.BIN, build/streets.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
HEAD            equ 3
ROWS            equ 18              ; streets on the screen
FIND_Y          equ 14
HEAD_Y          equ 32
LIST_Y          equ 46
COUNT_Y         equ 238
HINT_Y          equ 249
AREA_COL        equ 25              ; columns of 8 pixels
ZIP_COL         equ 42
NAME_LEN        equ 24              ; the record: name, area, post code
AREA_LEN        equ 16
REC_LEN         equ NAME_LEN + AREA_LEN + 2

CMD_ADD         equ VC_APP + 1      ; menu items: commands
CMD_DELETE      equ VC_APP + 2
CMD_ABOUT       equ VC_APP + 3
CMD_BACK        equ VC_APP + 4

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start; 2: back. The database is opened each time (if
; another program opened one meanwhile, this one is closed).
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
        ld a,(VOS_SELF)             ; on its own drive
        ld (db_file),a
        xor a
        ld (typed_n),a
.back:
        call open_db
        jp redraw

; STREETS.VDB open, table 0 in use; made the first time -> db_ok
open_db:
        xor a
        ld (db_ok),a
        ld c,DB_OPEN
        ld de,db_file
        call vdb
        jr nc,.open
        cp DB_ERR_NO_FILE
        jp nz,VOS_ERROR
        call make_db
        jp c,VOS_ERROR
        ld a,T_NEW                  ; said in the last line
        ld (said),a
        xor a
.open:
        or a                        ; in another alphabet: say so
        ld a,DB_ERR_ALPHABET
        call nz,VOS_ERROR
        ld c,DB_USE
        ld e,0
        call vdb
        jp c,VOS_ERROR
        ld a,1
        ld (db_ok),a
        ret

; a new STREETS.VDB: its table, then the streets of samples
make_db:
        ld c,DB_CREATE
        ld de,db_file
        call vdb
        ret c
        ld c,DB_TABLE
        ld de,table
        call vdb
        ret c
        ld hl,samples
.street:
        ld a,(hl)
        or a
        ret z
        ld de,rec                   ; name, area: to their lengths
        ld b,NAME_LEN
        call copy_pad
        ld b,AREA_LEN
        call copy_pad
        ld a,(hl)                   ; the post code
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        inc hl
        push hl
        ld c,DB_ADD
        ld hl,rec
        call vdb
        pop hl
        ret c
        jr .street

; HL -> text, 0; DE -> room for B characters: it, then spaces, HL and
; DE after them
copy_pad:
        ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz copy_pad
.end:
        ld a,(hl)                   ; (longer: the rest skipped)
        inc hl
        or a
        jr nz,.end
        ret
.pad:
        inc hl
.space:
        ld a," "
        ld (de),a
        inc de
        djnz .space
        ret

; C = DB_* call, DE, HL as it wants
vdb:
        ld a,VX_DB
        jp VOS_EXT

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
        ld c,48
        call print_label
        ld a,HEAD + VOS_UNDERLINE   ; the columns
        ld c,BG
        call VOS_COLOURS
        ld a,T_STREET
        ld hl,0
        call col_head
        ld a,T_AREA
        ld hl,AREA_COL * 8
        call col_head
        ld a,T_ZIP
        ld hl,(ZIP_COL - 4) * 8
        call col_head
        ; fall through
; what was typed, the streets that start so, how many there are
show:
        call show_typed
        call show_list
        jp show_count

; A = text, HL = x: a column's head
col_head:
        push hl
        call VOS_MSG
        ld b,h
        ld c,l
        pop hl
        ld de,HEAD_Y
        jp VOS_PRINT

show_typed:
        ld hl,line                  ; "FIND: " what was typed, "_"
        ld a,(typed_n)
        ld b,a
        ld de,typed
.char:
        ld a,b
        or a
        jr z,.cursor
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
        dec b
        jr .char
.cursor:
        ld (hl),"_"
        inc hl
        ld b,NAME_LEN
.pad:
        ld (hl)," "
        inc hl
        djnz .pad
        ld (hl),0
        ld a,T_FIND
        ld hl,0
        ld de,FIND_Y
        ld c,8
        call print_label
        ld a,HEAD + VOS_BOLD
        ld c,BG
        call VOS_COLOURS
        ld hl,64
        ld de,FIND_Y
        ld bc,line
        jp VOS_PRINT

; the streets from the first that starts with what was typed
show_list:
        xor a
        ld (row),a
        ld (first_ok),a
        ld a,(db_ok)
        or a
        jr z,.blank
        ld hl,rec                   ; FIND, or with nothing typed FIRST
        ld a,(typed_n)
        or a
        ld c,DB_FIRST
        jr z,.call
        ld de,rec                   ; the key: what was typed
        ld hl,typed
        ld c,a
        ld b,0
        ldir
        ld e,a
        ld c,DB_FIND
        ld hl,rec
.call:
        call vdb
.row:
        jr c,.blank                 ; no more
        ld (rid),de
        call starts                 ; one that starts otherwise: none
        jr nz,.blank
        ld a,(row)
        or a
        jr nz,.shown
        ld (first_rid),de           ; (DELETE THE FIRST)
        ld a,1
        ld (first_ok),a
.shown:
        call show_rec
        ld a,(row)
        inc a
        ld (row),a
        cp ROWS
        ret z
        ld c,DB_NEXT
        ld hl,rec
        call vdb
        jr .row
.blank:
        ld a,(row)                  ; the rest empty
        cp ROWS
        ret z
        ld hl,line
        ld b,48
.space:
        ld (hl)," "
        inc hl
        djnz .space
        ld (hl),0
        ld a,(row)                  ; nothing found: say so
        or a
        jr nz,.empty
        ld a,(typed_n)
        or a
        jr z,.empty
        ld a,T_NONE
        call VOS_MSG
        ld de,line
.none:
        ld a,(hl)
        or a
        jr z,.empty
        ld (de),a
        inc hl
        inc de
        jr .none
.empty:
        call colours
        call row_print
        ld a,(row)
        inc a
        ld (row),a
        jr .blank

; -> Z: rec's name starts with what was typed
starts:
        ld a,(typed_n)
        or a
        ret z
        ld b,a
        ld hl,rec
        ld de,typed
.char:
        ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .char
        ret

; rec in the row: name, area, post code
show_rec:
        ld hl,line
        ld b,48
.space:
        ld (hl)," "
        inc hl
        djnz .space
        ld (hl),0
        ld hl,rec
        ld de,line
        ld bc,NAME_LEN
        ldir
        ld de,line + AREA_COL
        ld bc,AREA_LEN
        ldir
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,line + ZIP_COL
        call number
        call colours
        ; fall through
row_print:
        ld a,(row)                  ; y = LIST_Y + 10 * row
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,a
        add a,LIST_Y
        ld e,a
        ld d,0
        ld hl,0
        ld bc,line
        jp VOS_PRINT

; "STREETS IN ALL: n", or what was said (a new index)
show_count:
        ld hl,line
        ld b,24
.space:
        ld (hl)," "
        inc hl
        djnz .space
        ld (hl),0
        ld a,(said)
        or a
        jr z,.count
        ld hl,said                  ; (once)
        ld (hl),0
        ld hl,0
        ld de,COUNT_Y
        ld c,48
        jp print_label
.count:
        ld a,(db_ok)
        or a
        ret z
        ld c,DB_COUNT
        call vdb
        ret c
        ld de,line
        call number
        ld a,T_COUNT
        ld hl,0
        ld de,COUNT_Y
        ld c,16
        call print_label
        ld a,HEAD + VOS_BOLD
        ld c,BG
        call VOS_COLOURS
        ld hl,16 * 8
        ld de,COUNT_Y
        ld bc,line
        jp VOS_PRINT

; HL = number -> 5 digits at DE, leading zeros as spaces
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
        cp VK_DEL
        jr z,.del
        ld a,c
        cp " "
        ret c
        cp "a"                      ; capitals
        jr c,.cap
        cp "z" + 1
        jr nc,.cap
        sub 32
.cap:
        ld c,a
        ld a,(typed_n)
        cp NAME_LEN
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
        call show_typed
        jp show_list

; A = command (the menu)
command:
        cp CMD_ADD
        jp z,add_street
        cp CMD_DELETE
        jp z,del_street
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

; ADD A STREET: its name, area and post code asked, then it is shown
add_street:
        ld a,(db_ok)
        or a
        ret z
        ld a,T_NAME_T
        ld c,NAME_LEN
        call ask
        ret c
        ld hl,input
        ld de,rec
        ld b,NAME_LEN
        call copy_pad
        ld a,T_AREA_T
        ld c,AREA_LEN
        call ask
        ret c
        ld hl,input
        ld de,rec + NAME_LEN
        ld b,AREA_LEN
        call copy_pad
        ld a,T_ZIP_T
        ld c,5
        call ask
        ret c
        ld hl,input                 ; its digits, a number
        ld de,0
.digit:
        ld a,(hl)
        inc hl
        or a
        jr z,.zip
        sub "0"
        cp 10
        jr nc,.digit
        push hl
        ld h,d                      ; DE * 10 + A
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        jr .digit
.zip:
        ld (rec + NAME_LEN + AREA_LEN),de
        ld c,DB_ADD
        ld hl,rec
        call vdb
        jp c,VOS_ERROR
        ld hl,rec                   ; what is typed: its name
        ld de,typed
        ld bc,NAME_LEN
        ldir
        ld b,NAME_LEN               ; without the spaces at its end
        ld hl,typed + NAME_LEN - 1
.trim:
        ld a,(hl)
        cp " "
        jr nz,.trimmed
        dec hl
        djnz .trim
.trimmed:
        ld a,b
        ld (typed_n),a
        jp show

; A = title, C = length -> input, capitals; carry: none
ask:
        ld hl,input
        ld (hl),0
        call VOS_INPUT
        ret c
        ld hl,input
        ld a,(hl)
        or a
        scf
        ret z
.cap:
        ld a,(hl)
        or a
        ret z
        cp "a"
        jr c,.next
        cp "z" + 1
        jr nc,.next
        sub 32
        ld (hl),a
.next:
        inc hl
        jr .cap

; DELETE THE FIRST: the first street on the screen
del_street:
        ld a,(first_ok)
        or a
        ret z
        ld c,DB_DEL
        ld de,(first_rid)
        call vdb
        jp c,VOS_ERROR
        jp show

; ---- data -----------------------------------------------------------
; black, white, blue, bright yellow (mode 1: pens 0..3), the border
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 5
                db T_ADD, CMD_ADD, "A", 0
                db T_DELETE, CMD_DELETE, "D", 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK

db_file:        db 0, "STREETS VDB"
; the table: name, fields, the key field, then each field
table:          db "STREETS ", 3, 1
                db "NAME    ", DB_ALPHA, NAME_LEN
                db "AREA    ", DB_TEXT, AREA_LEN
                db "ZIP     ", DB_NUMBER, 2
; some streets of Athens: name, area, post code (examples)
samples:        db "ERMOU", 0, "SYNTAGMA", 0 : dw 10563
                db "STADIOU", 0, "SYNTAGMA", 0 : dw 10564
                db "PANEPISTIMIOU", 0, "SYNTAGMA", 0 : dw 10564
                db "AKADIMIAS", 0, "KOLONAKI", 0 : dw 10671
                db "SOLONOS", 0, "KOLONAKI", 0 : dw 10672
                db "SKOUFA", 0, "KOLONAKI", 0 : dw 10673
                db "VASILISSIS SOFIAS", 0, "KOLONAKI", 0 : dw 10674
                db "IPPOKRATOUS", 0, "EXARCHIA", 0 : dw 10680
                db "PATISION", 0, "KYPSELI", 0 : dw 11257
                db "AGIOU NIKOLAOU", 0, "KYPSELI", 0 : dw 11362
                db "AGIOU NIKOLAOU", 0, "PLAKA", 0 : dw 10556
                db "ADRIANOU", 0, "PLAKA", 0 : dw 10556
                db "MITROPOLEOS", 0, "PLAKA", 0 : dw 10557
                db "AIOLOU", 0, "MONASTIRAKI", 0 : dw 10551
                db "ATHINAS", 0, "MONASTIRAKI", 0 : dw 10551
                db "PIRAEOS", 0, "PSYRRI", 0 : dw 10552
                db "AGIOU KONSTANTINOU", 0, "OMONIA", 0 : dw 10437
                db "MARNI", 0, "OMONIA", 0 : dw 10433
                db "KOLOKOTRONI", 0, "SYNTAGMA", 0 : dw 10561
                db "VOULIS", 0, "SYNTAGMA", 0 : dw 10562
                db "APOSTOLOU PAVLOU", 0, "THISIO", 0 : dw 11851
                db "DIONYSIOU AREOPAGITOU", 0, "ACROPOLI", 0 : dw 11742
                db "SYGROU", 0, "KOUKAKI", 0 : dw 11743
                db "PATRIARCHOU IOAKEIM", 0, "KOLONAKI", 0 : dw 10675
                db 0

        include "app_texts.asm"     ; texts, from texts.txt

db_ok:          db 0                ; the database open
said:           db 0                ; a text for the last line, once
typed_n:        db 0
typed:          ds NAME_LEN
row:            db 0
rid:            dw 0
first_rid:      dw 0
first_ok:       db 0
rec:            ds REC_LEN
input:          ds NAME_LEN + 2
line:           ds 49
lbuf:          ds 49
