; =====================================================================
; files_ext.asm - the file commands of kernel/files.asm, in the kernel
; extension: file_info, file_copy, file_delete, file_rename and
; file_format put the drive in fi_drive and come here (ext_call).
; =====================================================================

fx_info:
        ld a,(fi_drive)
        call fdc_select
        ld hl,file_name
        ld de,BUF_ADDR
        ld c,BUF_CFG
        call fs_load
        jp c,sys_error
        ld de,dlg_custom            ; NAME.EXT
        call file_name_text
        call file_newline
        ld a,MSG_SIZE               ; SIZE n
        call file_label
        ld hl,(fs_length)
        call util_dec
        call file_newline
        ld a,MSG_TYPE               ; TYPE ...
        call file_label
        ld a,(fs_hdr_type)
        ld c,MSG_TYPE_BASIC
        or a
        jr z,.type
        ld c,MSG_TYPE_TEXT
        inc a
        jr z,.type
        ld c,MSG_TYPE_BINARY
.type:
        ld a,c
        call util_msg
        ld a,(fs_hdr_type)          ; LOAD #nnnn, files with a header
        inc a
        jr z,.bytes
        call file_newline
        ld a,MSG_LOAD
        call file_label
        ld a,"#"
        call util_char
        ld hl,(fs_hdr_load)
        call util_hex4
.bytes:
        call file_newline           ; the first bytes, as text
        ld hl,(fs_length)
        ld bc,FILE_VIEW_BYTES
        or a
        sbc hl,bc
        jr nc,.count
        add hl,bc
        ld b,h
        ld c,l
.count:
        ld a,c
        or a
        jr z,.end
        ld b,a
        push bc                     ; (bank 4 is not mapped here: the
        push de                     ; bytes come through bank_buf)
        ld c,a
        ld b,0
        ld a,BUF_CFG
        ld hl,BUF_ADDR
        ld de,bank_buf
        call bank_get
        pop de
        pop bc
        ld hl,bank_buf
.byte:
        ld a,(hl)
        inc hl
        cp " "
        jr c,.dot
        cp "|"
        jr z,.dot
        cp #7F
        jr c,.store
        cp #A0
        jr nc,.store
.dot:
        ld a,"."
.store:
        ld (de),a
        inc de
        djnz .byte
.end:
        xor a
        ld (de),a
        ld hl,dlg_file
        jp dialog_run

; the target is the other drive
fx_copy:
        ld a,(fi_drive)
        xor 1
        ld (fi_target),a
        call fdc_select
        ld hl,file_name
        call fs_exists
        jr c,.copy                  ; not there (or unreadable: the copy says)
        ld de,dlg_custom            ; REPLACE|NAME.EXT?
        ld a,MSG_REPLACE_Q
        call file_question
        ret c
.copy:
        ld a,MSG_COPYING
        call ui_busy
        ld a,(fi_drive)
        ld b,a
        ld a,(fi_target)
        ld c,a
        ld hl,file_name
        call fs_copy
        push af
        call ui_restore
        pop af
        jp c,sys_error_nc
        ld de,dlg_custom            ; COPIED TO B:|NAME.EXT
        ld a,MSG_COPIED
        call file_label
        ld a,(fi_target)
        add a,"A"
        call util_char
        ld a,":"
        call util_char
        call file_newline
        call file_name_text
        xor a
        ld (de),a
        ld hl,dlg_file
        call dialog_run
        or a
        ret

fx_delete:
        ld de,dlg_custom            ; DELETE|NAME.EXT?
        ld a,MSG_DELETE_Q
        call file_question
        ret c
        ld a,(fi_drive)
        call fdc_select
        ld hl,file_name
        call fs_delete
        jp c,sys_error_nc
        ret

fx_rename:
        ld de,fi_text               ; the old name to edit
        call file_name_text
        xor a
        ld (de),a
        ld a,MSG_RENAME_T
        ld hl,fi_text
        ld c,FILE_TEXT_MAX
        call input_run
        ret c
        call file_parse
        ld a,FS_ERR_BAD_NAME
        jp c,sys_error_nc
        ld a,(fi_drive)
        call fdc_select
        ld hl,file_name
        ld de,fi_new
        call fs_rename
        jp c,sys_error_nc
        ret

fx_format:
        ld de,dlg_custom            ; FORMAT A:?|ALL FILES ARE LOST
        ld a,MSG_FORMAT_Q
        call file_label
        ld a,(fi_drive)
        add a,"A"
        call util_char
        ld a,":"
        call util_char
        ld a,MSG_QMARK
        call util_msg
        call file_newline
        ld a,MSG_FORMAT_LOST
        call file_ask
        ret c
        ld a,MSG_FORMATTING
        call ui_busy
        ld a,(fi_drive)
        call fdc_select
        call fs_format
        push af
        call ui_restore
        pop af
        jp c,sys_error_nc
        ret


; ---------------------------------------------------------------------
; fx_open - file_open: a program (ft_run) runs; a file of a type in
; ft_open runs its program, found on the file's drive, then A:, then
; B:, with the file in app_open; any other file: FILE INFO
; ---------------------------------------------------------------------
fx_open:
        ld de,ft_run
        ld b,3
        call fx_type
        ld a,(fi_drive)
        jp z,app_request
        ld de,ft_open
        ld b,3 + 11
        call fx_type
        jp nz,fx_info
        push de                     ; -> the program's name
        ld hl,app_open              ; the file, for the program
        ld (hl),1
        inc hl
        ld a,(fi_drive)
        ld (hl),a
        inc hl
        ex de,hl
        ld hl,file_name
        ld bc,11
        ldir
        pop hl
        ld de,file_name
        ld bc,11
        ldir
        ld a,(fi_drive)             ; where the program is
        call fx_has
        jp nc,app_request
        xor a
        call fx_has
        jp nc,app_request
        ld a,1
        call fx_has
        jp nc,app_request
        xor a                       ; nowhere: the file selected again
        ld (app_open),a
        ld hl,app_open + 2
        ld de,file_name
        ld bc,11
        ldir
        ld a,FS_ERR_NO_APP
        jp sys_error

; DE -> a table of B-byte entries, each starting with an extension, 0 at
; the end -> Z if file_name's extension is in it, DE -> the rest of
; that entry
fx_type:
        ld a,(de)
        or a
        jr z,.none
        ld hl,file_name + 8
        ld c,3
        push de
.char:
        ld a,(de)
        xor (hl)
        and #7F                     ; not the read-only and system bits
        jr nz,.other
        inc hl
        inc de
        dec c
        jr nz,.char
        pop af
        xor a
        ret
.other:
        pop hl                      ; the next entry
        ld e,b
        ld d,0
        add hl,de
        ex de,hl
        jr fx_type
.none:
        or 1
        ret

; A = drive -> no carry if file_name is on it; A kept
fx_has:
        push af
        call fdc_select
        ld hl,file_name
        call fs_exists
        pop bc
        ld a,b
        ret

ft_run:         db "BIN", "VBN", "BAS", 0
ft_open:        db "TXT", "NOTEPAD BIN"
                db "MD ", "MARKDOWNBIN"
                db "PIC", "PAINT   BIN"
                db "LYR", "PAINT   BIN"
                db "MUS", "MUSIC   BIN"
                db 0

; ---------------------------------------------------------------------
; VOS_EXT calls that live here (kernel/api.asm: api_ext)
; ---------------------------------------------------------------------
; VX_FREE: C = drive -> A = its free kilobytes; carry and A = error
xa_free:
        ld a,c
        call fdc_select
        call fs_mount
        ret c
        call fs_free_k
        or a
        ret

; -> A = the M4 ROM's number (searched once), carry if there is none
m4_find:                            ; (VX_M4, kernel/api.asm)
        ld a,(m4_num)
        cp #FE
        jr c,.known
        scf
        ret z                       ; known: none
        ld a,31
.rom:
        ld (m4_num),a
        di
        call m4_rom
        ld hl,(#C004)               ; the name: "M4 BOARD", "D" + #80
        ld de,m4_name
        ld a,(#C000)                ; a background ROM
        dec a
        jr nz,.other
.char:
        ld a,(de)
        cp (hl)
        jr nz,.other
        inc hl
        inc de
        rla
        jr nc,.char
        call m4_done
        ld a,(m4_num)
        or a
        ret
.other:
        call m4_done
        ld a,(m4_num)
        sub 1
        jr nc,.rom
        ld a,#FE
        ld (m4_num),a
        scf
        ret
.known:
        or a
        ret

m4_name:        db "M4 BOAR", "D" + #80
