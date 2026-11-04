; =====================================================================
; m4.asm - M4.SYS: drive 2, the SD card of the M4 board. It runs in
; bank 7 at M4_ADDR, loaded from drive A: the first time it is needed
; (m4_go_e, kernel/files_ext.asm, which its jumps below come through).
; The file system calls of kernel/fs.asm come here for drive 2 through
; fs_m4 (m4_fs); file_copy, file_rename (kernel/files_ext.asm) and the
; views' folders (m4_cd, m4_path_text) too.
;
; The M4 board does the file system: a command goes out on port #FE00
; (db size, dw command, data), #FC00 starts it, and the response (size,
; two bytes, data from +3) is read from its ROM, mapped at #C000 with
; the interrupts off (m4_send; m4_rom and m4_done in kernel/api.asm).
; Files are opened raw (FatFS, mode #80): a binary file's AMSDOS header
; is read and written here, as kernel/fs.asm does on a disc. Names are
; 8.3 ("NAME.EXT"), in the M4's current folder, which C_CD changes
; (m4_cd); C_READDIR lists it, folders first with ">" before the name.
; Data goes through fs_buf: a command or response starts at fs_buf +
; 252, its data at fs_buf + 256 (up to M4_PIECE bytes a command).
; =====================================================================

        jp m4_fs                    ; the jumps of m4_go_e (files_ext.asm)
        jp m4_copy
        jp m4_rename
        jp m4_cd
        jp m4_path_text
        db "M4"                     ; at +15: checked when loaded
        jp m4_date                  ; +17

C_OPEN          equ #01             ; (#43xx)
C_WRITE         equ #03
C_CLOSE         equ #04
C_READDIR       equ #06
C_CD            equ #08
C_FREE          equ #09
C_ERASEFILE     equ #0E
C_RENAME        equ #0F
C_FSIZE         equ #11
C_READ          equ #02
C_GETPATH       equ #13
C_DIRSETARGS    equ #25
C_FSTAT         equ #16
M4_MODE_R       equ #81             ; C_OPEN: FatFS, read
M4_MODE_W       equ #8A             ; FatFS, write, a new file always
M4_PIECE        equ 252
m4_data         equ fs_buf + 256
M4_FOLDER       equ 13              ; in an FS_CAT entry: 1, a folder
M4_ERR_NONE     equ 35              ; no M4 board
M4_ERR_BIG      equ 36              ; a copy to or from it over 16K
M4_ERR_SAME     equ 37              ; a copy to the drive it is on
M4_ERR_FORMAT   equ 38              ; FORMAT: not the M4's card
M4_ERR_SYS      equ 39              ; M4.SYS is not on drive A:

; ---------------------------------------------------------------------
; m4_fs - from fs_m4 (kernel/fs.asm): the call whose address + 3 is in
; m4_entry, for drive 2. HL, BC and A come in m4_hl, m4_bc, m4_a.
; ---------------------------------------------------------------------
m4_fs:
        push de
        ld hl,m4_calls
.find:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(m4_entry)
        cp e
        jr nz,.next
        ld a,(m4_entry + 1)
        cp d
        jr z,.found
.next:
        inc hl
        inc hl
        jr .find
.found:
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        ld bc,(m4_bc)
        ld a,(m4_a)
        jp (hl)

m4_calls:       dw fs_catalog + 3, m4_catalog
                dw fs_load + 3, m4_load
                dw fs_save + 3, m4_save
                dw fs_delete + 3, m4_delete
                dw fs_exists + 3, m4_exists
                dw fs_free_k + 3, m4_free_k
                dw fs_mount + 3, m4_mount

; ---------------------------------------------------------------------
; commands
; ---------------------------------------------------------------------
; HL -> a command (db size, dw command, data), DE -> where its response
; goes, BC = how many bytes of it -> carry: no M4 board (A = M4_ERR_NONE)
m4_send:
        ld a,(m4_num)
        cp #FE
        ld a,M4_ERR_NONE
        ccf
        ret c
        push bc
        push de
        ld bc,#FE00
        ld d,(hl)
        inc d
.out:
        inc b
        outi
        dec d
        jr nz,.out
        ld bc,#FC00                 ; go
        out (c),c
        pop de
        pop bc
        di
        call m4_rom
        ld hl,(#FF02)               ; the ROM's response buffer
        ldir
        jp m4_done

; A = command (#43xx) -> DE -> its data in m4_cmd
m4_begin:
        ld de,m4_cmd + 1
        ld (de),a
        inc de
        ld a,#43
        ld (de),a
        inc de
        ret

; DE = after m4_cmd's data: send it, its response to m4_rsp -> A = the
; result (its first byte of data), Z: done; carry: no M4 board
m4_go:
        ld a,e
        sub (m4_cmd + 1) & #FF
        ld (m4_cmd),a
        ld hl,m4_cmd
        ld de,m4_rsp
        ld bc,M4_RSP_LEN
        call m4_send
        ret c
; -> A = the result in m4_rsp, Z: done (no data, as C_CD's: done too)
m4_result:
        ld a,(m4_rsp)               ; its size: the command, then data
        cp 3
        jr nc,.data
        xor a
        ret
.data:
        ld a,(m4_rsp + 3)
        or a
        ret

; HL -> 11-byte name (FCB style) -> at DE as "NAME.EXT", 0; DE after
; the 0
m4_fname:
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
        ld a,(hl)
        and #7F
        cp " "
        jr z,.end
        ld a,"."
        ld (de),a
        inc de
        ld b,3
.ext:
        ld a,(hl)
        inc hl
        and #7F
        cp " "
        jr z,.ext_skip
        ld (de),a
        inc de
.ext_skip:
        djnz .ext
.end:
        xor a
        ld (de),a
        inc de
        ret

; A = command: m4_cmd = it with fs_name ("NAME.EXT"), sent -> A = the
; result, Z: done
m4_named:
        call m4_begin
        ld hl,fs_name
        call m4_fname
        jr m4_go

; fs_name opened with mode A (M4_MODE_R, M4_MODE_W) -> m4_fd; carry: A =
; error (FS_ERR_NOT_FOUND, or M4_ERR_NONE)
m4_open:
        push af
        ld a,C_OPEN
        call m4_begin
        pop af
        ld (de),a
        inc de
        ld hl,fs_name
        call m4_fname
        call m4_go
        ret c
        ld a,(m4_rsp + 4)           ; data: the descriptor, the result
        or a
        ld a,FS_ERR_NOT_FOUND
        scf
        ret nz
        ld a,(m4_rsp + 3)
        ld (m4_fd),a
        or a
        ret

; m4_fd closed; A and carry kept
m4_close:
        push af
        ld a,C_CLOSE
        call m4_begin
        ld a,(m4_fd)
        ld (de),a
        inc de
        call m4_go
        pop af
        ret

; ---------------------------------------------------------------------
; fs_mount: the board is there -> carry, A = M4_ERR_NONE if not
; ---------------------------------------------------------------------
m4_mount:
        ld a,(m4_num)
        cp #FE
        ccf
        ld a,M4_ERR_NONE
        ret c
        xor a
        ret

; fs_free_k -> A = free kilobytes, up to 255 (C_FREE: "nnnK free")
m4_free_k:
        ld a,C_FREE
        call m4_begin
        call m4_go
        ld a,0
        ret c
        ld hl,m4_rsp + 3
        ld c,0
.char:
        ld a,(hl)
        inc hl
        cp "K"
        jr z,.done
        sub "0"
        cp 10
        jr nc,.char                 ; not a digit (the CR LF before)
        ld b,a
        ld a,c
        cp 26
        jr nc,.most
        add a,a                     ; C * 10 + digit
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,b
        ld c,a
        jr nc,.char
.most:
        ld c,255
        jr .char
.done:
        ld a,c
        or a
        ret

; ---------------------------------------------------------------------
; fs_catalog -> A = entries in FS_CAT (16 bytes each: name[11], 0, size
; in K, M4_FOLDER: 1 for a folder, 0, 0): ".." first below the top
; folder, then what C_READDIR gives (names that are not 8.3 left out)
; ---------------------------------------------------------------------
m4_catalog:
        xor a
        ld (m4_count),a
        ld a,C_DIRSETARGS           ; every file
        call m4_begin
        xor a
        ld (de),a
        inc de
        call m4_go
        ret c
        call m4_path                ; below the top: ".." to go up
        ld a,(m4_rsp + 4)
        or a
        jr z,.list
        ld hl,m4_up
        call m4_entry_new
.list:
        ld a,(m4_count)
        cp FS_CAT_MAX
        jr nc,.done
        ld a,C_READDIR
        call m4_begin
        call m4_go
        ret c
        ld a,(m4_rsp)               ; size 2: no more
        cp 3
        jr c,.done
        call m4_parse
        jr c,.list                  ; not one V-OS can name
        ld hl,m4_ent
        call m4_entry_new
        jr .list
.done:
        ld a,(m4_count)
        or a
        ret

; HL -> 16 bytes: the next entry of FS_CAT
m4_entry_new:
        ld a,(m4_count)
        inc a
        ld (m4_count),a
        dec a
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        ex de,hl
        pop hl
        ld bc,16
        ldir
        ret

; m4_rsp: an entry of C_READDIR ("NAME    .EXT  1234", ">NAME   .  DIR"
; for a folder) -> m4_ent; carry if its name is not 8.3 (a space inside)
m4_parse:
        ld hl,m4_ent
        ld b,16
.clear:
        ld (hl),0
        inc hl
        djnz .clear
        ld hl,m4_rsp + 3
        ld de,m4_ent
        ld a,(hl)
        cp ">"
        jr nz,.name
        inc hl                      ; a folder: 7 characters
        ld a,1
        ld (m4_ent + M4_FOLDER),a
.name:
        ld b,8                      ; the name, up to the dot
        ld c,0                      ; 1: a space was seen
.char:
        ld a,(hl)
        cp "."
        jr z,.pad
        inc hl
        call m4_upper
        cp " "
        jr nz,.char_ok
        ld c,1
        jr .store
.char_ok:
        dec c
        inc c
        scf
        ret nz                      ; "A LONG F": not 8.3
.store:
        ld (de),a
        inc de
        djnz .char
.pad:
        ld a,b                      ; the rest of the 8 with spaces
        or a
        jr z,.dot
.space:
        ld a," "
        ld (de),a
        inc de
        djnz .space
.dot:
        ld a,(hl)                   ; past the dot
        cp "."
        jr nz,.ext
        inc hl
.ext:
        ld b,3
.ext_char:
        ld a,(hl)
        call m4_upper
        or a
        jr nz,.ext_store
        ld a," "
        dec hl
.ext_store:
        ld (de),a
        inc hl
        inc de
        djnz .ext_char
        ld a,(m4_ent + M4_FOLDER)
        or a
        ret nz                      ; a folder: no size
.blank:
        ld a,(hl)                   ; the size: bytes, or K ("12K")
        cp " "
        jr nz,.digits
        inc hl
        jr .blank
.digits:
        ex de,hl                    ; DE -> it, C:HL = the number
        ld hl,0
        ld c,l
.size:
        ld a,(de)
        inc de
        cp "K"
        jr z,.kilo
        sub "0"
        cp 10
        jr nc,.bytes
        call m4_ten
        jr .size
.kilo:
        ld a,c                      ; K already: the low byte, or 255
        or h
        ld a,l
        jr z,.k
        ld a,255
        jr .k
.bytes:
        ld de,1023                  ; K = (bytes + 1023) / 1024
        add hl,de
        jr nc,.round
        inc c
.round:
        ld a,c
        cp 4
        ld a,255
        jr nc,.k                    ; 256K or more
        ld a,h                      ; C:H / 4
        srl c
        rra
        srl c
        rra
.k:
        ld (m4_ent + 12),a
        or a
        ret

; C:HL = C:HL * 10 + A (24 bits); DE kept
m4_ten:
        push de
        push af
        ld d,h
        ld e,l
        ld b,c
        add hl,hl
        rl c
        add hl,hl
        rl c
        add hl,de
        ld a,c
        adc a,b
        ld c,a
        add hl,hl
        rl c
        pop af
        pop de
        add a,l
        ld l,a
        ret nc
        inc h
        ret nz
        inc c
        ret

; fs_name's date and time at DE, a line "2026-11-04 09:30" for FILE
; INFO (C_FSTAT), DE after them; nothing when the board does not give them
m4_date:
        push de
        ld a,C_FSTAT
        call m4_named
        pop de
        ret c
        ret nz
        ld a,(m4_rsp)               ; data up to the time
        cp 3 + 9
        ret c
        call file_newline
        ld hl,(m4_rsp + 3 + 5)      ; the date: year - 1980 (7 bits),
        push hl                     ; month (4), day (5)
        ld a,h
        srl a
        ld l,a
        ld h,0
        ld bc,1980
        add hl,bc
        call util_dec
        pop hl
        ld a,l                      ; the month
        rlca
        rlca
        rlca
        and 7
        bit 0,h
        jr z,.month
        or 8
.month:
        call .two
        ld a,l
        and 31
        call .two
        ld hl,(m4_rsp + 3 + 7)      ; the time: hour (5), minute (6)
        ld a,h
        rrca
        rrca
        rrca
        and 31
        ld c," "
        call .two_c
        ld a,h
        and 7
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,l
        rlca
        rlca
        rlca
        and 7
        or b
        ld c,":"
        jr .two_c
.two:                               ; "-", then A as two digits
        ld c,"-"
.two_c:                             ; C, then A as two digits
        ex de,hl
        ld (hl),c
        inc hl
        ld b,"0" - 1
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,"0" + 10
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        ex de,hl
        ret

; A -> A in capitals
m4_upper:
        cp "a"
        ret c
        cp "z" + 1
        ret nc
        sub " "
        ret

; -> m4_rsp: C_GETPATH, the folder now ("/", "/GAMES/"...) from +3;
; +4 is 0 at the top
m4_path:
        ld a,C_GETPATH
        call m4_begin
        jp m4_go

; the folder now, for a view's title -> bank_buf: its last 31
; characters, 0 (just 0 without an M4 board)
m4_path_text:
        call m4_path
        ld hl,m4_rsp + M4_RSP_LEN - 1
        ld (hl),0                   ; (a long one cut)
        ld hl,m4_rsp + 3
        jr nc,.end
        ld (hl),0
.end:
        ld a,(hl)                   ; HL -> the 0 after it
        inc hl
        or a
        jr nz,.end
        dec hl
        ld de,m4_rsp + 3 + 31
        push hl
        or a
        sbc hl,de
        pop hl
        ld de,m4_rsp + 3
        jr c,.copy
        ld de,-31
        add hl,de
        ex de,hl
.copy:
        ex de,hl
        ld de,bank_buf
        ld bc,32
        ldir
        ret

; ---------------------------------------------------------------------
; m4_cd - file_name: into that folder (".." up) -> carry, A = error
; (a view's RETURN on a folder, through m4_cd_e)
; ---------------------------------------------------------------------
m4_cd:
        ld hl,file_name
        call fs_set_name
        ld a,(fs_name)
        cp "."
        jr z,.up
        ld a,C_CD
        call m4_named
        ret c
.done:
        ret z
        ld a,FS_ERR_NOT_FOUND
        scf
        ret
; up: the folder now without its last name, sent whole (C_CD with
; ".." is not understood everywhere)
.up:
        call m4_path
        ret c
        ld hl,m4_rsp + 3
        ld de,m4_rsp + 4
.find:
        ld a,(hl)
        or a
        jr z,.cut
        inc hl
        cp "/"
        jr nz,.find
        ld d,h                      ; after the last "/" so far
        ld e,l
        jr .find
.cut:
        ld hl,m4_rsp + 4            ; that "/" goes too, unless it is
        sbc hl,de                   ; the first (carry clear: or a)
        jr z,.root
        dec de
.root:
        xor a
        ld (de),a
        ld hl,m4_rsp + 3            ; the command in fs_buf: db size,
        ld de,fs_buf + 3            ; dw C_CD, the path, 0
.copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.copy
        ld a,e
        sub (fs_buf + 1) & #FF
        ld hl,fs_buf
        ld (hl),a
        inc hl
        ld (hl),C_CD
        inc hl
        ld (hl),#43
        ld hl,fs_buf
        ld de,m4_rsp
        ld bc,M4_RSP_LEN
        call m4_send
        ret c
        call m4_result
        jr .done

; ---------------------------------------------------------------------
; fs_load: m4_hl = name, DE = destination, C = its RAM config -> BC =
; length, fs_hdr_*; at most FS_LOAD_MAX bytes copied
; ---------------------------------------------------------------------
m4_load:
        ld (fl_ptr),de
        ld a,c
        ld (fl_cfg),a
        ld hl,(m4_hl)
        call fs_set_name
        ld a,M4_MODE_R
        call m4_open
        ret c
        ld a,C_FSIZE                ; its size
        call m4_begin
        ld a,(m4_fd)
        ld (de),a
        inc de
        call m4_go
        ld hl,(m4_rsp + 3)
        ld a,(m4_rsp + 5)
        or a
        jr z,.size
        ld hl,#FFFF                 ; 64K or more
.size:
        ld (m4_left),hl
        ld bc,128                   ; the first 128 bytes (or fewer): a
        ld a,h                      ; header?
        or a
        jr nz,.first
        ld a,l
        cp c
        jr nc,.first
        ld c,a
.first:
        ld (m4_n),bc
        ld a,c
        or a
        jr z,.text                  ; empty
        call m4_read
        jp c,m4_close
        ld hl,m4_data
        ld de,fs_buf
        ldir
        ld a,(m4_n)
        cp 128
        jr c,.text                  ; shorter: no header
        call fs_header_ok
        jr nz,.text
        ld hl,(fs_buf + #40)        ; real length
        ld (fs_length),hl
        ld a,(fs_buf + #12)
        ld (fs_hdr_type),a
        ld hl,(fs_buf + #15)
        ld (fs_hdr_load),hl
        ld hl,(fs_buf + #1A)
        ld (fs_hdr_exec),hl
        ld hl,(fs_length)
        call .most
        jr .rest
.text:
        ld hl,(m4_left)             ; all of it is data, its first
        ld (fs_length),hl           ; bytes read already
        ld a,#FF
        ld (fs_hdr_type),a
        ld hl,0
        ld (fs_hdr_load),hl
        ld (fs_hdr_exec),hl
        ld hl,(fs_length)
        call .most
        ld bc,(m4_n)
        ld hl,fs_buf
        call fl_out
.rest:
        ld hl,(fl_left)             ; the rest, a piece at a time
        ld a,h
        or l
        jr z,.done
        ld bc,M4_PIECE
        sbc hl,bc
        jr nc,.piece
        ld bc,(fl_left)
.piece:
        call m4_read
        jp c,m4_close
        ld hl,m4_data
        call fl_out
        jr .rest
.done:
        call m4_close
        ld bc,(fs_length)
        or a
        ret
; HL = length -> fl_left: no more than FS_LOAD_MAX
.most:
        ld de,FS_LOAD_MAX + 1
        or a
        sbc hl,de
        jr c,.fits
        ld hl,FS_LOAD_MAX
        jr .left
.fits:
        add hl,de
.left:
        ld (fl_left),hl
        ret

; BC = bytes (up to M4_PIECE): the next of m4_fd -> m4_data; BC kept.
; Carry: A = error
m4_read:
        ld hl,fs_buf + 252
        ld (hl),5
        inc hl
        ld (hl),C_READ
        inc hl
        ld (hl),#43
        inc hl
        ld a,(m4_fd)
        ld (hl),a
        ld (fs_buf + 256),bc
        ld hl,fs_buf + 252
        push bc
        ld de,fs_buf + 252          ; the response there too: its result
        inc bc                      ; at +255, the data from m4_data
        inc bc
        inc bc
        inc bc
        call m4_send
        pop bc
        ret c
        ld a,(fs_buf + 255)
        or a
        ret z
        ld a,FDC_ERR_DATA
        scf
        ret

; ---------------------------------------------------------------------
; fs_save: m4_hl = name, DE = source, m4_a = its RAM config, BC =
; length, fs_hdr_type/load/exec (#FF: no header)
; ---------------------------------------------------------------------
m4_save:
        ld (fl_ptr),de
        ld (fl_cfg),a
        ld (fs_length),bc
        ld (fl_left),bc
        ld hl,(m4_hl)
        call fs_set_name
        ld a,M4_MODE_W
        call m4_open
        ret c
        ld a,(fs_hdr_type)
        inc a
        jr z,.data
        call fs_make_header
        ld hl,fs_buf
        ld de,m4_data
        ld bc,128
        ldir
        ld c,128
        call m4_write
        jp c,m4_close
.data:
        ld hl,(fl_left)
        ld a,h
        or l
        jr z,.done
        ld bc,M4_PIECE
        sbc hl,bc
        jr nc,.piece
        ld bc,(fl_left)
.piece:
        push bc
        ld hl,m4_data
        call fl_in
        pop bc
        call m4_write
        jp c,m4_close
        jr .data
.done:
        call m4_close
        or a
        ret

; C = bytes at m4_data: to m4_fd -> carry: A = error
m4_write:
        ld hl,fs_buf + 252
        ld a,c
        add a,3
        ld (hl),a
        inc hl
        ld (hl),C_WRITE
        inc hl
        ld (hl),#43
        inc hl
        ld a,(m4_fd)
        ld (hl),a
        ld hl,fs_buf + 252
        ld de,m4_rsp
        ld bc,M4_RSP_LEN
        call m4_send
        ret c
        call m4_result
        ret z
        ld a,FS_ERR_FULL
        scf
        ret

; ---------------------------------------------------------------------
; fs_delete, fs_exists: m4_hl = name
; ---------------------------------------------------------------------
m4_delete:
        ld hl,(m4_hl)
        call fs_set_name
        ld a,C_ERASEFILE
        call m4_named
        ret c
        ret z
        ld a,FS_ERR_NOT_FOUND
        scf
        ret

m4_exists:
        ld hl,(m4_hl)
        call fs_set_name
        ld a,M4_MODE_R
        call m4_open
        ret c
        xor a
        jp m4_close

; ---------------------------------------------------------------------
; m4_rename (fx_rename): file_name to fi_new -> carry, A = error
; ---------------------------------------------------------------------
m4_rename:
        ld a,C_RENAME               ; new name, 0, old name, 0
        call m4_begin
        ld hl,fi_new
        call m4_fname
        ld hl,file_name
        call m4_fname
        call m4_go
        ret c
        ret z
        ld a,FS_ERR_EXISTS
        scf
        ret

; ---------------------------------------------------------------------
; m4_copy (fx_copy): file_name from drive fi_drive to fi_target, one of
; them the M4's card: through bank 4, up to 16K -> carry, A = error
; ---------------------------------------------------------------------
m4_copy:
        ld a,(fi_drive)
        call fdc_select
        ld hl,file_name
        ld de,BUF_ADDR
        ld c,BUF_CFG
        call fs_load
        ret c
        ld hl,(fs_length)
        ld de,FS_LOAD_MAX + 1
        or a
        sbc hl,de
        ld a,M4_ERR_BIG
        ccf
        ret c
        ld a,(fi_target)
        call fdc_select
        ld hl,file_name
        ld de,BUF_ADDR
        ld bc,(fs_length)
        ld a,BUF_CFG
        jp fs_save

m4_up:          db "..         ", 0, 0, 1, 0, 0
m4_count:       db 0
m4_fd:          db 0
m4_left:        dw 0
m4_n:           dw 0
m4_ent:         ds 16
M4_RSP_LEN          equ 48
m4_rsp:         ds M4_RSP_LEN
m4_cmd:         ds 32
        assert (m4_cmd + 1) >> 8 == (m4_cmd + 32) >> 8

; from fs_m4 (kernel/fs.asm), outside the bank window: GAP1's last bytes
m4_a            equ GAP1 + 789
m4_entry        equ GAP1 + 790
m4_hl           equ GAP1 + 792
m4_bc           equ GAP1 + 794
