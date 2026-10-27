; =====================================================================
; files.asm - file commands shared by the views
;
; The view puts the 11-byte name in file_name, then calls with
; A = drive (0 = A:, 1 = B:):
;   file_info     load into bank 4, show size, type, load address and
;                 the first bytes
;   file_copy     copy to the other drive, any size (fs_copy)
;   file_delete   ask, then delete
;   file_rename   ask for the new name (input_run), then rename
; Copy, delete and rename return carry when nothing was tried (the user
; said no); otherwise the disc may have changed, so the view reads it
; again. Errors are shown with sys_error.
; =====================================================================

FILE_VIEW_BYTES equ 18              ; first bytes shown by file_info
FILE_TEXT_MAX   equ 12              ; "NAME.EXT"

file_info:
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
        ld a,BUF_CFG
        push bc
        call ram_select
        pop bc
        ld hl,BUF_ADDR
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
        call ram_home
.end:
        xor a
        ld (de),a
        ld hl,dlg_file
        jp dialog_run

; A = source drive; the target is the other one
file_copy:
        ld b,a
        xor 1
        ld c,a
        ld (fi_target),a
        ld hl,file_name
        call fs_copy
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

file_delete:
        ld (fi_drive),a
        ld de,dlg_custom            ; DELETE|NAME.EXT?
        ld a,MSG_DELETE_Q
        call util_msg
        call file_newline
        call file_name_text
        ld a,MSG_QMARK
        call util_msg
        xor a
        ld (de),a
        ld hl,dlg_yes_no
        call dialog_run
        or a                        ; 0 = YES
        scf
        ret nz
        ld a,(fi_drive)
        call fdc_select
        ld hl,file_name
        call fs_delete
        jp c,sys_error_nc
        ret

file_rename:
        ld (fi_drive),a
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
        jr c,sys_error_nc
        ret

; fi_text "name.ext" -> fi_new, 11 bytes, upper case, padded. Carry if
; it is not an AMSDOS name.
file_parse:
        ld hl,fi_new
        ld b,11
.clear:
        ld (hl)," "
        inc hl
        djnz .clear
        ld hl,fi_text
        ld de,fi_new
        ld b,8
        call .part
        ret c
        ld a,(hl)
        or a
        jr z,.check
        inc hl                      ; "."
        ld de,fi_new + 8
        ld b,3
        call .part
        ret c
        ld a,(hl)                   ; a second "."
        or a
        scf
        ret nz
.check:
        ld a,(fi_new)               ; no name at all
        cp " "
        scf
        ret z
        or a
        ret
; up to B characters, until the zero or "."
.part:
        ld a,(hl)
        or a
        ret z
        cp "."
        ret z
        cp "a"
        jr c,.upper
        cp "z" + 1
        jr nc,.upper
        sub 32
.upper:
        push hl
        push bc
        ld hl,file_bad_chars
        ld bc,FILE_BAD_COUNT
        cpir
        pop bc
        pop hl
        scf
        ret z
        cp "!"                      ; spaces, controls, non-ASCII
        ret c
        cp #7F
        ccf
        ret c
        ld (de),a
        inc de
        inc hl
        djnz .part
        ld a,(hl)                   ; B characters done: must end here
        or a
        ret z
        cp "."
        ret z
        scf
        ret

file_bad_chars: db "*?,;:=[]<>|"
FILE_BAD_COUNT  equ $ - file_bad_chars

; A = FDC_ERR_* / FS_ERR_* -> error dialog. Carry kept clear: the disc
; may have changed.
sys_error_nc:
        call sys_error
        or a
        ret
sys_error:
        add a,MSG_ERR_1 - 1
        ld de,dlg_custom
        call util_msg
        xor a
        ld (de),a
        ld hl,dlg_error
        jp dialog_run

; helpers: all write at DE
file_name_text:
        ld hl,file_name
        jp util_fcb_text
file_newline:
        ld a,"|"
        jp util_char
file_label:                         ; A = MSG_*: "TEXT "
        call util_msg
        ld a," "
        jp util_char

dlg_file:       db MSG_DLG_FILE_T, DLG_OWN_TEXT, 1, MSG_BTN_OK
dlg_error:      db MSG_DLG_ERR_T, DLG_OWN_TEXT, 1, MSG_BTN_OK
dlg_yes_no:     db MSG_DLG_FILE_T, DLG_OWN_TEXT, 2, MSG_BTN_YES, MSG_BTN_NO

file_name:      ds 11
fi_new:         ds 11
fi_text:        ds FILE_TEXT_MAX + 2  ; + the cursor of input_run
fi_drive:       db 0
fi_target:      db 0
