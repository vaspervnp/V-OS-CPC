; =====================================================================
; loader.asm - entry point run by AMSDOS after RUN"VOS"
;
; VOS.BIN is loaded at LOADER_ADDR. It holds this stub followed by the
; kernel image, which is assembled for KERNEL_BASE. The stub:
;   1. loads the language pack GREEK.LNG to LANG_LOAD through AMSDOS,
;      while the firmware still runs (until M4 brings V-OS's own disc
;      driver); a missing file only means English,
;   2. takes the machine away from the firmware,
;   3. moves the kernel into place.
; =====================================================================

CAS_IN_OPEN     equ #BC77
CAS_IN_CLOSE    equ #BC7A
CAS_IN_DIRECT   equ #BC83
KL_INIT_BACK    equ #BCCE
AMSDOS_ROM      equ 7
AMSDOS_DRIVE    equ #BE7D           ; -> AMSDOS work area, +0 = drive

loader_start:
        ; Running a binary resets the firmware to tape, so start AMSDOS
        ; again, keeping the drive VOS.BIN came from.
        ld hl,(AMSDOS_DRIVE)
        ld a,(hl)
        push af
        ld c,AMSDOS_ROM
        ld de,#0040
        ld hl,#B0FF
        call KL_INIT_BACK
        pop af
        ld hl,(AMSDOS_DRIVE)
        ld (hl),a

        ld hl,LANG_LOAD             ; no magic unless the load succeeds
        ld (hl),0
        ld b,lang_file_end - lang_file
        ld hl,lang_file
        ld de,LANG_DISC_BUF
        call CAS_IN_OPEN
        jr nc,.no_pack
        ld hl,LANG_LOAD
        call CAS_IN_DIRECT
        call CAS_IN_CLOSE
.no_pack:
        di
        ; both ROMs off, mode 1, reset the interrupt counter
        ld bc,GA_PORT + GA_RMR + GA_RMR_LOROM_OFF + GA_RMR_HIROM_OFF + GA_RMR_INT_RESET + 1
        out (c),c
        ; plain 64K RAM layout
        ld bc,GA_PORT + GA_RAMCFG
        out (c),c
        ; copy the kernel to #0000 (destination is below the source,
        ; so a forward LDIR is safe even if the ranges overlap)
        ld hl,kernel_image
        ld de,KERNEL_BASE
        ld bc,KERNEL_SIZE
        ldir
        jp kernel_entry

lang_file:      db "GREEK.LNG"
lang_file_end:
