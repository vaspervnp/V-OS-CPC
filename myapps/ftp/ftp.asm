; =====================================================================
; ftp.asm - FTP, files to and from a server with the M4 board (made
; with the SDK)
;
; Mode 1. CONNECT ^O asks HOST:PORT (21 without a port), the user
; (none: anonymous) and the password, logs in (USER, PASS; TYPE I) and
; lists the server's folder (PWD, then PASV and LIST on a second
; connection, to the control connection's address and the port PASV
; gave): its folders, <DIR>, and files with their sizes (the lines of
; Unix and of DOS servers), MAX_ENT at most. UP and DOWN choose one;
; RETURN opens a folder (CWD) or gets a file; DEL, or UP A FOLDER ^U,
; goes up (CDUP). GET THE FILE ^G asks the name (8.3, from the
; server's) and RETR's it into the data bank, then saves it on the
; drive shown (OTHER DRIVE changes it): 16K at most (more: closed, not
; saved). PUT A FILE ^P sends a file of that drive (STOR, its name as
; on the disc), DELETE THE FILE ^D deletes the one chosen (DELE), and
; the list is read again after them. CLOSE ^K, and BACK, say QUIT.
; Plain TCP through the M4 board's sockets (src/api/vos_net.inc), no
; TLS.
;   FTP menu: CONNECT ^O, CLOSE ^K, GET THE FILE ^G, PUT A FILE ^P,
;   DELETE THE FILE ^D, UP A FOLDER ^U, OTHER DRIVE, ABOUT, BACK ^Q
;   make app NAME=ftp         build/FTP.BIN, on build/apps.dsk
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
INFO_X          equ 26 * 8          ; the folder, or the server's words
INFO_MAX        equ 22
DATA            equ #4000           ; a file, in the data bank
FILE_MAX        equ #4000
MAX_ENT         equ 48              ; in the list
NAME_MAX        equ 36
SIZE_W          equ 9
E_SIZE          equ 1 + NAME_MAX + 1 + SIZE_W + 1 ; db folder, name, size
FIELD           equ 42
PWD_MAX         equ 60
EVENTS          equ 8               ; net_poll a frame, at most
QUIET_MAX       equ 1500            ; 30 seconds without an answer
PIECE           equ 240             ; STOR: a frame

C_NONE          equ 0               ; the control connection's state
C_GREET         equ 1
C_USER          equ 2
C_PASS          equ 3
C_TYPE          equ 4
C_PWD           equ 5
C_PASV          equ 6
C_X150          equ 7
C_XFER          equ 8
C_IDLE          equ 9
C_CWD           equ 10
C_DELE          equ 11

J_LIST          equ 0               ; what PASV is for
J_RETR          equ 1
J_STOR          equ 2

CMD_CONNECT     equ VC_APP + 1      ; menu items: commands
CMD_CLOSE       equ VC_APP + 2
CMD_GET         equ VC_APP + 3
CMD_PUT         equ VC_APP + 4
CMD_DELETE      equ VC_APP + 5
CMD_UP          equ VC_APP + 6
CMD_DRIVE       equ VC_APP + 7
CMD_ABOUT       equ VC_APP + 8
CMD_BACK        equ VC_APP + 9

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
        ld a,(win)                  ; in a window: on behind the others
        call VOS_BACKGROUND
        pop af
        cp 2
        jr z,redraw
        ld a,(VOS_SELF)             ; files on its own drive at first
        ld (f_drive),a
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
        ld a,(c_state)
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

; HL -> text: into info (INFO_MAX at most; of a long folder its end)
set_info:
        push hl
        ld bc,0
.len:
        ld a,(hl)
        or a
        jr z,.counted
        inc hl
        inc bc
        jr .len
.counted:
        pop hl
        ld a,c
        sub INFO_MAX
        jr c,.copy
        ld a,b
        or a
        jr nz,.copy                 ; (not over 255)
        ld a,c
        sub INFO_MAX
        ld e,a
        ld d,0
        add hl,de
.copy:
        ld de,info
        ld b,INFO_MAX
.char:
        ld a,(hl)
        or a
        jr z,.end
        ld (de),a
        inc hl
        inc de
        djnz .char
.end:
        xor a
        ld (de),a
        ret

; HL = a number: "TEXT  n" said (SAVED, BYTES 1234)
say_bytes:
        ld (said),a
        ld de,info
        call decimal
        xor a
        ld (de),a
        jp draw_top

; ---------------------------------------------------------------------
; the list
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

; B = a row: the entry l_top + B (the one chosen inverted)
draw_row:
        push bc                     ; (the row)
        ld a,(l_top)
        add a,b
        ld hl,n_ent
        cp (hl)
        jr nc,.blank
        push af
        ld b,a
        ld a,(sel)
        cp b
        ld a,INK
        ld c,BG
        jr nz,.colours
        ld a,BG
        ld c,INK
.colours:
        call VOS_COLOURS
        pop af
        call ent_at
        ld de,row_buf               ; " ", the name, the size
        ld a," "
        ld (de),a
        inc de
        push hl
        inc hl
        ld b,NAME_MAX
        call pad_copy
        ld a," "
        ld (de),a
        inc de
        pop hl
        ld bc,1 + NAME_MAX + 1
        add hl,bc
        ld bc,SIZE_W
        ldir
        xor a
        ld (de),a
        ld hl,row_buf
        jr .print
.blank:
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld hl,blank
.print:
        pop bc
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

; A = an entry -> HL -> it
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
        ld a,(hl)
        cp VK_RETURN
        jp z,open
        cp VK_ENTER
        jp z,open
        cp VK_DEL
        jp z,go_up
        ld hl,sel
        cp VK_UP
        jr z,.up
        cp VK_DOWN
        ret nz
        ld a,(n_ent)                ; DOWN: the next
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
        ld a,(l_top)                ; in view: the list scrolls, or the
        ld b,a                      ; rows around it are drawn
        ld a,(sel)
        cp b
        jr c,.scroll
        sub b
        cp ROWS
        jr nc,.down
        ld b,a
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
.down:
        ld a,(sel)
        sub ROWS - 1
.scroll:
        ld (l_top),a
        jp draw_rows

; every frame: the control and data connections, STOR's next piece
frame:
        ld ix,c_ctl
        ld hl,ctl_event
        call poll
        ld ix,c_dat
        ld hl,dat_event
        call poll
        ld a,(c_state)              ; waiting too long?
        or a
        ret z
        cp C_IDLE
        ret z
        ld a,(job)
        cp J_STOR
        jr nz,.quiet
        ld a,(c_state)
        cp C_XFER
        jr nz,.quiet
        ld hl,0
        ld (c_quiet),hl
        jp send_piece
.quiet:
        ld hl,(c_quiet)
        inc hl
        ld (c_quiet),hl
        ld de,QUIET_MAX
        or a
        sbc hl,de
        ret c
        call close_all
        ld a,T_NO_ANSWER
        jp say_top

; IX -> a connection, HL = what takes its events: net_poll's to it,
; EVENTS at most (A, HL, B, BC as net_poll gives them)
poll:
        ld (handler),hl
        ld (poll_ix),ix
        ld a,EVENTS
        ld (poll_n),a
.next:
        ld ix,(poll_ix)
        call net_poll
        or a
        ret z
        call .call
        ld hl,poll_n
        dec (hl)
        jr nz,.next
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
; the control connection
; ---------------------------------------------------------------------
; CONNECT: the address, the user, the password; logged in
connect:
        call close_all
        ld a,T_ADDR_T
        ld hl,addr
        ld c,FIELD - 2
        call VOS_INPUT
        jp c,redraw
        ld a,(addr)
        or a
        jp z,redraw
        ld a,T_USER_T
        ld hl,user
        ld c,FIELD - 2
        call VOS_INPUT
        jp c,redraw
        ld a,(user)                 ; none: anonymous, an address as the
        or a                        ; password
        jr nz,.password
        ld hl,s_anon
        ld de,user
        call copy_z
        ld hl,s_anon_pass
        ld de,pass
        call copy_z
        jr .open
.password:
        ld a,T_PASS_T
        ld hl,pass
        ld c,FIELD - 2
        call VOS_INPUT
        jp c,redraw
.open:
        xor a
        ld (n_ent),a
        ld (sel),a
        ld (l_top),a
        ld (info),a
        ld (pwd),a
        ld hl,0
        ld (c_quiet),hl
        ld ix,c_ctl
        ld hl,addr
        ld de,21
        call net_open
        jr c,net_said
        ld a,C_GREET
        ld (c_state),a
        ld a,T_CONNECTING
        ld (said),a
        jp redraw

; A = net_open's error: said
net_said:
        call ne_text
        ld (said),a
        jp redraw

; both connections closed (QUIT first, when logged in)
close_all:
        ld ix,c_dat
        call net_close
        ld a,(c_state)
        cp C_TYPE
        jr c,.close
        ld ix,c_ctl
        ld hl,s_quit
        call net_say
.close:
        xor a
        ld (c_state),a
        ld ix,c_ctl
        jp net_close

; A = net_poll's event, HL -> the line
ctl_event:
        push hl
        ld hl,0
        ld (c_quiet),hl
        pop hl
        cp NE_LINE
        jr z,.line
        cp NE_CONNECTED
        ld b,a
        ld a,T_LOGIN
        jp z,say_top
        ld a,b
        call ne_text
        push af
        call close_all
        pop af
        jp say_top
.line:
        ld (line),hl
        call net_reply              ; its last line: its number
        ret c
        ld (rcode),de
        ld a,(c_state)
        ld hl,ctl_jumps
        jp jump

ctl_jumps:      dw ctl_none, ctl_greet, ctl_user, ctl_pass, ctl_type
                dw ctl_pwd, ctl_pasv, ctl_x150, ctl_xfer, ctl_none
                dw ctl_cwd, ctl_dele

ctl_none:
        ret

; -> A = the reply's first digit ("2", "3", "4", "5")
first_digit:
        ld hl,(line)
        ld a,(hl)
        ret

; DE = a number -> Z: the reply's
is_code:
        ld hl,(rcode)
        or a
        sbc hl,de
        ret

ctl_greet:
        call first_digit
        cp "2"
        jr nz,ctl_refused
        ld hl,s_user
        ld de,user
        ld a,C_USER
        jp ctl_say

ctl_user:
        ld de,230                   ; in without a password
        call is_code
        jr z,logged_in
        call first_digit
        cp "3"
        jr nz,ctl_refused
        ld hl,s_pass
        ld de,pass
        ld a,C_PASS
        jp ctl_say

ctl_pass:
        call first_digit
        cp "2"
        jr nz,ctl_refused
        ; fall through
logged_in:
        ld hl,s_type
        ld de,empty
        ld a,C_TYPE
        ; fall through
; HL -> a command, DE -> what follows it: sent; A = the state now
ctl_say:
        ld (c_state),a
        push de
        ld de,out_buf
        call copy_z
        pop hl
        call copy_z
        ld ix,c_ctl
        ld hl,out_buf
        jp net_say

; not logged in: what the server said, closed
ctl_refused:
        ld hl,(line)
        call set_info
        call close_all
        ld a,T_REFUSED
        jp say_top

; what the server said; the list as it was
ctl_err:
        ld hl,(line)
        call set_info
        ld ix,c_dat
        call net_close
        ld a,C_IDLE
        ld (c_state),a
        ld a,T_SERVER
        jp say_top

ctl_type:
        ; (200, or not: images are what most servers send anyway)
        ; fall through
; PWD: the folder, then its list
pwd_list:
        ld hl,s_pwd
        ld de,empty
        ld a,C_PWD
        jp ctl_say

; 257 "folder": kept, shown; then PASV for its LIST
ctl_pwd:
        ld hl,(line)
.quote:
        ld a,(hl)
        or a
        jr z,.list
        inc hl
        cp #22
        jr nz,.quote
        ld de,pwd
        ld b,PWD_MAX
.copy:
        ld a,(hl)
        or a
        jr z,.end
        cp #22
        jr z,.end
        ld (de),a
        inc hl
        inc de
        djnz .copy
.end:
        xor a
        ld (de),a
.list:
        ld a,J_LIST
        ; fall through
; A = the job: PASV for it
pasv:
        ld (job),a
        or a                        ; a new list: from its start
        jr nz,.not_list
        ld (n_ent),a
        ld (sel),a
        ld (l_top),a
.not_list:
        xor a
        ld (x_ctl),a
        ld (x_dat),a
        ld (x_big),a
        ld hl,0
        ld (d_len),hl
        ld hl,s_pasv
        ld de,empty
        ld a,C_PASV
        jp ctl_say

; 227 ... (h1,h2,h3,h4,p1,p2): the data connection, to the control
; connection's ip and that port
ctl_pasv:
        ld de,227
        call is_code
        jp nz,ctl_err
        ld hl,(line)
        inc hl
        inc hl
        inc hl
.find:
        ld a,(hl)                   ; its first number (after "(")
        or a
        jp z,ctl_err
        sub "0"
        cp 10
        jr c,.numbers
        inc hl
        jr .find
.numbers:
        ld b,4                      ; past h1..h4 (their ip is not used:
.skip:                              ; behind a router it is often not the
        call net_number             ; one to connect to)
        jp c,ctl_err
        inc hl
        djnz .skip
        call net_number             ; p1, p2
        jp c,ctl_err
        ld a,e
        ld (d_port + 1),a
        inc hl
        call net_number
        jp c,ctl_err
        ld a,e
        ld (d_port),a
        ld de,d_addr                ; "a.b.c.d:port"
        ld hl,c_ctl + NC_IP + 3
        ld b,4
.part:
        push bc
        push hl
        ld l,(hl)
        ld h,0
        call decimal
        pop hl
        pop bc
        dec hl
        ld a,"."
        ld (de),a
        inc de
        djnz .part
        dec de
        ld a,":"
        ld (de),a
        inc de
        ld hl,(d_port)
        call decimal
        xor a
        ld (de),a
        ld a,(job)                  ; LIST a line at a time, files as
        or a                        ; bytes
        ld a,0
        jr z,.raw
        inc a
.raw:
        ld (c_dat + NC_RAW),a
        ld ix,c_dat
        ld hl,d_addr
        ld de,20
        call net_open
        jp c,ctl_err
        ld a,C_X150                 ; (the command when it is connected)
        ld (c_state),a
        ret

; 150 or 125: it comes (or goes)
ctl_x150:
        call first_digit
        cp "1"
        jp nz,ctl_err
        ld a,C_XFER
        ld (c_state),a
        ret

; 226: all sent
ctl_xfer:
        call first_digit
        cp "2"
        jp nz,ctl_err
        ld a,1
        ld (x_ctl),a
        jp x_done

; 250: the folder changed: its list
ctl_cwd:
        call first_digit
        cp "2"
        jp nz,ctl_err
        jp pwd_list

; 250: deleted: the list again
ctl_dele:
        call first_digit
        cp "2"
        jp nz,ctl_err
        ld a,J_LIST
        jp pasv

; ---------------------------------------------------------------------
; the data connection
; ---------------------------------------------------------------------
; A = net_poll's event: HL -> the line (LIST), or bytes (BC, RETR)
dat_event:
        cp NE_CONNECTED
        jr z,.connected
        cp NE_LINE
        jp z,entry
        cp NE_DATA
        jr z,.data
        cp NE_CLOSED
        jr z,.closed
        call ne_text                ; no connection: the list as it was
        push af
        ld a,C_IDLE
        ld (c_state),a
        pop af
        jp say_top
.closed:                            ; it ended
        ld a,1
        ld (x_dat),a
        jp x_done
.connected:                         ; the command for the job now
        ld a,(job)
        or a
        ld hl,s_list
        ld de,empty
        ld b,T_LISTING
        jr z,.say
        dec a
        ld hl,s_retr
        ld de,r_name
        ld b,T_GETTING
        jr z,.say
        ld hl,s_stor
        ld b,T_PUTTING
.say:
        push bc
        ld a,C_X150
        call ctl_say
        pop af
        jp say_top
.data:
        ld a,(x_big)                ; over FILE_MAX: left out
        or a
        ret nz
        push hl
        ld hl,(d_len)
        add hl,bc
        ld de,FILE_MAX + 1
        push hl
        or a
        sbc hl,de
        pop de
        pop hl
        jr nc,.big
        push de
        push bc
        ld de,(d_len)               ; into the bank
        ex de,hl
        ld bc,DATA
        add hl,bc
        ex de,hl
        pop bc
        call VOS_BANK_PUT
        pop hl
        ld (d_len),hl
        ld a,T_GETTING
        jp say_bytes
.big:
        ld a,1
        ld (x_big),a
        ld ix,c_dat
        call net_close
        ld a,1
        ld (x_dat),a
        ret

; a line of LIST: Unix ("drwxr-xr-x 2 u g 4096 Nov 1 10:00 name") or
; DOS ("11-01-26 10:00AM <DIR> name"), into the list
entry:
        ld a,(n_ent)
        cp MAX_ENT
        ret nc
        ld a,(hl)
        cp "d"
        jr z,.unix
        cp "l"
        jr z,.unix
        cp "-"
        jr z,.unix
        sub "0"
        cp 10
        ret nc
        ld c,0                      ; DOS: a date, a time
        call skip_field
        call skip_field
        ld a,(hl)
        cp "<"
        jr nz,.dos_file
        inc c
.dos_file:
        ld (size_at),hl
        call skip_field
        jr .name
.unix:
        ld c,0
        cp "-"
        jr z,.file
        inc c
.file:
        ld b,4
.fields:
        call skip_field
        djnz .fields
        ld (size_at),hl
        ld b,4
.more:
        call skip_field
        djnz .more
.name:
        ld a,(hl)
        or a
        ret z
        ld (name_at),hl
        ld a,(n_ent)
        push bc
        call ent_at
        pop bc
        ld (hl),c                   ; 1: a folder
        inc hl
        ex de,hl
        ld hl,(name_at)             ; the name (a link's up to " -> ")
        ld b,NAME_MAX
.char:
        ld a,(hl)
        or a
        jr z,.named
        cp " "
        jr nz,.put
        inc hl
        ld a,(hl)
        dec hl
        cp "-"
        ld a," "
        jr z,.named
.put:
        ld (de),a
        inc hl
        inc de
        djnz .char
.named:
        xor a
        ld (de),a
        ld a,(n_ent)                ; its size, on the right, or <DIR>
        call ent_at
        ld a,(hl)
        ld de,1 + NAME_MAX + 1
        add hl,de
        ex de,hl
        ld h,d
        ld l,e
        ld b,SIZE_W
.blank:
        ld (hl)," "
        inc hl
        djnz .blank
        ld (hl),0
        or a
        jr z,.size
        push de
        ld a,T_DIR
        call VOS_MSG
        pop de
        inc de                      ; (to the right, as the sizes)
        inc de
        inc de
        inc de
        ld bc,5
        ldir
        jr .counted
.size:
        ld hl,(size_at)             ; its digits, to the right
        ld b,0
.len:
        ld a,(hl)
        sub "0"
        cp 10
        jr nc,.length
        inc hl
        inc b
        jr .len
.length:
        ld a,b
        or a
        jr z,.counted
        cp SIZE_W
        jr c,.fits
        ld b,SIZE_W
.fits:
        ld a,SIZE_W
        sub b
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        ld hl,(size_at)
        ld c,b
        ld b,0
        ldir
.counted:
        ld hl,n_ent
        ld b,(hl)
        inc (hl)
        ld a,b                      ; shown, if it is in view
        ld hl,l_top
        sub (hl)
        cp ROWS
        ret nc
        ld b,a
        jp draw_row

; HL -> a field: HL -> the next one
skip_field:
        ld a,(hl)
        or a
        ret z
        cp " "
        jr z,.spaces
        inc hl
        jr skip_field
.spaces:
        ld a,(hl)
        cp " "
        ret nz
        inc hl
        jr .spaces

; the transfer's end: both connections said so -> the job done
x_done:
        ld a,(x_ctl)
        or a
        ret z
        ld a,(x_dat)
        or a
        ret z
        ld ix,c_dat
        call net_close
        ld a,C_IDLE
        ld (c_state),a
        ld a,(job)
        or a
        jr nz,.not_list
        ld a,(after)                ; the list: the folder shown, or how
        ld (said),a                 ; much was sent
        or a
        jr z,.folder
        xor a
        ld (after),a
        ld hl,(after_n)
        ld de,info
        call decimal
        xor a
        ld (de),a
        jp redraw
.folder:
        ld hl,pwd
        call set_info
        jp redraw
.not_list:
        dec a
        jr nz,.stored
        ld a,(x_big)                ; RETR: saved
        or a
        ld a,T_TOO_BIG
        jp nz,say_top
        ld a,(f_drive)
        or VOS_DATA
        ld hl,fname
        ld de,DATA
        ld bc,(d_len)
        call VOS_SAVE
        jr c,.error
        ld hl,(d_len)
        ld a,T_SAVED
        jp say_bytes
.error:
        call VOS_ERROR
        jp redraw
.stored:
        ld hl,(s_len)               ; STOR: the list again, then how
        ld (after_n),hl             ; much was sent
        ld a,T_SENT
        ld (after),a
        ld a,J_LIST
        jp pasv

; STOR, each frame the M4 is not sending: PIECE bytes, then closed
send_piece:
        ld a,(x_dat)
        or a
        ret nz
        ld ix,c_dat
        call net_ready
        ret c
        ld hl,(s_len)
        ld de,(s_pos)
        or a
        sbc hl,de
        jr z,.end
        ld bc,PIECE
        push hl
        sbc hl,bc
        pop hl
        jr nc,.full
        ld b,h
        ld c,l
.full:
        push bc
        ld hl,(s_pos)
        push hl
        add hl,bc
        ld (s_pos),hl
        pop hl
        ld de,DATA
        add hl,de
        ld de,sbuf
        call VOS_BANK_GET
        pop bc
        ld hl,sbuf
        ld ix,c_dat
        jp net_send
.end:
        ld ix,c_dat
        call net_close
        ld a,1
        ld (x_dat),a
        jp x_done

; ---------------------------------------------------------------------
; commands
; ---------------------------------------------------------------------
command:
        cp CMD_CONNECT
        jp z,connect
        cp CMD_CLOSE
        jr nz,.not_close
        call close_all
        xor a
        ld (said),a
        ld (n_ent),a
        ld (info),a
        jp redraw
.not_close:
        cp CMD_GET
        jp z,get
        cp CMD_PUT
        jp z,put
        cp CMD_DELETE
        jp z,delete
        cp CMD_UP
        jr z,go_up
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,f_drive
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
        call close_all
        jp VOS_EXIT

; -> NZ: not logged in, or busy
idle:
        ld a,(c_state)
        cp C_IDLE
        ret

; UP A FOLDER (DEL): CDUP
go_up:
        call idle
        ret nz
        ld hl,s_cdup
        ld de,empty
        ld a,C_CWD
        jp ctl_say

; RETURN: a folder opened (CWD), or a file got
open:
        call idle
        ret nz
        call chosen
        ret c
        ld a,(hl)
        or a
        jr z,get
        inc hl
        ex de,hl
        ld hl,s_cwd
        ld a,C_CWD
        jp ctl_say

; -> HL -> the entry chosen; carry: none
chosen:
        ld a,(n_ent)
        or a
        scf
        ret z
        ld a,(sel)
        call ent_at
        or a
        ret

; GET THE FILE: its name here, then PASV and RETR
get:
        call idle
        ret nz
        call chosen
        ret c
        ld a,(hl)
        or a
        ret nz                      ; (a folder)
        inc hl
        push hl
        ld de,r_name
        call copy_z
        pop hl
        call short_name
        ld a,T_NAME_T
        ld hl,name_in
        ld c,12
        call VOS_INPUT
        jp c,redraw
        call make_name
        jp c,redraw
        call redraw
        ld a,J_RETR
        jp pasv

; PUT A FILE: one of f_drive's, into the bank, then PASV and STOR
put:
        call idle
        ret nz
        ld a,(f_drive)
        call VOS_CATALOG
        jr c,.error
        or a
        jr nz,.pick
        ld hl,dlg_no_files
        jp VOS_DIALOG
.error:
        jp VOS_ERROR
.pick:
        ld (cat),hl
        ld a,T_PICK_T
        call VOS_FILE_PICK
        jp c,redraw
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
        ld a,(f_drive)
        or VOS_DATA
        ld hl,fname
        ld de,DATA
        call VOS_LOAD
        jr c,.error
        ld (s_len),bc
        ld hl,0
        ld (s_pos),hl
        ld hl,fname                 ; its name there: "NAME.EXT"
        ld de,r_name
        ld b,8
        call .part
        ld a,(fname + 8)
        cp " "
        jr z,.named
        ld a,"."
        ld (de),a
        inc de
        ld b,3
        call .part
.named:
        xor a
        ld (de),a
        call redraw
        ld a,J_STOR
        jp pasv
.part:                              ; B characters, without the spaces
        ld a,(hl)
        inc hl
        cp " "
        jr z,.next
        ld (de),a
        inc de
.next:
        djnz .part
        ret

; DELETE THE FILE: DELE, after asking
delete:
        call idle
        ret nz
        call chosen
        ret c
        ld a,(hl)
        or a
        ret nz
        push hl
        ld hl,dlg_del
        call VOS_DIALOG
        pop hl
        or a
        jp nz,redraw
        inc hl
        ex de,hl
        ld hl,s_dele
        ld a,C_DELE
        call ctl_say
        jp redraw

; HL -> a server's name -> name_in: 8.3 (the part before the first
; ".", 8 at most; the part after the last, 3 at most)
short_name:
        ld de,name_in
        ld b,8
.base:
        ld a,(hl)
        or a
        jr z,.end
        cp "."
        jr z,.ext
        ld (de),a
        inc de
        inc hl
        djnz .base
.ext:
        ld bc,0                     ; the last "."
.find:
        ld a,(hl)
        or a
        jr z,.found
        cp "."
        jr nz,.on
        ld b,h
        ld c,l
.on:
        inc hl
        jr .find
.found:
        ld a,b
        or c
        jr z,.end
        ld h,b
        ld l,c
        ld b,4
.copy:
        ld a,(hl)
        or a
        jr z,.end
        ld (de),a
        inc de
        inc hl
        djnz .copy
.end:
        xor a
        ld (de),a
        ret

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
        cp "a"
        jr c,.cap
        cp "z" + 1
        jr nc,.cap
        sub 32
.cap:
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

; HL -> text, 0 -> DE: copied, DE at its 0
copy_z:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr copy_z

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
menu:           db T_MENU, 10
                db T_CONNECT, CMD_CONNECT, "O", 0
                db T_CLOSE, CMD_CLOSE, "K", 0
                db T_GET, CMD_GET, "G", 0
                db T_PUT, CMD_PUT, "P", 0
                db T_DELETE, CMD_DELETE, "D", 0
                db T_UP, CMD_UP, "U", 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_del:        db T_MENU, T_DEL_Q, 2, VM_YES, VM_NO
dlg_no_files:   db T_MENU, T_NO_FILES, 1, VM_OK
tens:           dw 10000, 1000, 100, 10, 1, 0
s_anon:         db "anonymous", 0
s_anon_pass:    db "vos@cpc", 0
s_user:         db "USER ", 0
s_pass:         db "PASS ", 0
s_type:         db "TYPE I", 0
s_pwd:          db "PWD", 0
s_pasv:         db "PASV", 0
s_list:         db "LIST", 0
s_retr:         db "RETR ", 0
s_stor:         db "STOR ", 0
s_cwd:          db "CWD ", 0
s_cdup:         db "CDUP", 0
s_dele:         db "DELE ", 0
s_quit:         db "QUIT", 0
empty:          db 0
blank:          ds COLS, " "
                db 0

        include "app_texts.asm"     ; T_*, texts, from texts.txt

f_drive:        db 0
said:           db 0                ; a text instead of the state's
c_state:        db C_NONE
job:            db J_LIST
x_ctl:          db 0                ; 1: the control connection said 226
x_dat:          db 0                ; 1: the data connection ended
x_big:          db 0                ; 1: RETR over FILE_MAX
after:          db 0                ; said after the next list
after_n:        dw 0
c_quiet:        dw 0
handler:        dw 0
poll_ix:        dw 0
poll_n:         db 0
line:           dw 0
rcode:          dw 0
name_at:        dw 0
size_at:        dw 0
d_len:          dw 0
d_port:         dw 0
s_len:          dw 0
s_pos:          dw 0
cat:            dw 0
n_ent:          db 0
sel:            db 0
l_top:          db 0
name_in:        ds 14
fname:          ds 11
info:           ds INFO_MAX + 1
addr:           ds FIELD
user:           ds FIELD
pass:           ds FIELD
pwd:            ds PWD_MAX + 1
r_name:         ds NAME_MAX + 4
d_addr:         ds 24
out_buf:        ds FIELD + 8
row_buf:        ds COLS + 1
sbuf:           ds PIECE
c_ctl:          ds NC_SIZE
c_dat:          ds NC_SIZE
ents:           ds MAX_ENT * E_SIZE
