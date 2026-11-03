; =====================================================================
; vos_drive.inc - the drives for a program's OPEN and SAVE: included
; with the program's code (after vos_api.inc).
;
; vos_next_drive: HL -> the program's drive byte -> the next drive
; there (A: -> B: -> DISK with an M4 board, VX_DRIVE; on a V-OS older
; than version 29 A: <-> B:) and in A.
; vos_drive_text: A = drive, DE -> where -> "A:", "B:" or "DISK:"
; there, DE after it (BC, HL kept).
; =====================================================================

vos_next_drive:
        push hl
        ld c,(hl)
        ld a,VX_DRIVE
        call VOS_EXT
        pop hl
        jr nc,.set
        ld a,(hl)
        xor 1
.set:
        ld (hl),a
        ret

vos_drive_text:
        cp 2
        jr nc,.disk
        add a,"A"
        ld (de),a
        inc de
        ld a,":"
        ld (de),a
        inc de
        ret
.disk:
        push bc
        push hl
        ld hl,.text
        ld bc,5
        ldir
        pop hl
        pop bc
        ret
.text:  db "DISK:"
