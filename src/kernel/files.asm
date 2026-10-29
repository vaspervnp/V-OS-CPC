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
;   file_format   ask, then format the drive (DATA)
; Copying onto a file of the same name asks first.
; file_name and sys_drive also say which file is selected, so the next
; view selects it again (file_find).
; Copy, delete and rename return carry when nothing was tried (the user
; said no); otherwise the disc may have changed, so the view reads it
; again. Errors are shown with sys_error.
; =====================================================================

FILE_VIEW_BYTES equ 18              ; first bytes shown by file_info
FILE_TEXT_MAX   equ 12              ; "NAME.EXT"

; in the kernel extension (kernel/files_ext.asm); A = drive
file_info:
        ld hl,fx_info
        jr file_ext
file_copy:
        ld hl,fx_copy
        jr file_ext
file_delete:
        ld hl,fx_delete
        jr file_ext
file_rename:
        ld hl,fx_rename
        jr file_ext
file_format:
        ld hl,fx_format
file_ext:
        ld (fi_drive),a
        jp ext_call

; DE = dlg_custom, A = MSG_*: "TEXT|NAME.EXT?", YES / NO -> carry if NO
file_question:
        call util_msg
        call file_newline
        call file_name_text
        ld a,MSG_QMARK
        ; fall through
; A = MSG_* to end the text with -> carry if the answer is NO
file_ask:
        call util_msg
        xor a
        ld (de),a
        ld hl,dlg_yes_no
        call dialog_run
        or a                        ; 0 = YES
        ret z
        scf
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

; FS_CAT -> A = the entry named file_name; carry if there is none
file_find:
        ld a,(fc_count)
        or a
        scf
        ret z
        ld b,a
        ld hl,FS_CAT
        ld c,0
.entry:
        push bc
        push hl
        ld de,file_name
        ld b,11
.compare:
        ld a,(de)
        cp (hl)
        jr nz,.differ
        inc hl
        inc de
        djnz .compare
.differ:
        pop hl
        pop bc
        ld a,c
        ret z
        ld de,16
        add hl,de
        inc c
        djnz .entry
        scf
        ret

; HL -> 11-byte name, A = drive: the selected file
file_select:
        ld (sys_drive),a
        ld de,file_name
        ld bc,11
        ldir
        ret

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
sys_drive:      db 0
fi_new:         ds 11
fi_text:        ds FILE_TEXT_MAX + 2  ; + the cursor of input_run
fi_drive:       db 0
fi_target:      db 0
