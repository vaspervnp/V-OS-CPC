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

