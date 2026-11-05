; =====================================================================
; vos_m4file.inc - a file of the M4 board's SD card (drive DISK) read
; or written a piece at a time, so it may be bigger than the 16K a
; program has (VOS_LOAD and VOS_SAVE take a file whole): included with
; the program's code (after vos_api.inc). Through VX_M4 (API 17), with
; the board's FatFS commands, in the card's folder V-OS is in (the one
; the Desktop or the Commander last went into). One file at a time;
; the bytes as they are, without an AMSDOS header.
;
; m4f_create: HL -> "NAME.EXT", 0 -> a new file (or one emptied) for
;   writing; carry: not (no board, or the card refused it)
; m4f_open: HL -> "NAME.EXT", 0 -> for reading; DE:HL = its size;
;   carry: not there
; m4f_write: HL -> bytes, BC = how many (M4F_PIECE at most); carry: not
;   written (the card full)
; m4f_read: DE -> where, BC = how many (M4F_PIECE at most) -> the bytes
;   there; carry: not read
; m4f_close: the file closed
; m4f_header: HL -> a file's first 128 bytes -> NC: an AMSDOS header
;   (its checksum right), BC = the length it gives; carry: none
; =====================================================================

M4F_PIECE       equ 252             ; the bytes of one command at most
M4F_C_OPEN      equ #4301
M4F_C_READ      equ #4302
M4F_C_WRITE     equ #4303
M4F_C_CLOSE     equ #4304
M4F_C_FSIZE     equ #4311
M4F_MODE_R      equ #81             ; FatFS: read
M4F_MODE_W      equ #8A             ; write, a new file always

m4f_create:
        ld a,M4F_MODE_W
        jr m4f_open_mode
m4f_open:
        ld a,M4F_MODE_R
        call m4f_open_mode
        ret c
        ld hl,M4F_C_FSIZE           ; its size
        call m4f_begin
        ld a,(m4f_fd)
        ld (de),a
        ld c,1
        call m4f_go
        ret c
        ld hl,(m4f_rsp + 5)
        ex de,hl
        ld hl,(m4f_rsp + 3)
        or a
        ret

; A = mode, HL -> the name -> m4f_fd
m4f_open_mode:
        push hl
        ld hl,M4F_C_OPEN
        call m4f_begin
        pop hl
        ld (de),a
        inc de
        ld c,1
.name:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        inc c
        or a
        jr nz,.name
        call m4f_go
        ret c
        ld a,(m4f_rsp + 4)          ; the descriptor, then the result
        or a
        scf
        ret nz
        ld a,(m4f_rsp + 3)
        ld (m4f_fd),a
        or a
        ret

m4f_close:
        ld hl,M4F_C_CLOSE
        call m4f_begin
        ld a,(m4f_fd)
        ld (de),a
        ld c,1
        call m4f_go
        or a                        ; (its answer has no data)
        ret

m4f_write:
        push bc
        push hl
        ld hl,M4F_C_WRITE
        call m4f_begin
        ld a,(m4f_fd)
        ld (de),a
        inc de
        pop hl
        pop bc
        push bc
        ld a,b
        or c
        jr z,.none
        ldir
.none:
        pop bc
        inc c
        call m4f_go
        ret c
        ld a,(m4f_rsp + 3)          ; its result
        or a
        ret z
        scf
        ret

m4f_read:
        push de
        push bc
        ld hl,M4F_C_READ
        call m4f_begin
        ld a,(m4f_fd)
        ld (de),a
        inc de
        pop bc
        push bc
        ex de,hl
        ld (hl),c
        inc hl
        ld (hl),b
        ld c,3
        call m4f_go
        pop bc
        pop de
        ret c
        ld a,(m4f_rsp + 3)          ; the result, then the data
        or a
        scf
        ret nz
        ld hl,m4f_rsp + 4
        ld a,b
        or c
        ret z
        ldir
        or a
        ret

; HL = a command -> DE -> its data
m4f_begin:
        ld (m4f_cmd + 1),hl
        ld de,m4f_cmd + 3
        ret

; m4f_cmd with C bytes of data -> m4f_rsp; carry: no board
m4f_go:
        ld a,c
        add a,2
        ld (m4f_cmd),a
        xor a                       ; (VOS_EXT quiet behind another
        ld (m4f_rsp),a              ; window writes nothing)
        ld hl,m4f_cmd
        ld de,m4f_rsp
        ld bc,4 + M4F_PIECE
        ld a,VX_M4
        call VOS_EXT
        ret c
        ld a,(m4f_rsp)              ; no answer (VOS_EXT quiet): not
        cp 3
        ret

m4f_header:
        push hl
        ld de,0                     ; the sum of its first 67 bytes
        ld b,67
.sum:
        ld a,(hl)
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        inc hl
        djnz .sum
        ld a,(hl)                   ; = the word after them?
        cp e
        jr nz,.no
        inc hl
        ld a,(hl)
        cp d
        jr nz,.no
        ld a,d
        or e
        jr z,.no                    ; (all zeros: not one)
        pop hl
        ld bc,#40
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        or a
        ret
.no:
        pop hl
        scf
        ret

m4f_fd:         db 0
m4f_cmd:        ds 3 + 1 + M4F_PIECE
m4f_rsp:        ds 4 + M4F_PIECE
