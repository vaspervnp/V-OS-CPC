; =====================================================================
; mail.asm - MAIL, e-mail with the M4 board (made with the SDK)
;
; Mode 1. GET MAIL ^G logs in to the POP3 server of the ACCOUNT (USER,
; PASS) and lists the newest MAX_MSG messages (TOP n 0: who from, the
; subject), the newest first; the connection stays open. RETURN reads
; the one chosen (RETR): FROM, DATE and SUBJECT, then its text, in the
; data bank (MSG_MAX bytes at most) and wrapped at the window's width;
; UP and DOWN scroll it a line, LEFT and RIGHT a page, RETURN (or DEL)
; is the list again. Quoted-printable and base64 are decoded, UTF-8 (the text's
; charset) and the =?..?B?..?= and =?..?Q?..?= words of the headers
; made the V-OS set (VX_UTF8); of a message in parts (multipart) its
; first text/... part. DELETE ^D marks it deleted on the server (DELE;
; gone when the connection ends with QUIT: GET MAIL again or BACK).
; SAVE AS TEXT ^S writes what is shown as a .TXT (CR LF, as NOTEPAD).
; WRITE ^W asks TO, SUBJECT and a .TXT of the drive shown (NOTEPAD
; writes it) and sends it through the SMTP server (EHLO or HELO; AUTH
; LOGIN when the account has a password; ISO 8859-7, which is the V-OS
; set's Greek; the subject in =?ISO-8859-7?Q?..?= if it has Greek);
; REPLY ^R, while one is read, the same to its sender with "Re: ".
; ACCOUNT asks the servers (host or host:port; 110 and 25 without),
; the user, the password and the address, kept in MAIL.CFG on MAIL's
; drive (the password as it is). Plain TCP through the M4 board's
; sockets (src/api/vos_net.inc), no TLS: a server that wants it does
; not answer.
;   MAIL menu: GET MAIL ^G, READ, WRITE ^W, REPLY ^R, DELETE ^D, SAVE AS
;   TEXT ^S, ACCOUNT, OTHER DRIVE, ABOUT, BACK ^Q
;   make app NAME=mail        build/MAIL.BIN, on build/apps.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
HEAD            equ 3
COLS            equ 48
ROWS            equ 20
TOP_Y           equ 14
TEXT_Y          equ 28
ROW_H           equ 10
HINT_Y          equ 249
INFO_X          equ 26 * 8          ; the number of messages, or the
INFO_MAX        equ 22              ; server's words
DATA            equ #4000           ; the message, in the data bank
MSG_MAX         equ #3B00
LINES_AT        equ DATA + MSG_MAX  ; the lines' starts, after it
MAX_MSG         equ ROWS            ; in the list
E_SIZE          equ 3 + COLS + 1    ; one: dw its number, db deleted, row
MAX_LINES       equ 640
FIELD           equ 42              ; of the account, and TO, SUBJECT
ACC_SIZE        equ 5 * FIELD
HDR             equ 100             ; a header kept, 0 at its end
BND_MAX         equ 72
EVENTS          equ 8               ; net_poll a frame, at most
QUIET_MAX       equ 1500            ; 30 seconds without an answer

V_LIST          equ 0               ; view
V_READ          equ 1

P_NONE          equ 0               ; POP3's state
P_GREET         equ 1
P_USER          equ 2
P_PASS          equ 3
P_STAT          equ 4
P_TOP_OK        equ 5
P_TOP           equ 6
P_IDLE          equ 7
P_RETR_OK       equ 8
P_RETR          equ 9
P_DELE          equ 10

SM_NONE          equ 0               ; SMTP's state
SM_GREET         equ 1
SM_EHLO          equ 2
SM_HELO          equ 3
SM_AUTH          equ 4
SM_AUTH_U        equ 5
SM_AUTH_P        equ 6
SM_FROM          equ 7
SM_RCPT          equ 8
SM_DATA          equ 9
SM_BODY          equ 10
SM_END           equ 11
SM_QUIT          equ 12

MD_HDR           equ 0               ; a message's lines: its headers,
MD_PRE           equ 1               ; before a part (or a part left
MD_PHDR          equ 2               ; out), a part's headers, the text,
MD_TEXT          equ 3               ; the rest
MD_SKIP          equ 4

CMD_GET         equ VC_APP + 1      ; menu items: commands
CMD_READ        equ VC_APP + 2
CMD_WRITE       equ VC_APP + 3
CMD_REPLY       equ VC_APP + 4
CMD_DELETE      equ VC_APP + 5
CMD_SAVE        equ VC_APP + 6
CMD_ACCOUNT     equ VC_APP + 7
CMD_DRIVE       equ VC_APP + 8
CMD_ABOUT       equ VC_APP + 9
CMD_BACK        equ VC_APP + 10

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start; 2: back, as it was
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
        ld a,1                      ; VE_FRAME events
        call VOS_TICKS
        ld a,(win)                  ; in a window: on behind the others,
        call VOS_BACKGROUND         ; receiving while nothing covers it
        pop af
        cp 2
        jr z,redraw
        ld a,(VOS_SELF)             ; texts on its own drive at first,
        ld (m_drive),a              ; the account from there
        ld hl,cfg_name
        ld de,acc
        call VOS_LOAD
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
        call draw_rows
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld a,(view)
        or a
        ld a,T_HINT
        jr z,.hint
        ld a,T_HINT_R
.hint:
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

; A = text: said in the top line
say_top:
        ld (said),a
        ; fall through
; the state (or what was said), and info
draw_top:
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
        ld hl,0
        ld de,TOP_Y
        ld bc,blank
        call VOS_PRINT
        ld a,(said)
        or a
        jr nz,.text
        ld a,(p_state)
        or a
        ld a,T_CLOSED
        jr z,.text
        ld a,T_CONNECTED
.text:
        ld hl,0
        ld de,TOP_Y
        call print_msg
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld hl,INFO_X
        ld de,TOP_Y
        ld bc,info
        jp VOS_PRINT

; HL -> text: into info (INFO_MAX at most)
set_info:
        ld de,info
        ld b,INFO_MAX
.copy:
        ld a,(hl)
        or a
        jr z,.end
        ld (de),a
        inc hl
        inc de
        djnz .copy
.end:
        xor a
        ld (de),a
        ret

; ---------------------------------------------------------------------
; the rows: the list, or the message read
; ---------------------------------------------------------------------
draw_rows:
        ld b,0
.row:
        push bc
        call draw_row
        pop bc
        inc b
        ld a,b
        cp ROWS
        jr c,.row
        ret

; B = a row
draw_row:
        ld a,(view)
        or a
        jr nz,read_row
        ld a,b                      ; the list: a message, the one
        ld hl,n_msg                 ; chosen inverted
        cp (hl)
        jr nc,blank_row
        push bc
        ld a,(sel)
        cp b
        ld a,INK
        ld c,BG
        jr nz,.colours
        ld a,BG
        ld c,INK
.colours:
        call VOS_COLOURS
        pop bc
        ld a,b
        call ent_at
        inc hl
        inc hl
        inc hl
        ; fall through
; B = row, HL -> its text
print_row:
        push hl
        ld a,b                      ; y = TEXT_Y + 10 row
        add a,a
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,TEXT_Y
        ld e,a
        ld d,0
        pop bc
        ld hl,0
        jp VOS_PRINT

blank_row:
        push bc
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        pop bc
        ld hl,blank
        jp print_row

; B = a row of the message read: its line top + B from the bank
read_row:
        push bc
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        pop bc
        ld e,b
        ld d,0
        ld hl,(top)
        add hl,de
        ex de,hl                    ; DE = the line
        ld hl,(n_lines)
        or a
        sbc hl,de
        jr z,blank_row
        jr c,blank_row
        push bc
        ld a,h                      ; its end: the next line's start, or
        or a                        ; the text's
        jr nz,.next
        dec l
        jr nz,.next
        ld hl,(b_len)
        jr .end
.next:
        push de
        ld h,d
        ld l,e
        inc hl
        call line_start
        pop de
.end:
        push hl
        ex de,hl
        call line_start             ; HL = its start
        pop de
        ex de,hl
        or a
        sbc hl,de                   ; HL = its bytes
        ld bc,63
        push hl
        sbc hl,bc
        pop hl
        jr nc,.most
        ld b,h
        ld c,l
.most:
        ld a,b
        or c
        jr z,.got
        ld hl,DATA
        add hl,de
        ld de,rd_buf
        push bc
        call VOS_BANK_GET
        pop bc
.got:
        ld hl,rd_buf                ; its characters, spaces after them
        ld de,row_buf
        ld a,COLS
        ld (rd_left),a
.char:
        ld a,b
        or c
        jr z,.pad
        dec bc
        ld a,(hl)
        inc hl
        cp 9
        jr nz,.not_tab
        ld a," "
.not_tab:
        cp " "
        jr c,.char
        cp 127
        jr z,.char
        ld (de),a
        inc de
        ld a,(rd_left)
        dec a
        ld (rd_left),a
        jr nz,.char
.pad:
        ld a,(rd_left)
        or a
        jr z,.done
        ld b,a
        ld a," "
.space:
        ld (de),a
        inc de
        djnz .space
.done:
        xor a
        ld (de),a
        pop bc
        ld hl,row_buf
        jp print_row

; HL = a line -> HL = its start in the text (BC, DE lost)
line_start:
        add hl,hl
        ld bc,LINES_AT
        add hl,bc
        ld de,ml_word
        ld bc,2
        call VOS_BANK_GET
        ld hl,(ml_word)
        ret

; A = a message of the list -> HL -> its entry
ent_at:
        ld hl,ents
        ld de,E_SIZE
        or a
        ret z
.add:
        add hl,de
        dec a
        jr nz,.add
        ret

; the lines of the text in the bank, COLS characters at most: their
; starts after it (LINES_AT)
make_lines:
        ld hl,0
        ld (n_lines),hl
        ld (ml_pos),hl
        xor a
        ld (ml_col),a
        ld (ml_left),a
        call ml_add
.byte:
        ld hl,(ml_pos)
        ld de,(b_len)
        or a
        sbc hl,de
        ret nc
        ld a,(ml_left)
        or a
        call z,ml_fill
        ld hl,(ml_at)
        ld a,(hl)
        inc hl
        ld (ml_at),hl
        ld hl,ml_left
        dec (hl)
        ld hl,(ml_pos)
        inc hl
        ld (ml_pos),hl
        cp 13
        jr z,.byte
        cp 10
        jr nz,.char
        xor a
        ld (ml_col),a
        call ml_add
        jr .byte
.char:
        ld a,(ml_col)
        cp COLS
        jr c,.fits
        ld hl,(ml_pos)              ; a new line from this character
        dec hl
        call ml_add_hl
        xor a
.fits:
        inc a
        ld (ml_col),a
        jr .byte

; the next bytes of the text, 64 at most, into ml_buf
ml_fill:
        ld hl,(b_len)
        ld de,(ml_pos)
        or a
        sbc hl,de
        ld bc,64
        push hl
        sbc hl,bc
        pop hl
        jr nc,.most
        ld b,h
        ld c,l
.most:
        ld a,c
        ld (ml_left),a
        ld hl,DATA
        add hl,de
        ld de,ml_buf
        ld (ml_at),de
        jp VOS_BANK_GET

ml_add:
        ld hl,(ml_pos)
; HL = a line's start
ml_add_hl:
        ex de,hl
        ld hl,(n_lines)
        ld bc,MAX_LINES
        or a
        sbc hl,bc
        ret nc
        ld (ml_word),de
        ld hl,(n_lines)
        push hl
        add hl,hl
        ld bc,LINES_AT
        add hl,bc
        ex de,hl
        ld hl,ml_word
        ld bc,2
        call VOS_BANK_PUT
        pop hl
        inc hl
        ld (n_lines),hl
        ret

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        ld a,(hl)
        cp VE_FRAME
        jp z,frame
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
        ld b,(hl)
        ld a,(view)
        or a
        ld a,b
        jr nz,read_key
        cp VK_RETURN
        jp z,read
        cp VK_ENTER
        jp z,read
        ld hl,sel
        cp VK_UP
        jr z,.up
        cp VK_DOWN
        ret nz
        ld a,(n_msg)                ; DOWN: the next
        dec a
        cp (hl)
        ret z
        ret c
        inc (hl)
        jr .moved
.up:
        ld a,(hl)
        or a
        ret z
        dec (hl)
.moved:
        ld b,(hl)                   ; the new one and those around it
        dec b
        jp p,.three
        inc b
.three:
        ld c,3
.row:
        push bc
        call draw_row
        pop bc
        inc b
        ld a,b
        cp ROWS
        ret nc
        dec c
        jr nz,.row
        ret

; A = a key in the message read
read_key:
        cp VK_RETURN                ; RETURN, ENTER or DEL: the list
        jr z,.list
        cp VK_ENTER
        jr z,.list
        cp VK_DEL
        jr nz,.not_list
.list:
        xor a
        ld (view),a
        jp redraw
.not_list:
        ld hl,(top)
        ld de,1
        cp VK_UP
        jr z,.up
        cp VK_DOWN
        jr z,.down
        ld de,ROWS
        cp VK_LEFT
        jr z,.up
        cp VK_RIGHT
        ret nz
.down:
        add hl,de                   ; on, but the last page at most
        push hl
        ld hl,(n_lines)
        ld bc,ROWS
        or a
        sbc hl,bc
        jr nc,.last
        ld hl,0
.last:
        ex de,hl
        pop hl
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.set
        ex de,hl
        jr .set
.up:
        or a
        sbc hl,de
        jr nc,.set
        ld hl,0
.set:
        ld (top),hl
        jp draw_rows

; every frame: what came from both servers, a message sent on
frame:
        ld ix,c_pop
        ld hl,pop_event
        call poll
        ld ix,c_smtp
        ld hl,smtp_event
        call poll
        ld a,(p_state)              ; waiting too long for the POP3
        or a                        ; server?
        jr z,.smtp
        cp P_IDLE
        jr z,.smtp
        ld hl,(p_quiet)
        inc hl
        ld (p_quiet),hl
        ld de,QUIET_MAX
        or a
        sbc hl,de
        jr c,.smtp
        call pop_close
        ld a,T_NO_ANSWER
        call say_top
.smtp:
        ld a,(s_state)              ; or for the SMTP server?
        or a
        ret z
        cp SM_BODY
        jr z,.body
        ld hl,(s_quiet)
        inc hl
        ld (s_quiet),hl
        ld de,QUIET_MAX
        or a
        sbc hl,de
        ret c
        call smtp_close
        ld a,T_NO_ANSWER
        jp say_top
.body:
        ld hl,0
        ld (s_quiet),hl
        jp send_body

; IX -> a connection, HL = what takes its events: net_poll's to it,
; EVENTS at most (A, HL, B as net_poll gives them)
poll:
        ld (handler),hl
        ld (poll_ix),ix
        ld b,EVENTS
.next:
        push bc
        ld ix,(poll_ix)
        call net_poll
        or a
        jr z,.none
        call .call
        pop bc
        djnz .next
        ret
.none:
        pop bc
        ret
.call:
        push hl
        ld hl,(handler)
        ex (sp),hl
        ret

; A = index, HL -> dw table: there
jump:
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

; A = net_poll's event, not NE_LINE -> A = what to say
ne_text:
        cp NE_CLOSED
        ld b,T_CLOSED_BY
        jr z,.text
        cp NE_NO_M4
        ld b,T_NO_M4
        jr z,.text
        ld b,T_FAILED
.text:
        ld a,b
        ret

; ---------------------------------------------------------------------
; POP3
; ---------------------------------------------------------------------
; GET MAIL: logged in again, the list
get_mail:
        ld a,(acc_pop)
        or a
        jr nz,.go
        call account
        ld a,(acc_pop)
        or a
        jp z,redraw
.go:
        call pop_quit
        xor a
        ld (n_msg),a
        ld (sel),a
        ld (view),a
        ld (info),a
        ld hl,0
        ld (b_len),hl
        ld (p_quiet),hl
        ld ix,c_pop
        ld hl,acc_pop
        ld de,110
        call net_open
        jr c,net_said
        ld a,P_GREET
        ld (p_state),a
        ld a,T_CONNECTING
        ld (said),a
        jp redraw

; A = net_open's error: said
net_said:
        call ne_text
        ld (said),a
        jp redraw

; the POP3 connection ended (QUIT first, when logged in: the messages
; deleted go)
pop_quit:
        ld a,(p_state)
        cp P_STAT
        jr c,pop_close
        ld ix,c_pop
        ld hl,s_quit
        call net_say
pop_close:
        xor a
        ld (p_state),a
        ld ix,c_pop
        jp net_close

; A = net_poll's event, HL -> the line, B its length
pop_event:
        push hl
        ld hl,0
        ld (p_quiet),hl
        pop hl
        cp NE_LINE
        jr z,.line
        cp NE_CONNECTED
        ld b,a
        ld a,T_LOGIN
        jp z,say_top
        xor a
        ld (p_state),a
        ld a,b
        call ne_text
        jp say_top
.line:
        ld (line),hl
        ld a,(p_state)
        ld hl,pop_jumps
        jp jump

pop_jumps:      dw pop_none, pop_greet, pop_user, pop_pass, pop_stat
                dw pop_top_ok, pop_top, pop_none, pop_retr_ok, pop_retr
                dw pop_dele

pop_none:
        ret

; -> Z: the line is +OK
pop_ok:
        ld hl,(line)
        ld a,(hl)
        cp "+"
        ret

pop_greet:
        call pop_ok
        jr nz,pop_refused
        ld hl,s_user
        ld de,acc_user
        ld a,P_USER
        jr pop_say

pop_user:
        call pop_ok
        jr nz,pop_refused
        ld hl,s_pass
        ld de,acc_pass
        ld a,P_PASS
        jr pop_say

pop_pass:
        call pop_ok
        jr nz,pop_refused
        ld hl,s_stat
        ld de,empty
        ld a,P_STAT
        ; fall through
; HL -> a command, DE -> what follows it: sent; A = the state now
pop_say:
        ld (p_state),a
        push de
        ld de,out_buf
        call copy_z
        pop hl
        call copy_z
        ld ix,c_pop
        ld hl,out_buf
        jp net_say

; not logged in: what the server said, closed
pop_refused:
        ld hl,(line)
        call set_info
        call pop_close
        ld a,T_REFUSED
        jp say_top

; +OK messages size: the newest MAX_MSG, from the last
pop_stat:
        call pop_ok
        jr nz,pop_refused
        ld hl,(line)
        inc hl
        inc hl
        inc hl
        inc hl
        call net_number
        jr nc,.count
        ld de,0
.count:
        ld (total),de
        ld a,d
        or e
        jr nz,.some
        ld a,P_IDLE
        ld (p_state),a
        ld a,T_NO_MAIL
        jp say_top
.some:
        ld (cur),de
        ex de,hl
        ld bc,MAX_MSG
        or a
        sbc hl,bc
        jr nc,.first
        ld hl,0
.first:
        inc hl
        ld (first),hl
        call top_next
        ld a,T_LISTING
        jp say_top

; TOP cur 0: its headers
top_next:
        call hdr_clear
        ld de,out_buf
        ld hl,s_top
        call copy_z
        ld hl,(cur)
        call decimal
        ld hl,s_zero
        call copy_z
        ld ix,c_pop
        ld hl,out_buf
        call net_say
        ld a,P_TOP_OK
        ld (p_state),a
        ret

pop_top_ok:
        call pop_ok
        jr nz,top_done              ; no TOP: an entry without them
        ld a,P_TOP
        ld (p_state),a
        ret

pop_top:
        ld hl,(line)
        ld a,(hl)
        cp "."
        jp nz,hdr_line
        inc hl
        ld a,(hl)
        or a
        jp nz,hdr_line
        ; fall through
; the headers of message cur came: its entry, then the one before
top_done:
        ld a,(n_msg)
        cp MAX_MSG
        jr nc,.next
        call ent_at
        ld de,(cur)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),0
        inc hl
        push hl
        call hdr_decode
        pop de
        ld a," "                    ; " ", who from, " ", the subject
        ld (de),a
        inc de
        push de
        call from_name
        pop de
        ld b,16
        call pad_copy
        ld a," "
        ld (de),a
        inc de
        ld hl,h_subj
        ld b,COLS - 18
        call pad_copy
        xor a
        ld (de),a
        ld hl,n_msg
        ld b,(hl)
        inc (hl)
        call draw_row
.next:
        ld hl,(cur)
        dec hl
        ld (cur),hl
        ld de,(first)
        or a
        sbc hl,de
        jp nc,top_next
        ld a,P_IDLE                 ; all: "n MESSAGES"
        ld (p_state),a
        ld de,info
        ld hl,(total)
        call decimal
        ld a," "
        ld (de),a
        inc de
        push de
        ld a,T_MESSAGES
        call VOS_MSG
        pop de
        call copy_z
        xor a
        jp say_top

; HL -> text, DE -> where, B = characters: copied, spaces after it
pad_copy:
        ld a,(hl)
        or a
        jr z,.pad
        inc hl
        ld (de),a
        inc de
        djnz pad_copy
        ret
.pad:
        ld a," "
.space:
        ld (de),a
        inc de
        djnz .space
        ret

; READ (RETURN): RETR, its lines into the bank
read:
        ld a,(s_state)              ; (the text sent is in the bank)
        or a
        ret nz
        ld a,(p_state)
        cp P_IDLE
        ret nz
        ld a,(n_msg)
        or a
        ret z
        call chosen
        call hdr_clear
        ld hl,0
        ld (b_len),hl
        ld (b_body),hl
        xor a
        ld (mode),a
        ld (mp),a
        ld (taken),a
        ld (dec_mode),a
        ld (u8),a
        ld (was_long),a
        ld de,out_buf
        ld hl,s_retr
        call copy_z
        ld hl,(cur)
        call decimal
        ld ix,c_pop
        ld hl,out_buf
        call net_say
        ld a,P_RETR_OK
        ld (p_state),a
        ld a,T_GETTING
        jp say_top

; the message chosen: its number in cur
chosen:
        ld a,(sel)
        call ent_at
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (cur),de
        ret

pop_retr_ok:
        call pop_ok
        jr nz,pop_err
        ld a,P_RETR
        ld (p_state),a
        ret

; -ERR: what the server said
pop_err:
        ld hl,(line)
        call set_info
        ld a,P_IDLE
        ld (p_state),a
        ld a,T_SERVER
        jp say_top

; a line of the message: "." alone ends it, ".." is "."
pop_retr:
        ld hl,(line)
        ld a,(was_long)             ; (a piece of a long line: not its
        ld (cont),a                 ; start)
        ld a,(net_long)
        ld (was_long),a
        ld a,(cont)
        or a
        jr nz,.line
        ld a,(hl)
        cp "."
        jr nz,.line
        inc hl
        ld a,(hl)
        or a
        jp z,retr_end
.line:
        ld (cur_line),hl
        ld a,(mode)
        ld hl,mode_jumps
        jp jump

mode_jumps:     dw m_hdr, m_pre, m_phdr, m_text, pop_none

m_hdr:
        ld hl,(cur_line)
        ld a,(hl)
        or a
        jp nz,hdr_line
        ; the headers' end: FROM, DATE, SUBJECT into the bank, then
        ; how the text comes
        call hdr_decode
        ld a,T_FROM_L
        ld hl,h_from
        call put_field
        ld a,T_DATE_L
        ld hl,h_date
        call put_field
        ld a,T_SUBJ_L
        ld hl,h_subj
        call put_field
        call put_crlf
        ld hl,(b_len)
        ld (b_body),hl
        call keep_reply
        ld hl,h_type
        ld de,k_multi
        call find_ci
        jr c,.single
        call boundary
        jr c,.single
        ld a,1
        ld (mp),a
        ld a,MD_PRE
        ld (mode),a
        ret
.single:
        call set_dec
        ld a,MD_TEXT
        ld (mode),a
        ret

; before a part: its boundary starts it (if none was taken yet)
m_pre:
        call bnd_line
        ret c
        ld a,(taken)
        or a
        ld a,MD_SKIP
        jr nz,.set
        xor a
        ld (h_type),a
        ld (h_cte),a
        ld a,MD_PHDR
.set:
        ld (mode),a
        ret

; a part's headers: then a part in parts, a text or one left out
m_phdr:
        ld hl,(cur_line)
        ld a,(hl)
        or a
        jp nz,hdr_line
        ld hl,h_type
        ld de,k_multi
        call find_ci
        jr c,.not_multi
        call boundary
        jr c,.not_multi
        ld a,MD_PRE
        ld (mode),a
        ret
.not_multi:
        ld a,(h_type)
        or a
        jr z,.text
        ld hl,h_type
        ld de,k_text
        call find_ci
        jr c,.skip
.text:
        call set_dec
        ld a,1
        ld (taken),a
        ld a,MD_TEXT
        ld (mode),a
        ret
.skip:
        ld a,MD_PRE
        ld (mode),a
        ret

; a line of the text: decoded into the bank (in parts: until the next
; boundary)
m_text:
        ld a,(mp)
        or a
        jr z,.text
        call bnd_line
        jr c,.text
        ld a,MD_SKIP
        ld (mode),a
        ret
.text:
        ld hl,(cur_line)
        ld a,(dec_mode)
        cp 2
        jr z,.b64
        cp 1
        jr z,.qp
        call put_z
        jr .crlf
.qp:
        ld d,h
        ld e,l
        push hl
        xor a
        ld (q_under),a
        call qp_dec
        pop hl
        push af                     ; carry: "=" at its end, no CR LF
        call put_to_de
        pop af
        ret c
        jr .crlf
.b64:
        ld d,h
        ld e,l
        push hl
        call b64_dec
        pop hl
        jp put_to_de
.crlf:
        ld a,(net_long)
        or a
        ret nz
        jp put_crlf

; ".": the message all here
retr_end:
        ld a,(u8)                   ; UTF-8: its text into the V-OS set
        or a
        jr z,.lines
        ld hl,(b_len)
        ld de,(b_body)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        jr z,.lines
        ld hl,DATA
        add hl,de
        ld e,VOS_DATA
        ld a,VX_UTF8
        call VOS_EXT
        ld hl,(b_body)
        add hl,bc
        ld (b_len),hl
.lines:
        call make_lines
        ld a,P_IDLE
        ld (p_state),a
        ld a,V_READ
        ld (view),a
        ld hl,0
        ld (top),hl
        xor a
        ld (said),a
        jp redraw

; how the text comes: quoted-printable, base64; UTF-8
set_dec:
        ld hl,h_cte
        ld de,k_qp
        call find_ci
        ld a,1
        jr nc,.set
        ld hl,h_cte
        ld de,k_b64
        call find_ci
        ld a,2
        jr nc,.set
        xor a
.set:
        ld (dec_mode),a
        ld hl,h_type
        ld de,k_utf8
        call find_ci
        ld a,0
        jr c,.u8
        inc a
.u8:
        ld (u8),a
        ret

; h_type's boundary= into bnd; carry: none
boundary:
        ld hl,h_type
        ld de,k_bnd
        call find_ci
        ret c
        ld de,bnd
        ld b,BND_MAX
        ld c,0                      ; the quote it is in, or 0
        ld a,(hl)
        cp #22
        jr nz,.copy
        ld c,a
        inc hl
.copy:
        ld a,(hl)
        or a
        jr z,.end
        cp c
        jr z,.end
        push af
        ld a,c
        or a
        jr nz,.take
        pop af
        cp ";"
        jr z,.end
        cp " "
        jr z,.end
        push af
.take:
        pop af
        ld (de),a
        inc de
        inc hl
        djnz .copy
.end:
        xor a
        ld (de),a
        ld a,(bnd)
        or a
        scf
        ret z
        or a
        ret

; -> NC: cur_line is "--" and the boundary
bnd_line:
        ld a,(cont)                 ; (not a piece after the first)
        or a
        scf
        ret nz
        ld hl,(cur_line)
        ld a,(hl)
        cp "-"
        scf
        ret nz
        inc hl
        ld a,(hl)
        cp "-"
        scf
        ret nz
        inc hl
        ld de,bnd
.cmp:
        ld a,(de)
        or a
        ret z
        cp (hl)
        scf
        ret nz
        inc hl
        inc de
        jr .cmp

; DELETE: DELE, after asking
delete:
        ld a,(p_state)
        cp P_IDLE
        ret nz
        ld a,(n_msg)
        or a
        ret z
        ld hl,dlg_del
        call VOS_DIALOG
        or a
        jp nz,redraw
        call chosen
        ld de,out_buf
        ld hl,s_dele
        call copy_z
        ld hl,(cur)
        call decimal
        ld ix,c_pop
        ld hl,out_buf
        call net_say
        ld a,P_DELE
        ld (p_state),a
        jp redraw

pop_dele:
        call pop_ok
        jp nz,pop_err
        ld a,(sel)                  ; marked: X
        call ent_at
        inc hl
        inc hl
        ld (hl),1
        inc hl
        ld (hl),"X"
        ld a,P_IDLE
        ld (p_state),a
        xor a
        ld (view),a
        jp redraw

; ---------------------------------------------------------------------
; a message's headers
; ---------------------------------------------------------------------
hdr_clear:
        xor a
        ld (h_from),a
        ld (h_subj),a
        ld (h_date),a
        ld (h_type),a
        ld (h_cte),a
        ld hl,0
        ld (hdr_cur),hl
        ret

; HL -> a header's line: its value kept, if it is one of hdr_names (a
; line after it starting with a space or a TAB goes on with it)
hdr_line:
        ld a,(hl)
        cp " "
        jr z,.more
        cp 9
        jr z,.more
        ld de,0
        ld (hdr_cur),de
        ld de,hdr_names
.name:
        ld a,(de)
        or a
        ret z
        push hl
        call match_ci
        jr nc,.ours
        pop hl
        inc de
        inc de
        inc de
        jr .name
.ours:
        pop af
        push hl
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (hdr_cap),a
        ld (hdr_cur),de
        xor a
        ld (de),a
        pop hl
.space:
        ld a,(hl)
        cp " "
        jr z,.skip
        cp 9
        jr nz,.more
.skip:
        inc hl
        jr .space
.more:
        ld de,(hdr_cur)
        ld a,d
        or e
        ret z
        ld a,(hdr_cap)
        ld b,a
.end:
        ld a,(de)
        or a
        jr z,.copy
        inc de
        djnz .end
        ret
.copy:
        ld a,(hl)
        or a
        jr z,.done
        ld (de),a
        inc hl
        inc de
        djnz .copy
.done:
        xor a
        ld (de),a
        ret

; HL -> text, DE -> a NAME, 0 -> NC: the text starts with it (without
; case), HL after it; DE after the name's 0 either way
match_ci:
        ld a,(de)
        inc de
        or a
        ret z
        ld c,a
        ld a,(hl)
        call upper
        cp c
        jr nz,.skip
        inc hl
        jr match_ci
.skip:
        ld a,(de)
        inc de
        or a
        jr nz,.skip
        scf
        ret

; HL -> text, DE -> a WORD, 0 -> NC: it is in the text (without case),
; HL after it
find_ci:
        ld a,(hl)
        or a
        scf
        ret z
        push hl
        push de
.cmp:
        ld a,(de)
        or a
        jr z,.found
        ld c,a
        ld a,(hl)
        call upper
        cp c
        jr nz,.next
        inc hl
        inc de
        jr .cmp
.found:
        pop de
        pop af
        or a
        ret
.next:
        pop de
        pop hl
        inc hl
        jr find_ci

upper:
        cp "a"
        ret c
        cp "z" + 1
        ret nc
        sub 32
        ret

; From and Subject: their =?..?= words decoded, UTF-8 the V-OS set
hdr_decode:
        ld hl,h_from
        call .one
        ld hl,h_subj
.one:
        push hl
        ld de,ew_out
        call ew_dec
        ex de,hl
        ld de,ew_out
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        jr z,.copy
        ld hl,ew_out
        ld e,0
        ld a,VX_UTF8
        call VOS_EXT
        ld hl,ew_out
        add hl,bc
        ld (hl),0
.copy:
        pop de
        ld hl,ew_out
        jp copy_z

; HL -> a header's text -> DE: with its =?charset?B?...?= and
; =?charset?Q?...?= decoded (the space between two of them left out),
; 0 at its end, DE at the 0
ew_dec:
        ld a,(hl)
        or a
        jp z,.end
        cp "="
        jr nz,.copy
        inc hl
        ld a,(hl)
        dec hl
        cp "?"
        jr nz,.copy_eq
        push hl                     ; the start, if it is not one
        inc hl
        inc hl
.charset:
        ld a,(hl)
        or a
        jr z,.fail
        inc hl
        cp "?"
        jr nz,.charset
        ld a,(hl)
        and #DF
        ld c,a                      ; B or Q
        inc hl
        ld a,(hl)
        cp "?"
        jr nz,.fail
        inc hl
        push de
        ld de,ew_buf
.data:
        ld a,(hl)
        or a
        jr z,.fail2
        cp "?"
        jr nz,.char
        inc hl
        ld a,(hl)
        dec hl
        cp "="
        jr z,.dend
        ld a,"?"
.char:
        ld (de),a
        inc de
        inc hl
        jr .data
.dend:
        xor a
        ld (de),a
        inc hl
        inc hl
        pop de
        pop af
        push hl
        ld hl,ew_buf
        ld a,c
        cp "B"
        jr nz,.q
        call b64_dec
        jr .done
.q:
        ld a,1
        ld (q_under),a
        call qp_dec
.done:
        pop hl
        push hl                     ; spaces, then another: left out
.sp:
        ld a,(hl)
        cp " "
        jr z,.spn
        cp 9
        jr nz,.spe
.spn:
        inc hl
        jr .sp
.spe:
        cp "="
        jr nz,.keep
        inc hl
        ld a,(hl)
        dec hl
        cp "?"
        jr nz,.keep
        pop af
        jp ew_dec
.keep:
        pop hl
        jp ew_dec
.fail2:
        pop de
.fail:
        pop hl
.copy_eq:
        ld a,"="
.copy:
        ld (de),a
        inc de
        inc hl
        jp ew_dec
.end:
        xor a
        ld (de),a
        ret

; h_from -> HL -> name_buf: the name before <...> (without its quotes),
; or the address
from_name:
        ld hl,h_from
        ld de,name_buf
.copy:
        ld a,(hl)
        or a
        jr z,.end
        cp "<"
        jr z,.end
        inc hl
        cp #22
        jr z,.copy
        ld (de),a
        inc de
        jr .copy
.end:
        ld hl,name_buf              ; the spaces at its end left out
        ex de,hl
.trim:
        or a
        sbc hl,de
        add hl,de
        jr z,.empty
        dec hl
        ld a,(hl)
        cp " "
        jr z,.trim
        inc hl
        ld (hl),0
        ex de,hl
.lead:
        ld a,(hl)
        cp " "
        ret nz
        inc hl
        jr .lead
.empty:
        ld hl,h_from
        ; fall through
; HL -> "Name <a@b>" or "a@b" -> HL -> addr_buf: the address
addr_of:
        push hl
.find:
        ld a,(hl)
        or a
        jr z,.whole
        inc hl
        cp "<"
        jr nz,.find
        pop af
        ld de,addr_buf
.in:
        ld a,(hl)
        or a
        jr z,.end
        cp ">"
        jr z,.end
        ld (de),a
        inc hl
        inc de
        jr .in
.whole:
        pop hl
        ld de,addr_buf
.space:
        ld a,(hl)
        cp " "
        jr nz,.word
        inc hl
        jr .space
.word:
        ld a,(hl)
        or a
        jr z,.end
        cp " "
        jr z,.end
        ld (de),a
        inc hl
        inc de
        jr .word
.end:
        xor a
        ld (de),a
        ld hl,addr_buf
        ret

; the sender and "Re: " the subject, for REPLY
keep_reply:
        ld hl,h_from
        call addr_of
        ld de,r_from
        ld b,FIELD - 2
        call copy_n
        ld de,r_subj
        ld hl,h_subj
        push de
        ld de,k_re
        call match_ci
        pop de
        jr nc,.as_is
        ld hl,s_re
        call copy_z
        ld a,FIELD - 2 - 4
        jr .subject
.as_is:
        ld a,FIELD - 2
.subject:
        ld b,a
        ld hl,h_subj
        ; fall through
; HL -> text -> DE: B characters at most, 0 after them
copy_n:
        ld a,(hl)
        or a
        jr z,.end
        ld (de),a
        inc hl
        inc de
        djnz copy_n
.end:
        xor a
        ld (de),a
        ret

; HL -> text, 0 -> DE: copied, DE at its 0
copy_z:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr copy_z

; ---------------------------------------------------------------------
; the bank: the message read
; ---------------------------------------------------------------------
; A = a label, HL -> its value: "LABEL value" CR LF
put_field:
        push hl
        call VOS_MSG
        call put_z
        ld hl,s_space
        call put_z
        pop hl
        call put_z
        ; fall through
put_crlf:
        ld hl,s_crlf
        ; fall through
; HL -> text, 0
put_z:
        ld d,h
        ld e,l
.end:
        ld a,(de)
        or a
        jr z,put_to_de
        inc de
        jr .end

; HL -> bytes up to DE: into the bank after b_len (MSG_MAX at most)
put_to_de:
        ex de,hl
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ex de,hl
        ; fall through
; HL -> bytes, BC = how many
put_n:
        ld a,b
        or c
        ret z
        push hl
        ld hl,MSG_MAX
        ld de,(b_len)
        or a
        sbc hl,de                   ; room left
        jr z,.full
        push hl
        sbc hl,bc
        pop hl
        jr nc,.fits
        ld b,h
        ld c,l
.fits:
        ld hl,DATA
        add hl,de
        ex de,hl
        ld hl,(b_len)
        add hl,bc
        ld (b_len),hl
        pop hl
        jp VOS_BANK_PUT
.full:
        pop hl
        ret

; ---------------------------------------------------------------------
; decoding
; ---------------------------------------------------------------------
; HL -> quoted-printable text, 0 -> DE (DE <= HL: in place): =XX a byte,
; with q_under "_" a space (a header's word) -> DE after them; carry:
; "=" at its end (the line goes on)
qp_dec:
        ld a,(hl)
        or a
        ret z
        inc hl
        cp "="
        jr z,.esc
        cp "_"
        jr nz,.put
        ld a,(q_under)
        or a
        ld a,"_"
        jr z,.put
        ld a," "
.put:
        ld (de),a
        inc de
        jr qp_dec
.esc:
        ld a,(hl)
        or a
        scf
        ret z
        call hex_val
        jr c,.raw
        add a,a
        add a,a
        add a,a
        add a,a
        ld c,a
        inc hl
        ld a,(hl)
        call hex_val
        jr c,.raw_back
        or c
        inc hl
        jr .put
.raw_back:
        dec hl
.raw:
        ld a,"="
        jr .put

; A = a character -> A = its value as a hex digit; carry: not one
hex_val:
        sub "0"
        cp 10
        ccf
        ret nc
        sub "A" - "0"
        and #DF
        cp 6
        ccf
        ret c
        add a,10
        ret

; HL -> base64, 0 (or "=") -> DE (in place): the bytes, DE after them
b64_dec:
        ld c,0
.loop:
        ld a,(hl)
        or a
        jr z,.end
        inc hl
        cp "="
        jr z,.end
        call b64_val
        jr c,.loop
        push hl
        ld hl,b64_q
        ld b,0
        add hl,bc
        ld (hl),a
        pop hl
        inc c
        ld a,c
        cp 4
        jr nz,.loop
        ld b,3
        call b64_out
        ld c,0
        jr .loop
.end:
        ld a,c
        cp 2
        ret c
        dec a
        ld b,a
        ; fall through
; B bytes from the sextets in b64_q -> DE
b64_out:
        push hl
        ld hl,b64_q
        ld a,(hl)
        add a,a
        add a,a
        ld c,a
        inc hl
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 3
        or c
        ld (de),a
        inc de
        dec b
        jr z,.done
        ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        and #F0
        ld c,a
        inc hl
        ld a,(hl)
        rrca
        rrca
        and #0F
        or c
        ld (de),a
        inc de
        dec b
        jr z,.done
        ld a,(hl)
        rrca
        rrca
        and #C0
        ld c,a
        inc hl
        ld a,(hl)
        or c
        ld (de),a
        inc de
.done:
        pop hl
        ret

; A = a character -> A = its base64 value; carry: not base64
b64_val:
        cp "A"
        jr c,.low
        cp "Z" + 1
        jr nc,.small
        sub "A"
        ret
.small:
        cp "a"
        jr c,.bad
        cp "z" + 1
        jr nc,.bad
        sub "a" - 26
        ret
.low:
        cp "0"
        jr c,.sign
        cp "9" + 1
        jr nc,.bad
        add a,52 - "0"
        ret
.sign:
        cp "+"
        jr z,.plus
        cp "/"
        jr z,.slash
.bad:
        scf
        ret
.plus:
        ld a,62
        ret
.slash:
        ld a,63
        ret

; HL -> text, 0 -> DE: it in base64, 0 at its end
b64_enc:
        xor a
        ld (b64_q),a
        ld (b64_q + 1),a
        ld (b64_q + 2),a
        ld b,0
.take:
        ld a,(hl)
        or a
        jr z,.took
        inc hl
        push hl
        push bc
        ld hl,b64_q
        ld c,b
        ld b,0
        add hl,bc
        ld (hl),a
        pop bc
        pop hl
        inc b
        ld a,b
        cp 3
        jr nz,.take
.took:
        ld a,b
        or a
        jr z,.end
        push hl
        ld a,(b64_q)
        rrca
        rrca
        and 63
        call b64_chr
        ld a,(b64_q)
        and 3
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,(b64_q + 1)
        rrca
        rrca
        rrca
        rrca
        and 15
        or c
        call b64_chr
        ld a,b
        cp 2
        jr c,.pad2
        ld a,(b64_q + 1)
        and 15
        add a,a
        add a,a
        ld c,a
        ld a,(b64_q + 2)
        rlca
        rlca
        and 3
        or c
        call b64_chr
        ld a,b
        cp 3
        jr c,.pad1
        ld a,(b64_q + 2)
        and 63
        call b64_chr
        pop hl
        jr b64_enc
.pad2:
        ld a,"="
        ld (de),a
        inc de
.pad1:
        ld a,"="
        ld (de),a
        inc de
        pop hl
.end:
        xor a
        ld (de),a
        ret

; A = 0..63 -> its base64 character at DE, DE on
b64_chr:
        push hl
        ld hl,b64_tab
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ld (de),a
        inc de
        pop hl
        ret

; ---------------------------------------------------------------------
; SMTP
; ---------------------------------------------------------------------
; WRITE: TO, SUBJECT, the text, then sent
write:
        xor a
        ld (w_to),a
        ld (w_subj),a
        ; fall through
; (REPLY: with TO and SUBJECT)
compose:
        ld a,(s_state)
        or a
        ret nz
        ld a,(p_state)              ; (nor while one comes into it)
        cp P_RETR_OK
        ret z
        cp P_RETR
        ret z
        ld a,(acc_smtp)
        or a
        jr nz,.go
        call account
        ld a,(acc_smtp)
        or a
        jp z,redraw
.go:
        ld a,T_TO_T
        ld hl,w_to
        ld c,FIELD - 2
        call VOS_INPUT
        jp c,redraw
        ld a,(w_to)
        or a
        jp z,redraw
        ld a,T_SUBJ_T
        ld hl,w_subj
        ld c,FIELD - 2
        call VOS_INPUT
        jp c,redraw
        call pick_text
        jp c,redraw
        xor a                       ; the message read is gone from the
        ld (view),a                 ; bank
        ld (info),a
        ld hl,0
        ld (b_len),hl
        ld (s_quiet),hl
        ld ix,c_smtp
        ld hl,acc_smtp
        ld de,25
        call net_open
        jp c,net_said
        ld a,SM_GREET
        ld (s_state),a
        ld a,T_SENDING
        ld (said),a
        jp redraw

; REPLY: to the sender of the one read
reply:
        ld a,(view)
        or a
        ret z
        ld hl,r_from
        ld de,w_to
        call copy_z
        ld hl,r_subj
        ld de,w_subj
        call copy_z
        jp compose

; a .TXT of m_drive, chosen, into the bank (s_len bytes) -> carry: not
pick_text:
        ld a,(m_drive)
        or VOS_CAT_EXT
        ld hl,ext_txt
        call VOS_CATALOG
        jr c,.error
        or a
        jr nz,.pick
        ld hl,dlg_no_txt
        call VOS_DIALOG
        scf
        ret
.error:
        call VOS_ERROR
        scf
        ret
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
        ld de,fname
        ld bc,11
        ldir
        ld a,(m_drive)
        or VOS_DATA
        ld hl,fname
        ld de,DATA
        call VOS_LOAD
        jr c,.error
        ld (s_len),bc
        ld hl,0
        ld (s_pos),hl
        ld a,1
        ld (s_bol),a
        xor a
        ld (s_prev),a
        ret

smtp_close:
        xor a
        ld (s_state),a
        ld ix,c_smtp
        jp net_close

; A = net_poll's event, HL -> the line
smtp_event:
        push hl
        ld hl,0
        ld (s_quiet),hl
        pop hl
        cp NE_LINE
        jr z,.line
        cp NE_CONNECTED
        ret z
        ld b,a
        ld a,(s_state)
        cp SM_QUIT                   ; after QUIT: sent
        jr z,smtp_close
        xor a
        ld (s_state),a
        ld a,b
        call ne_text
        jp say_top
.line:
        ld (line),hl
        call net_reply              ; its last line: its number
        ret c
        ld (rcode),de
        ld a,(s_state)
        ld hl,smtp_jumps
        jp jump

smtp_jumps:     dw pop_none, smtp_greet, smtp_ehlo, smtp_helo, smtp_auth
                dw smtp_auth_u, smtp_auth_p, smtp_from, smtp_rcpt
                dw smtp_data, smtp_fail, smtp_end, smtp_quit

; DE = a number -> Z: the reply's
is_code:
        ld hl,(rcode)
        or a
        sbc hl,de
        ret

smtp_greet:
        ld de,220
        call is_code
        jp nz,smtp_fail
        ld hl,s_ehlo
        ld a,SM_EHLO
        jp smtp_say

smtp_ehlo:
        ld de,250
        call is_code
        jr z,.hello
        ld hl,s_helo                ; no EHLO: HELO
        ld a,SM_HELO
        jp smtp_say
.hello:
        ld a,(acc_pass)             ; a password: AUTH LOGIN
        or a
        jr z,mail_from
        ld hl,s_auth
        ld a,SM_AUTH
        jp smtp_say

smtp_helo:
        ld de,250
        call is_code
        jr z,mail_from
        ; fall through
; not sent: what the server said, closed
smtp_fail:
        ld hl,(line)
        call set_info
        call smtp_close
        ld a,T_NOT_SENT
        jp say_top

smtp_auth:
        ld hl,acc_user
        ld a,SM_AUTH_U
        jr smtp_b64

smtp_auth_u:
        ld hl,acc_pass
        ld a,SM_AUTH_P
        ; fall through
; after 334: HL -> text, in base64; A = the state now
smtp_b64:
        push af
        push hl
        ld de,334
        call is_code
        pop hl
        jr nz,.fail
        ld de,out_buf
        call b64_enc
        pop af
        ld hl,out_buf
        jp smtp_say
.fail:
        pop af
        jp smtp_fail

smtp_auth_p:
        ld de,235
        call is_code
        jp nz,smtp_fail
        ; fall through
mail_from:
        ld hl,s_mail
        ld de,acc_mail
        ld a,SM_FROM
        jr smtp_angle

smtp_from:
        ld de,250
        call is_code
        jp nz,smtp_fail
        ld hl,w_to
        call addr_of
        ex de,hl
        ld hl,s_rcpt
        ld a,SM_RCPT
        ; fall through
; HL -> a command, DE -> an address: "COMMAND<address>"; A = the state
smtp_angle:
        push af
        push de
        ld de,out_buf
        call copy_z
        pop hl
        call copy_z
        ld a,">"
        ld (de),a
        inc de
        xor a
        ld (de),a
        pop af
        ld hl,out_buf
        ; fall through
; HL -> a line: sent; A = the state now
smtp_say:
        ld (s_state),a
        ld ix,c_smtp
        jp net_say

smtp_rcpt:
        ld de,250
        call is_code
        jr z,.ok
        ld de,251
        call is_code
        jp nz,smtp_fail
.ok:
        ld hl,s_data
        ld a,SM_DATA
        jp smtp_say

; 354: the headers, then the text (send_body)
smtp_data:
        ld de,354
        call is_code
        jp nz,smtp_fail
        ld hl,s_h_from
        ld de,acc_mail
        call say_pair
        ld hl,s_h_to
        ld de,w_to
        call say_pair
        call subj_enc
        ld hl,s_h_subj
        ld de,enc_buf
        call say_pair
        ld hl,s_h_mime
        call smtp_line
        ld hl,s_h_type
        call smtp_line
        ld hl,s_h_cte
        call smtp_line
        ld hl,s_h_mailer
        call smtp_line
        ld hl,empty
        call smtp_line
        ld a,SM_BODY
        ld (s_state),a
        ret

; HL -> a header's name, DE -> its value: sent
say_pair:
        push de
        ld de,out_buf
        call copy_z
        pop hl
        call copy_z
        ld hl,out_buf
        ; fall through
; HL -> a line: sent on the SMTP connection
smtp_line:
        ld ix,c_smtp
        jp net_say

smtp_end:
        ld de,250
        call is_code
        jp nz,smtp_fail
        ld hl,s_quit
        ld a,SM_QUIT
        call smtp_say
        ld a,T_SENT
        jp say_top

smtp_quit:
        jp smtp_close

; w_subj -> enc_buf: as it is, or =?ISO-8859-7?Q?...?= if it has a
; letter over 127
subj_enc:
        ld hl,w_subj
.find:
        ld a,(hl)
        or a
        jr z,.plain
        inc hl
        cp 128
        jr c,.find
        ld hl,s_q_start
        ld de,enc_buf
        call copy_z
        ld hl,w_subj
.char:
        ld a,(hl)
        or a
        jr z,.q_end
        inc hl
        cp " "
        jr nz,.not_space
        ld a,"_"
        jr .put
.not_space:
        call alnum
        jr nc,.put
        ld c,a                      ; =XX
        ld a,"="
        ld (de),a
        inc de
        ld a,c
        rrca
        rrca
        rrca
        rrca
        call hex_chr
        ld a,c
        call hex_chr
        jr .char
.put:
        ld (de),a
        inc de
        jr .char
.q_end:
        ld hl,s_q_end
        jp copy_z
.plain:
        ld hl,w_subj
        ld de,enc_buf
        jp copy_z

; A -> NC: a letter A-Z, a-z or a digit
alnum:
        cp "0"
        ret c
        cp "9" + 1
        ccf
        ret nc
        push af
        call upper
        cp "A"
        jr c,.no
        cp "Z" + 1
        jr nc,.no
        pop af
        or a
        ret
.no:
        pop af
        scf
        ret

; A: its low four bits as a hex digit at DE, DE on
hex_chr:
        and 15
        add a,"0"
        cp "9" + 1
        jr c,.put
        add a,"A" - "9" - 1
.put:
        ld (de),a
        inc de
        ret

; SM_BODY, each frame the M4 is not sending: up to 96 bytes of the text,
; "." first doubled, LF alone CR LF; at its end "." alone
send_body:
        ld ix,c_smtp
        call net_ready
        ret c
        ld hl,(s_len)
        ld de,(s_pos)
        or a
        sbc hl,de
        ld bc,96
        push hl
        sbc hl,bc
        pop hl
        jr nc,.full
        ld b,h
        ld c,l
.full:
        ld de,sb_out
        ld a,b
        or c
        jr z,.ending
        push bc
        ld hl,(s_pos)
        push hl
        add hl,bc
        ld (s_pos),hl
        pop hl
        ld de,DATA
        add hl,de
        ld de,sb_in
        call VOS_BANK_GET
        pop bc
        ld hl,sb_in
        ld de,sb_out
.byte:
        ld a,(s_bol)
        or a
        jr z,.mid
        ld a,(hl)
        cp "."
        jr nz,.mid
        ld (de),a
        inc de
.mid:
        ld a,(hl)
        cp 10
        jr nz,.put
        ld a,(s_prev)
        cp 13
        jr z,.lf
        ld a,13
        ld (de),a
        inc de
.lf:
        ld a,10
.put:
        ld (de),a
        inc de
        ld (s_prev),a
        cp 10
        ld a,0
        jr nz,.bol
        inc a
.bol:
        ld (s_bol),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.byte
        push de
        ld hl,(s_len)
        ld de,(s_pos)
        or a
        sbc hl,de
        pop de
        jr nz,.send
.ending:
        ld a,(s_bol)
        or a
        jr nz,.dot
        ld a,13
        ld (de),a
        inc de
        ld a,10
        ld (de),a
        inc de
.dot:
        ld hl,s_dot
        ld bc,3
        ldir
        ld a,SM_END
        ld (s_state),a
.send:
        ex de,hl
        ld de,sb_out
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,sb_out
        ld ix,c_smtp
        jp net_send

; ---------------------------------------------------------------------
; commands
; ---------------------------------------------------------------------
command:
        cp CMD_GET
        jp z,get_mail
        cp CMD_READ
        jp z,read
        cp CMD_WRITE
        jp z,write
        cp CMD_REPLY
        jp z,reply
        cp CMD_DELETE
        jp z,delete
        cp CMD_SAVE
        jr z,save_text
        cp CMD_ACCOUNT
        jr nz,.not_account
        call account
        jp redraw
.not_account:
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,m_drive
        call vos_next_drive
        ld de,info
        call vos_drive_text
        xor a
        ld (de),a
        ld a,T_DRIVE_IS
        ld (said),a
        jp redraw
.not_drive:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        call pop_quit
        call smtp_close
        jp VOS_EXIT

; SAVE AS TEXT: the message read, a .TXT on m_drive
save_text:
        ld a,(view)
        or a
        ret z
        ld a,T_NAME_T
        ld hl,name_in
        ld c,12
        call VOS_INPUT
        jp c,redraw
        call make_name
        jp c,redraw
        ld a,(m_drive)
        or VOS_DATA
        ld hl,fname
        ld de,DATA
        ld bc,(b_len)
        call VOS_SAVE
        jr c,.error
        ld a,T_SAVED
        ld (said),a
        jp redraw
.error:
        call VOS_ERROR
        jp redraw

; ACCOUNT: the servers, the user, the password, the address -> MAIL.CFG
account:
        ld a,T_POP_T
        ld hl,acc_pop
        call .ask
        ret c
        ld a,T_SMTP_T
        ld hl,acc_smtp
        call .ask
        ret c
        ld a,T_USER_T
        ld hl,acc_user
        call .ask
        ret c
        ld a,T_PASS_T
        ld hl,acc_pass
        call .ask
        ret c
        ld a,T_ADDR_T
        ld hl,acc_mail
        call .ask
        ret c
        ld a,(VOS_SELF)
        ld hl,cfg_name
        ld de,acc
        ld bc,ACC_SIZE
        call VOS_SAVE
        ret nc
        jp VOS_ERROR
.ask:
        ld c,FIELD - 2
        jp VOS_INPUT

; name_in "name.ext" -> fname, 11 bytes in capitals; carry if empty
make_name:
        ld hl,fname
        ld b,11
.clear:
        ld (hl)," "
        inc hl
        djnz .clear
        ld hl,name_in
        ld a,(hl)
        or a
        scf
        ret z
        ld de,fname
        ld b,8
        call .part
        ld a,(hl)
        cp "."
        jr nz,.no_ext
        inc hl
        ld de,fname + 8
        ld b,3
        call .part
.no_ext:
        or a
        ret
.part:
        ld a,(hl)
        or a
        ret z
        cp "."
        ret z
        call upper
        ld (de),a
        inc hl
        inc de
        djnz .part
.skip:
        ld a,(hl)
        or a
        ret z
        cp "."
        ret z
        inc hl
        jr .skip

; HL = a number -> DE: in decimal, DE after it (no 0)
decimal:
        push ix
        ld ix,tens
        ld b,0                      ; 1: a digit was written
.digit:
        push bc
        ld c,(ix + 0)
        ld b,(ix + 1)
        ld a,"0" - 1
.more:
        inc a
        or a
        sbc hl,bc
        jr nc,.more
        add hl,bc
        pop bc
        ld c,a
        ld a,(ix + 0)
        dec a
        jr z,.write
        ld a,c
        cp "0"
        jr nz,.write
        ld a,b
        or a
        jr z,.next
.write:
        ld a,c
        ld (de),a
        inc de
        ld b,1
.next:
        inc ix
        inc ix
        ld a,(ix + 0)
        or (ix + 1)
        jr nz,.digit
        pop ix
        ret

        include "api/vos_net.inc"
        include "api/vos_drive.inc"

; ---- data -----------------------------------------------------------
win:            db 0                ; 1: in a window (VX_WINDOW)
wsize:          dw 376, 232, 0, 12 ; its w, h, and from x0, y0

palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 11
                db T_GET, CMD_GET, "G", 0
                db T_READ, CMD_READ, 0, 0
                db T_WRITE, CMD_WRITE, "W", 0
                db T_REPLY, CMD_REPLY, "R", 0
                db T_DELETE, CMD_DELETE, "D", 0
                db T_SAVE, CMD_SAVE, "S", 0
                db T_ACCOUNT, CMD_ACCOUNT, 0, 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_del:        db T_MENU, T_DEL_Q, 2, VM_YES, VM_NO
dlg_no_txt:     db T_MENU, T_NO_TXT, 1, VM_OK
tens:           dw 10000, 1000, 100, 10, 1, 0
cfg_name:       db "MAIL    CFG"
ext_txt:        db "TXT"
hdr_names:      db "FROM:", 0
                dw h_from
                db HDR - 1
                db "SUBJECT:", 0
                dw h_subj
                db HDR - 1
                db "DATE:", 0
                dw h_date
                db 47
                db "CONTENT-TYPE:", 0
                dw h_type
                db HDR - 1
                db "CONTENT-TRANSFER-ENCODING:", 0
                dw h_cte
                db 39
                db 0
k_multi:        db "MULTIPART/", 0
k_text:         db "TEXT/", 0
k_bnd:          db "BOUNDARY=", 0
k_qp:           db "QUOTED-PRINTABLE", 0
k_b64:          db "BASE64", 0
k_utf8:         db "UTF-8", 0
k_re:           db "RE:", 0
s_re:           db "Re: ", 0
s_user:         db "USER ", 0
s_pass:         db "PASS ", 0
s_stat:         db "STAT", 0
s_top:          db "TOP ", 0
s_zero:         db " 0", 0
s_retr:         db "RETR ", 0
s_dele:         db "DELE ", 0
s_quit:         db "QUIT", 0
s_ehlo:         db "EHLO cpc", 0
s_helo:         db "HELO cpc", 0
s_auth:         db "AUTH LOGIN", 0
s_mail:         db "MAIL FROM:<", 0
s_rcpt:         db "RCPT TO:<", 0
s_data:         db "DATA", 0
s_h_from:       db "From: ", 0
s_h_to:         db "To: ", 0
s_h_subj:       db "Subject: ", 0
s_h_mime:       db "MIME-Version: 1.0", 0
s_h_type:       db "Content-Type: text/plain; charset=ISO-8859-7", 0
s_h_cte:        db "Content-Transfer-Encoding: 8bit", 0
s_h_mailer:     db "X-Mailer: V-OS MAIL", 0
s_q_start:      db "=?ISO-8859-7?Q?", 0
s_q_end:        db "?=", 0
s_dot:          db ".", 13, 10
s_crlf:         db 13, 10, 0
s_space:        db " "
empty:          db 0
b64_tab:        db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
blank:          ds COLS, " "
                db 0

        include "app_texts.asm"     ; T_*, texts, from texts.txt

acc:                                ; MAIL.CFG
acc_pop:        ds FIELD
acc_smtp:       ds FIELD
acc_user:       ds FIELD
acc_pass:       ds FIELD
acc_mail:       ds FIELD
m_drive:        db 0
said:           db 0                ; a text instead of the state's
view:           db V_LIST
p_state:        db P_NONE
s_state:        db SM_NONE
p_quiet:        dw 0
s_quiet:        dw 0
handler:        dw 0
poll_ix:        dw 0
line:           dw 0
cur_line:       dw 0
rcode:          dw 0
total:          dw 0
cur:            dw 0
first:          dw 0
n_msg:          db 0
sel:            db 0
top:            dw 0
n_lines:        dw 0
b_len:          dw 0
b_body:         dw 0
mode:           db 0
mp:             db 0
taken:          db 0
dec_mode:       db 0                ; 1 quoted-printable, 2 base64
u8:             db 0
was_long:       db 0
cont:           db 0
q_under:        db 0
hdr_cur:        dw 0
hdr_cap:        db 0
ml_pos:         dw 0
ml_col:         db 0
ml_left:        db 0
ml_at:          dw 0
ml_word:        dw 0
rd_left:        db 0
s_len:          dw 0
s_pos:          dw 0
s_bol:          db 0
s_prev:         db 0
cat:            dw 0
b64_q:          ds 4
name_in:        db "MAIL.TXT", 0
                ds 5
fname:          ds 11
info:           ds INFO_MAX + 1
w_to:           ds FIELD
w_subj:         ds FIELD
r_from:         ds FIELD
r_subj:         ds FIELD
h_from:         ds HDR
h_subj:         ds HDR
h_date:         ds 48
h_type:         ds HDR
h_cte:          ds 40
bnd:            ds BND_MAX + 1
ew_buf:                             ; (a header decoded, then its name
name_buf:       ds HDR              ; or address)
ew_out:
addr_buf:       ds HDR
out_buf:        ds 200
ml_buf:                             ; (not while a text is sent: no
sb_in:          ds 64               ; READ then)
rd_buf:         ds 64
row_buf:        ds COLS + 1
enc_buf:                            ; (the subject, before the text)
sb_out:         ds 2 * 96 + 8
c_pop:          ds NC_SIZE
c_smtp:         ds NC_SIZE
ents:           ds MAX_MSG * E_SIZE
