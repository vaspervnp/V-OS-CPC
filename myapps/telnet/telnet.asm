; =====================================================================
; telnet.asm - TELNET, text over the network with the M4 board (made
; with the SDK)
;
; Mode 1. CONNECT ^O asks for HOST:PORT (a name, or an address as
; 192.168.1.10; without a port 23) and opens a TCP connection through
; the M4 board's sockets (C_NETHOSTIP, C_NETSOCKET, C_NETCONNECT with
; VX_M4; their state from the ROM's sock_info, VX_M4 with HL = 0, API
; 32). What comes is written in the window, scrolling up at its end:
; CR LF, TAB and backspace as on a terminal, ANSI escape sequences left
; out, the letters over 160 as the V-OS set has them (ISO 8859-7 for
; Greek); the telnet options asked for are refused (DO: WONT, WILL:
; DONT). The line typed at the bottom goes with RETURN, with CR LF.
; CLOSE ^D ends it, as the other end may.
;   TELNET menu: CONNECT ^O, CLOSE ^D, CLEAR THE SCREEN, ABOUT, BACK ^Q
;   make app NAME=telnet      build/TELNET.BIN, on build/apps.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 0               ; pens (palette below)
INK             equ 1
HEAD            equ 3
COLS            equ 48
ROWS            equ 20
TOP_Y           equ 14
TEXT_Y          equ 28
ROW_H           equ 10
IN_Y            equ TEXT_Y + ROWS * ROW_H + 4
HINT_Y          equ 249
IN_MAX          equ COLS - 3        ; the line typed
ADDR_MAX        equ 40
PIECE           equ 128             ; C_NETRECV: at most this a frame
WAIT_FRAMES     equ 500             ; 10 seconds for a name or a connection

C_NETSOCKET     equ #4331           ; the M4 board's network
C_NETCONNECT    equ #4332
C_NETCLOSE      equ #4333
C_NETSEND       equ #4334
C_NETRECV       equ #4335
C_NETHOSTIP     equ #4336
S_IDLE          equ 0               ; sock_info: a socket's status
S_CONNECTING    equ 1
S_CLOSED        equ 3
S_LOOKUP        equ 5
S_ERROR         equ 240

ST_CLOSED       equ 0               ; state
ST_LOOKUP       equ 1
ST_CONNECTING   equ 2
ST_CONNECTED    equ 3

IAC             equ 255             ; telnet: a command, then
WILL            equ 251
WONT            equ 252
DO              equ 253
DONT            equ 254

CMD_CONNECT     equ VC_APP + 1      ; menu items: commands
CMD_CLOSE       equ VC_APP + 2
CMD_CLEAR       equ VC_APP + 3
CMD_ABOUT       equ VC_APP + 4
CMD_BACK        equ VC_APP + 5

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
        call clear
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
        call draw_input
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

; the window empty
clear:
        ld hl,screen
        ld de,screen + 1
        ld bc,ROWS * (COLS + 1) - 1
        ld (hl)," "
        ldir
        ld hl,screen + COLS         ; a 0 after each row
        ld de,COLS + 1
        ld b,ROWS
.end:
        ld (hl),0
        add hl,de
        djnz .end
        xor a
        ld (col),a
        ret

; ---------------------------------------------------------------------
; the screen
; ---------------------------------------------------------------------
; the state, and the address
draw_top:
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
        ld a,(state)
        ld e,a
        ld d,0
        ld hl,state_texts
        add hl,de
        ld a,(said)                 ; or what went wrong
        or a
        jr nz,.text
        ld a,(hl)
.text:
        ld hl,0
        ld de,TOP_Y
        call print_msg
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld hl,22 * 8
        ld de,TOP_Y
        ld bc,addr
        jp VOS_PRINT

; every row of the window
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

; B = a row of the window: drawn
draw_row:
        ld a,INK
        ld c,BG
        push bc
        call VOS_COLOURS
        pop bc
        ld a,b
        call row_at
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

; A = row -> HL -> its text
row_at:
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; * 16
        push hl
        add hl,hl                   ; * 32
        pop de
        add hl,de                   ; * 48
        ld e,a
        ld d,0
        add hl,de                   ; * 49
        ld de,screen
        add hl,de
        ret

; "> " and the line typed, a cursor after it
draw_input:
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
        ld hl,in_line - 2
        ld (hl),">"
        inc hl
        ld (hl)," "
        ld a,(in_n)
        ld e,a
        ld d,0
        ld hl,in_line
        add hl,de
        ld (hl),"_"
        inc hl
        ld a,IN_MAX                 ; spaces over what was there
        sub e
        jr z,.end
        ld b,a
.space:
        ld (hl)," "
        inc hl
        djnz .space
.end:
        ld (hl),0
        ld hl,0
        ld de,IN_Y
        ld bc,in_line - 2
        jp VOS_PRINT

; ---------------------------------------------------------------------
; text in the window
; ---------------------------------------------------------------------
; A = a byte from the network: telnet's commands, ANSI's sequences,
; then the text
take:
        ld c,a
        ld a,(t_state)
        or a
        jr z,.text
        dec a
        jr nz,.not_iac
        ld a,c                      ; after IAC: its verb
        cp IAC
        jr z,.text_iac              ; IAC IAC: a byte 255
        ld (t_verb),a
        cp WILL
        jr c,.done                  ; a command without an option
        ld a,2
        ld (t_state),a
        ret
.not_iac:
        dec a
        jr nz,.ansi
        xor a                       ; the option: refused
        ld (t_state),a
        ld a,(t_verb)
        ld b,WONT
        cp DO
        jr z,.refuse
        ld b,DONT
        cp WILL
        ret nz
.refuse:
        ld hl,send_data
        ld (hl),IAC
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        ld bc,3
        jp send
.ansi:                              ; ESC [ ...: up to a letter
        ld a,c
        cp "@"
        ret c
        cp "["
        ret z
.done:
        xor a
        ld (t_state),a
        ret
.text_iac:
        xor a
        ld (t_state),a
        ret
.text:
        ld a,c
        cp IAC
        jr nz,.not_cmd
        ld a,1
        ld (t_state),a
        ret
.not_cmd:
        cp 27
        jr nz,.not_esc
        ld a,3
        ld (t_state),a
        ret
.not_esc:
        cp 10
        jr z,new_line
        cp 13
        jr z,.cr
        cp 8
        jr z,.back
        cp 9
        jr z,.tab
        cp " "
        ret c
        cp 127
        jr c,put
        cp 160
        ret c
        jr put
.cr:
        xor a
        ld (col),a
        ret
.back:
        ld hl,col
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret
.tab:
        ld a," "
        call put
        ld a,(col)
        and 7
        jr nz,.tab
        ret

; A = a character at the last row's col, the col on (a new line at the
; end of the row)
put:
        push af
        ld a,(col)
        cp COLS
        call nc,new_line
        ld a,ROWS - 1
        call row_at
        ld a,(col)
        ld e,a
        ld d,0
        add hl,de
        pop af
        ld (hl),a
        ld hl,col
        inc (hl)
        ld hl,dirty                 ; the last row, unless all already
        ld a,(hl)
        or a
        ret nz
        inc (hl)
        ret

; all rows a row up, the last empty
new_line:
        ld hl,screen + COLS + 1
        ld de,screen
        ld bc,(ROWS - 1) * (COLS + 1)
        ldir
        ld h,d
        ld l,e
        ld b,COLS
.space:
        ld (hl)," "
        inc hl
        djnz .space
        xor a
        ld (col),a
        ld a,2
        ld (dirty),a
        ret

; ---------------------------------------------------------------------
; the M4 board
; ---------------------------------------------------------------------
; cmd: a command of C bytes of data (after its code) -> resp; carry: no
; M4 board
m4:
        ld a,c
        add a,2
        ld (cmd),a
        ld hl,cmd
        ld de,resp
        ld bc,6 + PIECE
        ld a,VX_M4
        jp VOS_EXT

; HL = command: its code in cmd -> DE -> its data
m4_cmd:
        ld (cmd + 1),hl
        ld de,cmd + 3
        ret

; -> HL -> the state of sock (or of socket 0 while a name is looked
; up) in socks: status, last command, dw bytes received, ip, port;
; carry: no M4 board
sock_state:
        ld bc,5 * 16
        ld hl,0
        ld de,socks
        ld a,VX_M4
        call VOS_EXT
        ret c
        ld hl,socks - 16
        ld a,(sock)
        ld e,a
        ld a,(t_query)
        or a
        jr z,.ours
        ld e,0                      ; (socket 0: the name looked up)
.ours:
        inc e
        ld d,0
.at:
        ld bc,16
        add hl,bc
        dec e
        jr nz,.at
        ret

; CONNECT: the address asked for, then looked up or connected to
connect:
        call close
        ld a,T_ADDR_T
        ld hl,addr
        ld c,ADDR_MAX
        call VOS_INPUT
        ret c
        xor a
        ld (said),a
        ld (t_query),a
        call parse_addr
        jp nc,open_sock
        ld a,1                      ; a name: looked up first, on
        ld (t_query),a              ; socket 0
        ld hl,C_NETHOSTIP
        call m4_cmd
        ld hl,addr
        ld c,0
.copy:
        ld a,(hl)
        or a
        jr z,.copied
        cp ":"
        jr z,.copied
        ld (de),a
        inc hl
        inc de
        inc c
        jr .copy
.copied:
        xor a
        ld (de),a
        inc c
        call m4
        jr c,no_m4
        ld a,(resp + 3)
        cp 1                        ; 1: in progress
        jr nz,failed
        ld a,ST_LOOKUP
        jr waiting

no_m4:
        ld a,T_NO_M4
        jr say
failed:
        ld a,T_FAILED
say:
        ld (said),a
        ld a,ST_CLOSED
        ld (state),a
        jp redraw

; A = state: waiting for it, WAIT_FRAMES at most
waiting:
        ld (state),a
        ld hl,WAIT_FRAMES
        ld (wait),hl
        jp redraw

; a socket, connected to ip:port -> ST_CONNECTING (or what went wrong
; said)
open_sock:
        ld hl,C_NETSOCKET
        call m4_cmd
        ex de,hl
        ld (hl),0                   ; TCP
        inc hl
        ld (hl),0
        inc hl
        ld (hl),6
        ld c,3
        call m4
        jr c,no_m4
        ld a,(resp + 3)
        cp #FF
        jr z,failed
        ld (sock),a
        ld hl,C_NETCONNECT
        call m4_cmd
        ld a,(sock)
        ld (de),a
        inc de
        ld hl,ip                    ; the ip, low byte first, the port
        ld bc,6
        ldir
        ld c,7
        call m4
        jr c,no_m4
        ld a,(resp + 3)
        or a
        jr nz,failed
        ld a,ST_CONNECTING
        jr waiting

; CLOSE: the socket closed, if it is open
close:
        ld a,(state)
        cp ST_CONNECTING
        jr c,.closed
        ld hl,C_NETCLOSE
        call m4_cmd
        ld a,(sock)
        ld (de),a
        ld c,1
        call m4
.closed:
        ld a,ST_CLOSED
        ld (state),a
        ret

; addr -> ip (4 bytes, the last first) and port (23 if none); carry:
; not an address of numbers (a name)
parse_addr:
        ld hl,23
        ld (port),hl
        ld hl,addr
        ld b,4
.part:
        call number
        ret c
        ld a,d                      ; up to 255
        or a
        scf
        ret nz
        push hl
        ld hl,ip - 1                ; the first part goes last
        ld e,b
        ld d,0
        add hl,de
        ld a,(num)
        ld (hl),a
        pop hl
        ld a,(hl)
        dec b
        jr z,.port
        cp "."
        scf
        ret nz
        inc hl
        jr .part
.port:
        or a
        ret z
        cp ":"
        scf
        ret nz
        inc hl
        call number
        ret c
        ld (port),de
        ret

; HL -> digits -> DE = num = their number, HL after them; carry: none
number:
        ld de,0
        ld a,(hl)
        sub "0"
        cp 10
        ccf
        ret c
.digit:
        ld a,(hl)
        sub "0"
        cp 10
        jr nc,.end
        push hl
        ld h,d
        ld l,e
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        jr .digit
.end:
        ld a,e
        ld (num),a
        or a
        ret

; send_data, BC bytes -> the socket
send:
        push bc
        ld hl,C_NETSEND
        call m4_cmd
        ld a,(sock)
        ld (de),a
        inc de
        pop bc
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        inc de
        ld hl,send_data
        push bc
        ldir
        pop bc
        ld a,c
        add a,3
        ld c,a
        jp m4

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        ld a,(hl)
        cp VE_FRAME
        jr z,frame
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
        ld c,(hl)
        ld a,b
        cp VK_RETURN
        jr z,send_line
        cp VK_ENTER
        jr z,send_line
        cp VK_DEL
        jr z,.del
        ld a,c                      ; a character typed
        cp " "
        ret c
        ld hl,in_n
        ld a,(hl)
        cp IN_MAX
        ret nc
        inc (hl)
        ld e,a
        ld d,0
        ld hl,in_line
        add hl,de
        ld (hl),c
        jp draw_input
.del:
        ld hl,in_n
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jp draw_input

; RETURN: the line typed, with CR LF, to the other end
send_line:
        ld a,(state)
        cp ST_CONNECTED
        ret nz
        ld hl,in_line
        ld de,send_data
        ld a,(in_n)
        ld c,a
        ld b,0
        or a
        jr z,.empty
        ldir
.empty:
        ex de,hl
        ld (hl),13
        inc hl
        ld (hl),10
        ld a,(in_n)
        add a,2
        ld c,a
        ld b,0
        call send
        xor a
        ld (in_n),a
        jp draw_input

; every frame: a name or a connection waited for, what came drawn
frame:
        ld a,(state)
        or a
        ret z
        ld a,#FF                    ; behind and covered, VOS_EXT does
        ld (socks),a                ; nothing (WM.SYS): socks as they
        call sock_state             ; were, nothing to do now
        jp c,no_m4
        ld a,(socks)
        inc a
        ret z
        ld a,(state)
        cp ST_CONNECTED
        jr z,.receive
        ld a,(hl)                   ; waiting: still?
        cp S_LOOKUP
        jr z,.wait
        cp S_CONNECTING
        jr z,.wait
        cp S_ERROR
        jr nc,.error
        ld a,(state)
        cp ST_LOOKUP
        jr nz,.connected
        ld de,4                     ; the name's ip, from socket 0
        add hl,de
        ld de,ip
        ld bc,4
        ldir
        xor a
        ld (t_query),a
        call parse_port
        call open_sock
        ret
.connected:
        ld a,ST_CONNECTED
        ld (state),a
        xor a
        ld (t_state),a
        jp redraw
.wait:
        ld hl,(wait)
        dec hl
        ld (wait),hl
        ld a,h
        or l
        ret nz
.error:
        call close
        jp failed
.receive:
        push hl
        inc hl
        inc hl
        ld a,(hl)                   ; anything received?
        inc hl
        or (hl)
        pop hl
        jr nz,.get
        ld a,(hl)                   ; no: closed by the other end?
        cp S_CLOSED
        ret nz
        call close
        ld a,T_CLOSED
        jp say
.get:
        ld hl,C_NETRECV
        call m4_cmd
        ld a,(sock)
        ld (de),a
        inc de
        ld a,PIECE
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld c,3
        call m4
        ret c
        ld a,(resp + 3)
        or a
        ret nz
        ld bc,(resp + 4)            ; what came, at most PIECE
        ld a,b
        or a
        jr nz,.most
        ld a,c
        cp PIECE + 1
        jr c,.count
.most:
        ld c,PIECE
.count:
        ld a,c
        or a
        ret z
        xor a
        ld (dirty),a
        ld b,0                      ; (a reply to telnet sent from take
        push bc                     ; would write over resp)
        ld hl,resp + 6
        ld de,rx
        ldir
        pop bc
        ld hl,rx
.byte:
        push bc
        push hl
        ld a,(hl)
        call take
        pop hl
        pop bc
        inc hl
        dec c
        jr nz,.byte
        ld a,(dirty)                ; drawn again: the last row, or all
        or a
        ret z
        dec a
        jp nz,draw_rows
        ld b,ROWS - 1
        jp draw_row

; the port after addr's ":" (or 23)
parse_port:
        ld hl,23
        ld (port),hl
        ld hl,addr
.find:
        ld a,(hl)
        or a
        ret z
        inc hl
        cp ":"
        jr nz,.find
        call number
        ret c
        ld (port),de
        ret

; A = command
command:
        cp CMD_CONNECT
        jp z,connect
        cp CMD_CLOSE
        jr nz,.not_close
        call close
        xor a
        ld (said),a
        jp redraw
.not_close:
        cp CMD_CLEAR
        jr nz,.not_clear
        call clear
        jp redraw
.not_clear:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        call close
        jp VOS_EXIT

; ---- data -----------------------------------------------------------
win:            db 0                ; 1: in a window (VX_WINDOW)
wsize:          dw 376, 232, 0, 12 ; its w, h, and from x0, y0

palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 0
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 6
                db T_CONNECT, CMD_CONNECT, "O", 0
                db T_CLOSE, CMD_CLOSE, "D", 0
                db T_CLEAR, CMD_CLEAR, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
state_texts:    db T_CLOSED, T_LOOKING, T_CONNECTING, T_CONNECTED

        include "app_texts.asm"     ; T_*, texts, from texts.txt

state:          db ST_CLOSED
said:           db 0                ; a text instead of the state's
sock:           db 0
t_query:        db 0                ; 1: the state of socket 0 (a name)
t_state:        db 0                ; 1 IAC, 2 its option, 3 ESC [ ...
t_verb:         db 0
wait:           dw 0
col:            db 0                ; on the last row
dirty:          db 0                ; 1: the last row, 2: all
num:            db 0
ip:             ds 4                ; for C_NETCONNECT: the ip, the port
port:           dw 23
in_n:           db 0
                ds 2                ; "> "
in_line:        ds IN_MAX + 2
addr:           ds ADDR_MAX + 2
cmd:            ds 3 + 3 + PIECE
resp:           ds 6 + PIECE
send_data:      ds IN_MAX + 2
socks:          ds 5 * 16
rx:             ds PIECE
screen:         ds ROWS * (COLS + 1)
