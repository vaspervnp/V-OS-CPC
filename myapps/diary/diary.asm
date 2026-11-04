; =====================================================================
; diary.asm - DIARY, days and what is on them (made with the SDK)
;
; Mode 1. A month on the left, a week a row from Monday, the chosen
; day inverted and the days with notes marked "*"; under it the chosen
; day's notes (up to NOTES_MAX). They are kept in DIARY.VDB on the
; drive it was started from (OTHER DRIVE ^W): a table DAYS of DATE
; ("2026-11-04", its key) and NOTE (40 characters), made the first
; time, through DB.SYS (VX_DB, API 22); opened for each change of day
; and closed again, so other programs may use a database meanwhile.
;   the month   ARROWS a day, a week; < > a month; TAB the notes
;   the notes   UP DOWN choose one, RETURN changes it, DEL deletes it,
;               TAB the month
;   DIARY menu: ADD A NOTE ^A, CHANGE THE NOTE, DELETE THE NOTE ^D,
;   TODAY ^T (the M4 board's date, C_TIME through VX_M4), PREVIOUS
;   MONTH, NEXT MONTH, OTHER DRIVE ^W, ABOUT, BACK ^Q
; It starts on today with an M4 board, else on the last day with a
; note, else on 2026-01-01.
;   make app NAME=diary       build/DIARY.BIN, on build/apps.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
HEAD            equ 3
TOP_Y           equ 14
WEEK_Y          equ 30
CAL_X           equ 8
CAL_Y           equ 42
CAL_STEP        equ 12
NOTES_Y         equ 120
NOTE_X          equ 16
NOTE_STEP       equ 10
NOTES_MAX       equ 10
HINT_Y          equ 249
DRIVE_X         equ 34 * 8
DATE_LEN        equ 10              ; a record: "2026-11-04", then
NOTE_LEN        equ 40              ; the note, padded with spaces
REC_LEN         equ DATE_LEN + NOTE_LEN
C_TIME          equ #4324           ; the M4 board: "hh:mm:ss yyyy-mm-dd"

CMD_ADD         equ VC_APP + 1      ; menu items: commands
CMD_CHANGE      equ VC_APP + 2
CMD_DELETE      equ VC_APP + 3
CMD_TODAY       equ VC_APP + 4
CMD_PREV_M      equ VC_APP + 5
CMD_NEXT_M      equ VC_APP + 6
CMD_DRIVE       equ VC_APP + 7
CMD_ABOUT       equ VC_APP + 8
CMD_BACK        equ VC_APP + 9

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start, on its own drive; 2: back, as it was
init:
        push af                     ; in a window, if there are windows
        ld a,VX_WINDOW              ; (first, each time): the part of
        ld hl,wsize                 ; the screen it uses
        call VOS_EXT
        sbc a,a                     ; 0: a window, #FF: the screen
        inc a
        ld (win),a
        pop af
        push af
        ld hl,texts
        call VOS_TEXTS
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        pop af
        cp 2
        jr z,reload
        ld a,(VOS_SELF)
        ld (drive),a
        xor a
        ld (focus),a
        ld (sel),a
        call today                  ; the M4's date, or the last day
        call c,last_day             ; with a note
        ; fall through

; the month's marks and the day's notes read again, all drawn
reload:
        xor a
        ld (lm_month),a
reload_day:
        call load
        ; fall through

redraw:
        ld a,(win)                  ; in a window: the Desktop's mode
        or a                        ; and colours
        jr nz,.colours
        ld a,1
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
.colours:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        call draw_top
        call draw_month
        call draw_notes
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld a,T_HINT
        ld hl,0
        ld de,HINT_Y
        ; fall through
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

; ---------------------------------------------------------------------
; the date: year, month, day
; ---------------------------------------------------------------------
; -> the M4 board's date; carry: none (no board, or not its answer)
today:
        ld hl,time_cmd
        ld de,resp
        ld bc,3 + 20
        ld a,VX_M4
        call VOS_EXT
        ret c
        ld a,(resp)
        cp 3 + 19
        ret c
        ld hl,resp + 3 + 9          ; "yyyy-mm-dd" after the time
        ; fall through
; HL -> "yyyy-mm-dd" -> year, month, day (a day past the month's end:
; its last); carry: not a date, nothing changed
parse_date:
        ld b,4
        call digits
        ret c
        ld (p_year),de
        inc hl
        ld b,2
        call digits
        ret c
        ld a,e
        dec a
        cp 12
        ccf
        ret c
        inc a
        ld (p_month),a
        inc hl
        ld b,2
        call digits
        ret c
        ld a,e
        or a
        scf
        ret z
        ld (day),a
        ld a,(p_month)
        ld (month),a
        ld hl,(p_year)
        ld (year),hl
        jp clamp_day

; B digits at HL -> DE = their number, HL after them; carry: not digits
digits:
        ld de,0
.digit:
        ld a,(hl)
        sub "0"
        ret c
        cp 10
        ccf
        ret c
        push hl
        ld h,d
        ld l,e
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de                   ; * 10
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        djnz .digit
        or a
        ret

; -> the date of the last note in the diary, if there is one
last_day:
        call vdb_open
        ret c
        ld hl,rbuf
        ld c,DB_LAST
        call vdb
        ld hl,rbuf
        call nc,parse_date
        jp vdb_close

; the day no later than the month's last
clamp_day:
        call days_in
        ld hl,day
        cp (hl)
        jr nc,.ok
        ld (hl),a
.ok:
        or a
        ret

; A = days on (-7..7): the day before or after, in another month too
move_day:
        ld hl,day
        add a,(hl)
        jr z,.before
        bit 7,a
        jr nz,.before
        ld (hl),a
        ld b,a
        call days_in
        cp b
        jr nc,.moved
        ld c,a                      ; past the end: into the next month
        ld a,b
        sub c
        ld (day),a
        call month_up
        jr .moved
.before:
        push af                     ; before the 1st: the last month's
        call month_down
        call days_in
        pop bc
        add a,b
        ld (day),a
.moved:
        jp reload_day

prev_month:
        call month_down
        jr month_moved
next_month:
        call month_up
month_moved:
        call clamp_day
        jp reload_day

month_up:
        ld hl,month
        inc (hl)
        ld a,(hl)
        cp 13
        ret c
        ld (hl),1
        ld hl,(year)
        inc hl
        ld (year),hl
        ret

month_down:
        ld hl,month
        dec (hl)
        ret nz
        ld (hl),12
        ld hl,(year)
        dec hl
        ld (year),hl
        ret

; -> A = the days of month (in year)
days_in:
        ld a,(month)
        cp 2
        jr z,.feb
        ld e,a
        ld d,0
        ld hl,month_days - 1
        add hl,de
        ld a,(hl)
        ret
.feb:
        ld a,(year)                 ; a leap year: by 4, not by 100
        and 3                       ; unless by 400
        jr nz,.not_leap
        ld hl,(year)
        ld c,100
        call div8
        or a
        jr nz,.leap
        ld a,l
        and 3
        jr z,.leap
.not_leap:
        ld a,28
        ret
.leap:
        ld a,29
        ret

; A = a day of month (in year) -> A = its weekday, 0 Monday .. 6 Sunday
; (Sakamoto's way)
weekday:
        ld (wd_d),a
        ld hl,(year)
        ld a,(month)
        cp 3
        jr nc,.year
        dec hl
.year:
        ld (wd_y),hl
        ld d,h                      ; y + y / 4
        ld e,l
        srl h
        rr l
        srl h
        rr l
        add hl,de
        push hl
        ld hl,(wd_y)                ; - y / 100 + y / 400
        ld c,100
        call div8
        ex de,hl
        pop hl
        or a
        sbc hl,de
        srl d
        rr e
        srl d
        rr e
        add hl,de
        ld a,(month)                ; + t[month - 1] + day
        ld e,a
        ld d,0
        push hl
        ld hl,wd_t - 1
        add hl,de
        ld e,(hl)
        pop hl
        add hl,de
        ld a,(wd_d)
        ld e,a
        add hl,de
        ld c,7
        call div8                   ; 0: Sunday
        add a,6
        cp 7
        ret c
        sub 7
        ret

; HL / C (C up to 128) -> HL, A = what is left
div8:
        xor a
        ld b,16
.bit:
        add hl,hl
        rla
        cp c
        jr c,.next
        sub c
        inc l
.next:
        djnz .bit
        ret

; the date at DE as "2026-11-04", DE after it
date_text:
        call year_text
        ld a,"-"
        ld (de),a
        inc de
        ld a,(month)
        call two
        ld a,"-"
        ld (de),a
        inc de
        ld a,(day)
        jr two

; the year at DE, DE after it
year_text:
        ld hl,(year)
        ld c,100
        call div8
        push af
        ld a,l
        call two
        pop af
        ; fall through
; A = 0..99 -> two digits at DE, DE after them
two:
        ld b,"0" - 1
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,"0" + 10
        ex de,hl
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        ex de,hl
        ret

; ---------------------------------------------------------------------
; DIARY.VDB
; ---------------------------------------------------------------------
; C = DB_* call, DE, HL as it wants
vdb:
        ld a,VX_DB
        jp VOS_EXT

; DIARY.VDB of drive open (made, with its table, the first time), its
; table in use -> carry: A = error
vdb_open:
        ld a,(drive)
        ld (db_file),a
        ld c,DB_OPEN
        ld de,db_file
        call vdb
        jr nc,.use
        cp DB_ERR_NO_FILE
        scf
        ret nz
        ld c,DB_CREATE
        ld de,db_file
        call vdb
        ret c
        ld c,DB_TABLE
        ld de,tdef
        call vdb
        ret c
.use:
        ld e,0
        ld c,DB_USE
        jp vdb

; closed again; A and carry kept
vdb_close:
        push af
        ld c,DB_CLOSE
        call vdb
        pop af
        ret

; the month's marks (when it is another month) and the chosen day's
; notes, from DIARY.VDB; an error said
load:
        xor a
        ld (nnotes),a
        ld de,key
        call date_text
        call vdb_open
        jp c,.error
        ld a,(month)                ; the marks: this month's records
        ld hl,lm_month
        cp (hl)
        jr nz,.marks
        ld hl,(year)
        ld de,(lm_year)
        or a
        sbc hl,de
        jr z,.day
.marks:
        ld a,(month)
        ld (lm_month),a
        ld hl,(year)
        ld (lm_year),hl
        ld hl,marks
        ld b,31
.clear:
        ld (hl),0
        inc hl
        djnz .clear
        ld e,7                      ; "2026-11"
        call find
.mark:
        jr c,.day
        ld b,7
        call same
        jr nz,.day
        ld hl,rbuf + 8
        ld b,2
        call digits
        jr c,.next_mark
        ld a,e
        dec a
        cp 31
        jr nc,.next_mark
        ld hl,marks - 1
        add hl,de
        ld (hl),1
.next_mark:
        call next
        jr .mark
.day:
        ld e,DATE_LEN               ; the day's notes
        call find
.note:
        jr c,.done
        ld b,DATE_LEN
        call same
        jr nz,.done
        ld a,(nnotes)
        cp NOTES_MAX
        jr nc,.done
        ld l,a                      ; its rid
        ld h,0
        add hl,hl
        ld bc,rids
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        call note_at                ; its text
        ex de,hl
        ld hl,rbuf + DATE_LEN
        ld bc,NOTE_LEN
        ldir
        ld hl,nnotes
        inc (hl)
        call next
        jr .note
.done:
        call vdb_close
        ld a,(nnotes)               ; the choice in the notes
        or a
        jr nz,.some
        ld (focus),a
        ld (sel),a
        ret
.some:
        ld hl,sel                   ; at most the last
        dec a
        cp (hl)
        ret nc
        ld (hl),a
        ret
.error:
        call VOS_ERROR
        xor a
        ld (lm_month),a
        ret

; E = key bytes that count: the first record from key on, into rbuf
; (DB_FIND gives it where the key was) -> DE = its rid; carry: none
find:
        push de
        ld hl,key
        ld de,rbuf
        ld bc,DATE_LEN
        ldir
        pop de
        ld hl,rbuf
        ld c,DB_FIND
        jp vdb

; the next record into rbuf -> DE = its rid; carry: none
next:
        ld hl,rbuf
        ld c,DB_NEXT
        jp vdb

; B bytes of rbuf and key the same? Z: yes. DE kept
same:
        push de
        ld hl,rbuf
        ld de,key
.byte:
        ld a,(de)
        cp (hl)
        jr nz,.end
        inc hl
        inc de
        djnz .byte
.end:
        pop de
        ret

; A = a note -> HL -> its text, in notes
note_at:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl                   ; * 8
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl                   ; * 32
        add hl,de                   ; * 40
        ld de,notes
        add hl,de
        ret

; rbuf: the chosen day and in_buf, padded with spaces
make_rec:
        ld de,rbuf
        call date_text
        ld hl,in_buf
        ld b,NOTE_LEN
.char:
        ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .char
        ret
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
        ret

; ---------------------------------------------------------------------
; the notes: add, change, delete
; ---------------------------------------------------------------------
add_note:
        ld hl,in_buf
        ld (hl),0
        call ask
        ret c
        call vdb_open
        jr c,db_error
        ld hl,rbuf
        ld c,DB_ADD
        call vdb
        jr db_done

change_note:
        ld a,(nnotes)
        or a
        ret z
        ld a,(sel)                  ; its text, without the spaces after
        call note_at
        ld de,in_buf
        ld bc,NOTE_LEN
        ldir
        ld b,NOTE_LEN
.trim:
        xor a
        ld (de),a
        dec de
        ld a,(de)
        cp " "
        jr nz,.asked
        djnz .trim
        xor a
        ld (de),a
.asked:
        call ask
        ret c
        call vdb_open
        jr c,db_error
        call rid_sel
        ld hl,rbuf
        ld c,DB_PUT
        call vdb
        jr db_done

delete_note:
        ld a,(nnotes)
        or a
        ret z
        ld hl,dlg_del
        call VOS_DIALOG
        or a
        ret nz
        call vdb_open
        jr c,db_error
        call rid_sel
        ld c,DB_DEL
        call vdb
        ; fall through
; after a change: closed, then the month and the day again
db_done:
        call vdb_close
        jp nc,reload
db_error:
        call VOS_ERROR
        jp reload

; THE NOTE -> rbuf (in_buf, with the day); carry: nothing
ask:
        ld a,T_NOTE_T
        ld hl,in_buf
        ld c,NOTE_LEN
        call VOS_INPUT
        ret c
        ld a,(in_buf)
        or a
        scf
        ret z
        call make_rec
        or a
        ret

; -> DE = the chosen note's rid
rid_sel:
        ld a,(sel)
        ld l,a
        ld h,0
        add hl,hl
        ld de,rids
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

; ---------------------------------------------------------------------
; the screen
; ---------------------------------------------------------------------
; "NOVEMBER 2026" and the diary's drive
draw_top:
        ld a,(month)
        add a,T_M1 - 1
        call VOS_MSG
        ld de,line
.name:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.name
        dec de
        ld a," "
        ld (de),a
        inc de
        call year_text
        xor a
        ld (de),a
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
        ld hl,CAL_X
        ld de,TOP_Y
        ld bc,line
        call VOS_PRINT
        ld de,line                  ; "B:DIARY.VDB"
        ld a,(drive)
        call vos_drive_text
        ld hl,diary_vdb
        ld bc,10
        ldir
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld hl,DRIVE_X
        ld de,TOP_Y
        ld bc,line
        jp VOS_PRINT

; the weekdays, then the month's days, a week a row
draw_month:
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld a,T_WEEK
        ld hl,CAL_X
        ld de,WEEK_Y
        call print_msg
        ld a,1
        call weekday
        ld (cl_col),a
        xor a
        ld (cl_row),a
        call days_in
        ld (cl_days),a
        ld a,1
.day:
        ld (cl_d),a
        ld de,cell                  ; " 4*": the day, marked if it has
        call two                    ; notes
        ld a,(cell)
        cp "0"
        jr nz,.tens
        ld a," "
        ld (cell),a
.tens:
        ld a,(cl_d)
        ld e,a
        ld d,0
        ld hl,marks - 1
        add hl,de
        ld a,(hl)
        or a
        ld a," "
        jr z,.mark
        ld a,"*"
.mark:
        ld (cell + 2),a
        ld a,(day)                  ; the chosen one inverted
        ld hl,cl_d
        cp (hl)
        ld a,INK
        ld c,BG
        jr nz,.colours
        ld a,BG
        ld c,INK
.colours:
        call VOS_COLOURS
        ld a,(cl_col)               ; x = CAL_X + 24 col
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,CAL_X
        add hl,de
        push hl
        ld a,(cl_row)               ; y = CAL_Y + 12 row
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,CAL_Y
        add hl,de
        ex de,hl
        pop hl
        ld bc,cell
        call VOS_PRINT
        ld a,(cl_col)               ; the next place
        inc a
        cp 7
        jr c,.col
        ld hl,cl_row
        inc (hl)
        xor a
.col:
        ld (cl_col),a
        ld a,(cl_d)
        ld hl,cl_days
        cp (hl)
        ret nc
        inc a
        jp .day

; "2026-11-04 WE", then the day's notes, the chosen one inverted (in
; the notes)
draw_notes:
        ld de,line
        call date_text
        ld a," "
        ld (de),a
        inc de
        push de
        ld a,(day)
        call weekday
        ld c,a
        add a,a
        add a,c
        push af
        ld a,T_WEEK
        call VOS_MSG
        pop af
        ld e,a
        ld d,0
        add hl,de
        pop de
        ldi
        ldi
        xor a
        ld (de),a
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
        ld hl,CAL_X
        ld de,NOTES_Y
        ld bc,line
        call VOS_PRINT
        ld a,(nnotes)
        or a
        jr nz,.list
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld a,T_NOTHING
        ld hl,NOTE_X
        ld de,NOTES_Y + 14
        jp print_msg
.list:
        ld b,0
.note:
        push bc
        ld a,b
        call note_at
        ld de,line
        ld bc,NOTE_LEN
        ldir
        xor a
        ld (de),a
        pop bc
        push bc
        ld a,(focus)
        or a
        jr z,.plain
        ld a,(sel)
        cp b
        jr nz,.plain
        ld a,BG
        ld c,INK
        jr .colours
.plain:
        ld a,INK
        ld c,BG
.colours:
        call VOS_COLOURS
        pop bc
        push bc
        ld a,b                      ; y = NOTES_Y + 14 + 10 n
        add a,a
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,NOTES_Y + 14
        ld e,a
        ld d,0
        ld hl,NOTE_X
        ld bc,line
        call VOS_PRINT
        pop bc
        inc b
        ld a,(nnotes)
        cp b
        jr nz,.note
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
        ld b,(hl)                   ; the key, its character
        inc hl
        ld a,(hl)
        cp "<"
        jp z,prev_month
        cp ">"
        jp z,next_month
        ld a,b
        cp VK_TAB
        jr z,.tab
        ld a,(focus)
        or a
        jr nz,notes_key
        ld a,b                      ; the month
        cp VK_LEFT
        ld a,-1
        jp z,move_day
        ld a,b
        cp VK_RIGHT
        ld a,1
        jp z,move_day
        ld a,b
        cp VK_UP
        ld a,-7
        jp z,move_day
        ld a,b
        cp VK_DOWN
        ld a,7
        jp z,move_day
        ret
.tab:
        ld a,(nnotes)
        or a
        ret z
        ld a,(focus)
        xor 1
        ld (focus),a
        jp redraw

; B = a key, in the notes
notes_key:
        ld hl,sel
        ld a,b
        cp VK_UP
        jr nz,.not_up
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jp redraw
.not_up:
        cp VK_DOWN
        jr nz,.not_down
        ld a,(nnotes)
        dec a
        cp (hl)
        ret z
        inc (hl)
        jp redraw
.not_down:
        cp VK_RETURN
        jp z,change_note
        cp VK_ENTER
        jp z,change_note
        cp VK_DEL
        jp z,delete_note
        ret

; A = command
command:
        cp CMD_ADD
        jp z,add_note
        cp CMD_CHANGE
        jp z,change_note
        cp CMD_DELETE
        jp z,delete_note
        cp CMD_PREV_M
        jp z,prev_month
        cp CMD_NEXT_M
        jp z,next_month
        cp CMD_TODAY
        jr nz,.not_today
        call today
        jp nc,reload
        ld hl,dlg_no_time
        jp VOS_DIALOG
.not_today:
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,drive
        call vos_next_drive
        jp reload
.not_drive:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        jp VOS_EXIT

        include "api/vos_drive.inc"

; ---- data -----------------------------------------------------------
win:            db 0                ; 1: in a window (VX_WINDOW)
wsize:          dw 344, 228, 0, 12 ; its w, h, and from x0, y0

palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 11
                db T_ADD, CMD_ADD, "A", 0
                db T_CHANGE, CMD_CHANGE, 0, 0
                db T_DELETE, CMD_DELETE, "D", 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_TODAY, CMD_TODAY, "T", 0
                db T_PREV_M, CMD_PREV_M, 0, 0
                db T_NEXT_M, CMD_NEXT_M, 0, 0
                db T_DRIVE, CMD_DRIVE, "W", 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_del:        db T_MENU, T_DEL_Q, 2, VM_YES, VM_NO
dlg_no_time:    db T_MENU, T_NO_TIME, 1, VM_OK
time_cmd:       db 2
                dw C_TIME
db_file:        db 0, "DIARY   VDB"
diary_vdb:      db "DIARY.VDB", 0
tdef:           db "DAYS    ", 2, 1 ; a table: 2 fields, the first its key
                db "DATE    ", DB_ALPHA, DATE_LEN
                db "NOTE    ", DB_TEXT, NOTE_LEN
month_days:     db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
wd_t:           db 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4

        include "app_texts.asm"     ; T_*, texts, from texts.txt

drive:          db 0
year:           dw 2026             ; the chosen day
month:          db 1
day:            db 1
focus:          db 0                ; 1: the notes, 0: the month
sel:            db 0                ; the chosen note
nnotes:         db 0
lm_month:       db 0                ; the month of marks (0: none)
lm_year:        dw 0
p_year:         dw 0                ; parse_date
p_month:        db 0
wd_y:           dw 0
wd_d:           db 0
cl_col:         db 0                ; drawing the month
cl_row:         db 0
cl_days:        db 0
cl_d:           db 0
cell:           ds 4
key:            ds DATE_LEN
resp:           ds 3 + 20
line:           ds NOTE_LEN + 2
in_buf:         ds NOTE_LEN + 2
rbuf:           ds REC_LEN + 2
marks:          ds 31               ; 1: the day has notes
rids:           ds NOTES_MAX * 2
notes:          ds NOTES_MAX * NOTE_LEN
