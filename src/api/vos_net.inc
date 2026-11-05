; =====================================================================
; vos_net.inc - TCP connections through the M4 board, for a program's
; own protocols (MAIL's POP3 and SMTP, FTP): included with the
; program's code (after vos_api.inc). As TELNET does it (VX_M4, API 32:
; C_NETHOSTIP, C_NETSOCKET, C_NETCONNECT, C_NETSEND, C_NETRECV,
; C_NETCLOSE and the ROM's sock_info), but for any number of
; connections at once (one name looked up at a time), what comes a line
; at a time or as bytes. A connection is NC_SIZE bytes of the
; program's, at IX, all 0 at first (closed).
;
; net_open: IX, HL -> "name", "name:port", "1.2.3.4" or "1.2.3.4:port"
;   (0 at its end), DE = the port when it has none -> the name looked
;   up, then connected: net_poll says when. Carry, A = NE_NO_M4 or
;   NE_FAILED: not (closed).
; net_poll: IX, at each VE_FRAME; again while it is not NE_NONE (a few
;   times a frame) -> A = what happened:
;   NE_NONE      nothing now (or behind and covered: VOS_EXT quiet)
;   NE_CONNECTED connected
;   NE_LINE      HL -> a line received, 0 at its end, without its CR LF;
;                B = its length. A line longer than NET_LINE_MAX comes
;                in pieces: net_long = 1 for all but the last
;   NE_DATA      (NC_RAW set) HL -> bytes received, BC = how many
;   NE_CLOSED    closed by the other end (closed now; its last line
;                without an LF came before)
;   NE_FAILED    no connection (the name, or the address answers
;                nothing in 10 seconds); closed
;   NE_NO_M4     no M4 board; closed
; net_send: IX, HL -> bytes, BC = how many (NET_SEND_MAX at most)
; net_say: IX, HL -> a line, 0 at its end: sent with CR LF
; net_ready: IX -> carry: still sending (more should wait a frame)
; net_close: IX: closed, if it was open
; net_reply: HL -> a line of an SMTP or FTP reply -> carry: not its
;   last line ("250-..."); else DE = its number (250), HL after it
; net_number: HL -> digits -> DE = their number, HL after them; carry:
;   no digit
; =====================================================================

NC_STATE        equ 0               ; a connection: NS_*
NC_SOCK         equ 1               ; its socket
NC_WAIT         equ 2               ; dw frames left to wait
NC_IP           equ 4               ; the ip (the last part first) and
NC_PORT         equ 8               ; the port, as C_NETCONNECT has them
NC_RAW          equ 10              ; 1: bytes (NE_DATA), not lines
NC_RXN          equ 11              ; bytes left in NC_RX
NC_RXAT         equ 12              ; the next of them
NC_LN           equ 13              ; the line so far
NC_STATUS       equ 14              ; its socket's status, last seen
NC_RX           equ 16              ; NET_PIECE bytes received
NC_LINE         equ NC_RX + NET_PIECE ; the line, NET_LINE_MAX + 1
NC_SIZE         equ NC_LINE + NET_LINE_MAX + 2

NET_PIECE       equ 128             ; C_NETRECV: at most this at a time
NET_LINE_MAX    equ 160
NET_SEND_MAX    equ 240
NET_WAIT_FRAMES equ 500             ; 10 seconds for a name, a connection

NS_CLOSED       equ 0               ; NC_STATE
NS_LOOKUP       equ 1
NS_CONNECTING   equ 2
NS_CONNECTED    equ 3

NE_NONE         equ 0               ; net_poll's events
NE_CONNECTED    equ 1
NE_LINE         equ 2
NE_DATA         equ 3
NE_CLOSED       equ 4
NE_FAILED       equ 5
NE_NO_M4        equ 6

NSS_CONNECTING  equ 1               ; sock_info: a socket's status
NSS_SENDING     equ 2
NSS_CLOSED      equ 3
NSS_LOOKUP      equ 5
NSS_ERROR       equ 240

NET_C_SOCKET    equ #4331           ; the M4 board's network
NET_C_CONNECT   equ #4332
NET_C_CLOSE     equ #4333
NET_C_SEND      equ #4334
NET_C_RECV      equ #4335
NET_C_HOSTIP    equ #4336

; ---------------------------------------------------------------------
net_open:
        push hl
        push de
        call net_close
        pop de
        pop hl
        ld (ix + NC_PORT),e
        ld (ix + NC_PORT + 1),d
        xor a
        ld (ix + NC_RXN),a
        ld (ix + NC_LN),a
        ld (ix + NC_STATUS),a
        push hl                     ; its port, after ":"
.find:
        ld a,(hl)
        or a
        jr z,.no_port
        inc hl
        cp ":"
        jr nz,.find
        call net_number
        jr c,.no_port
        ld (ix + NC_PORT),e
        ld (ix + NC_PORT + 1),d
.no_port:
        pop hl
        push hl
        call net_parse
        pop hl
        jr nc,net_connect
        ld de,(net_owner)           ; a name: looked up on socket 0,
        ld a,d                      ; one at a time
        or e
        jr nz,net_failed
        push hl
        ld hl,NET_C_HOSTIP
        call net_cmd_at
        pop hl
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
        ld a,c
        cp 64
        jr nc,net_failed
        jr .copy
.copied:
        xor a
        ld (de),a
        inc c
        call net_m4
        ld a,NE_NO_M4
        ret c
        ld a,(net_resp + 3)
        cp 1                        ; 1: in progress
        jr nz,net_failed
        ld (net_owner),ix
        ld a,NS_LOOKUP
        ; fall through
; A = the state, waited for (NET_WAIT_FRAMES at most)
net_wait:
        ld (ix + NC_STATE),a
        ld (ix + NC_WAIT),NET_WAIT_FRAMES & 255
        ld (ix + NC_WAIT + 1),NET_WAIT_FRAMES >> 8
        or a
        ret

net_failed:
        call net_close
        ld a,NE_FAILED
        scf
        ret

; a socket, connected to the ip and port -> NS_CONNECTING; carry, A:
; not
net_connect:
        ld hl,NET_C_SOCKET
        call net_cmd_at
        ex de,hl
        ld (hl),0                   ; TCP
        inc hl
        ld (hl),0
        inc hl
        ld (hl),6
        ld c,3
        call net_m4
        ld a,NE_NO_M4
        ret c
        ld a,(net_resp + 3)
        cp #FF
        jr z,net_failed
        ld (ix + NC_SOCK),a
        ld (ix + NC_STATE),NS_CONNECTING ; (closed again if it fails)
        ld hl,NET_C_CONNECT
        call net_cmd_at
        ld a,(ix + NC_SOCK)
        ld (de),a
        inc de
        push ix
        pop hl
        ld bc,NC_IP
        add hl,bc
        ld bc,6
        ldir
        ld c,7
        call net_m4
        ld a,NE_NO_M4
        jr c,.no_m4
        ld a,(net_resp + 3)
        or a
        jr nz,net_failed
        ld a,NS_CONNECTING
        jr net_wait
.no_m4:
        ld (ix + NC_STATE),NS_CLOSED
        scf
        ret

net_close:
        ld a,(ix + NC_STATE)
        cp NS_LOOKUP
        jr nz,.not_lookup
        ld hl,0                     ; (the M4 ends the lookup alone)
        ld (net_owner),hl
.not_lookup:
        cp NS_CONNECTING
        jr c,.closed
        ld hl,NET_C_CLOSE
        call net_cmd_at
        ld a,(ix + NC_SOCK)
        ld (de),a
        ld c,1
        call net_m4
.closed:
        ld (ix + NC_STATE),NS_CLOSED
        ret

; ---------------------------------------------------------------------
net_poll:
        ld a,(ix + NC_STATE)
        or a
        ret z
        cp NS_CONNECTED
        jp nz,.waiting
        ld a,(ix + NC_RXN)          ; the rest of what came first
        or a
        jp nz,net_lines
        ld e,(ix + NC_SOCK)
        call net_info
        jr c,.no_m4
        ret z
        ld a,(hl)
        ld (ix + NC_STATUS),a
        inc hl
        inc hl
        ld a,(hl)                   ; anything received?
        inc hl
        or (hl)
        jr nz,.get
        ld a,(ix + NC_STATUS)       ; no: closed by the other end?
        cp NSS_CLOSED
        ld a,NE_NONE
        ret nz
        ld a,(ix + NC_RAW)          ; its last line, without an LF
        or a
        jr nz,.closed
        ld a,(ix + NC_LN)
        or a
        jp nz,net_line_end
.closed:
        call net_close
        ld a,NE_CLOSED
        ret
.no_m4:
        call net_close
        ld a,NE_NO_M4
        ret
.get:
        ld hl,NET_C_RECV
        call net_cmd_at
        ld a,(ix + NC_SOCK)
        ld (de),a
        inc de
        ld a,NET_PIECE
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld c,3
        call net_m4
        jr c,.no_m4
        ld a,(net_resp + 3)
        or a
        ld a,NE_NONE
        ret nz
        ld bc,(net_resp + 4)        ; what came, at most NET_PIECE
        ld a,b
        or a
        jr nz,.most
        ld a,c
        cp NET_PIECE + 1
        jr c,.count
.most:
        ld bc,NET_PIECE
.count:
        ld a,c
        or a
        ret z
        push bc
        push ix
        pop de
        ld hl,NC_RX
        add hl,de
        ex de,hl
        ld hl,net_resp + 6
        ldir
        pop bc
        ld a,(ix + NC_RAW)
        or a
        jr z,.lines
        push ix
        pop hl
        ld de,NC_RX
        add hl,de
        ld a,NE_DATA
        ret
.lines:
        ld (ix + NC_RXN),c
        ld (ix + NC_RXAT),0
        jr net_lines
.waiting:                           ; a name or a connection: still?
        ld e,(ix + NC_SOCK)
        cp NS_LOOKUP
        jr nz,.sock
        ld e,0
.sock:
        call net_info
        jr c,.no_m4
        ret z
        ld a,(hl)
        cp NSS_LOOKUP
        jr z,.wait
        cp NSS_CONNECTING
        jr z,.wait
        cp NSS_ERROR
        jr nc,.fail
        ld a,(ix + NC_STATE)
        cp NS_LOOKUP
        jr nz,.connected
        ld de,4                     ; the name's ip, from socket 0
        add hl,de
        push ix
        pop de
        ld a,e
        add a,NC_IP
        ld e,a
        adc a,d
        sub e
        ld d,a
        ld bc,4
        ldir
        ld hl,0
        ld (net_owner),hl
        ld (ix + NC_STATE),NS_CLOSED
        call net_connect
        ret c
        xor a
        ret
.connected:
        ld (ix + NC_STATE),NS_CONNECTED
        ld a,NE_CONNECTED
        ret
.wait:
        ld l,(ix + NC_WAIT)
        ld h,(ix + NC_WAIT + 1)
        dec hl
        ld (ix + NC_WAIT),l
        ld (ix + NC_WAIT + 1),h
        ld a,h
        or l
        ld a,NE_NONE
        ret nz
.fail:
        call net_close
        ld a,NE_FAILED
        ret

; the bytes in NC_RX, into the line -> NE_LINE when it ends, or NE_NONE
net_lines:
        push ix
        pop hl
        ld de,NC_RX
        add hl,de
        ld e,(ix + NC_RXAT)
        ld d,0
        add hl,de
.byte:
        ld a,(ix + NC_RXN)
        or a
        ret z
        ld a,(ix + NC_LN)           ; a long line: this piece first
        cp NET_LINE_MAX
        jr nc,.long
        dec (ix + NC_RXN)
        inc (ix + NC_RXAT)
        ld a,(hl)
        inc hl
        cp 13
        jr z,.byte
        cp 10
        jr z,net_line_end
        push hl
        ld c,a
        call net_line_at
        ld (hl),c
        pop hl
        inc (ix + NC_LN)
        jr .byte
.long:
        call net_line_end
        ld a,1
        ld (net_long),a
        ld a,NE_LINE
        ret

; the line ends -> NE_LINE, HL -> it, B = its length
net_line_end:
        xor a
        ld (net_long),a
        call net_line_at
        ld (hl),0
        ld b,(ix + NC_LN)
        ld (ix + NC_LN),0
        push ix
        pop hl
        ld de,NC_LINE
        add hl,de
        ld a,NE_LINE
        ret

; -> HL -> the line's next byte (DE lost)
net_line_at:
        push ix
        pop hl
        ld de,NC_LINE
        add hl,de
        ld e,(ix + NC_LN)
        ld d,0
        add hl,de
        ret

; E = a socket -> HL -> its 16 bytes of the ROM's sock_info; carry: no
; M4 board; Z (A = 0): nothing now (behind and covered, VOS_EXT quiet)
net_info:
        push de
        ld a,#FF
        ld (net_socks),a
        ld bc,5 * 16
        ld hl,0
        ld de,net_socks
        ld a,VX_M4
        call VOS_EXT
        pop de
        ret c
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,net_socks
        add hl,de
        ld a,(net_socks)
        inc a
        ret

; ---------------------------------------------------------------------
net_say:
        ld de,net_out
        ld bc,0
.copy:
        ld a,(hl)
        or a
        jr z,.end
        ld (de),a
        inc hl
        inc de
        inc bc
        ld a,c
        cp NET_SEND_MAX - 2
        jr c,.copy
.end:
        ld a,13
        ld (de),a
        inc de
        ld a,10
        ld (de),a
        inc bc
        inc bc
        ld hl,net_out
        ; fall through
net_send:
        ld a,(ix + NC_STATE)
        cp NS_CONNECTED
        ret nz
        ld a,b
        or c
        ret z
        push bc
        push hl
        ld hl,NET_C_SEND
        call net_cmd_at
        ld a,(ix + NC_SOCK)
        ld (de),a
        inc de
        pop hl
        pop bc
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        inc de
        push bc
        ldir
        pop bc
        ld a,c
        add a,3
        ld c,a
        ; fall through
; net_cmd: a command of C bytes of data -> net_resp; carry: no M4 board
net_m4:
        ld a,c
        add a,2
        ld (net_cmd),a
        ld hl,net_cmd
        ld de,net_resp
        ld bc,6 + NET_PIECE
        ld a,VX_M4
        jp VOS_EXT

; HL = a command: its code in net_cmd -> DE -> its data
net_cmd_at:
        ld (net_cmd + 1),hl
        ld de,net_cmd + 3
        ret

net_ready:
        ld a,(ix + NC_STATUS)
        cp NSS_SENDING
        scf
        ret z
        or a
        ret

; ---------------------------------------------------------------------
; HL -> text -> IX's ip; carry: not four numbers (a name)
net_parse:
        ld b,4
.part:
        call net_number
        ret c
        ld a,d                      ; up to 255
        or a
        scf
        ret nz
        ld c,e
        push hl
        push ix                     ; the first part goes last
        pop hl
        ld a,NC_IP - 1
        add a,b
        ld e,a
        ld d,0
        add hl,de
        ld (hl),c
        pop hl
        ld a,(hl)
        dec b
        jr z,.end
        cp "."
        scf
        ret nz
        inc hl
        jr .part
.end:
        or a
        ret z
        cp ":"
        ret z
        scf
        ret

net_number:
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
        or a
        ret

net_reply:
        call net_number
        ret c
        ld a,(hl)
        cp " "
        ret z
        or a
        ret z
        scf
        ret

net_owner:      dw 0                ; the connection looking up a name
net_long:       db 0
net_cmd:        ds 6 + NET_SEND_MAX
net_resp:       ds 6 + NET_PIECE
net_out:        ds NET_SEND_MAX + 2
net_socks:      ds 5 * 16
