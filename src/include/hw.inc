; =====================================================================
; hw.inc - Amstrad CPC 6128 hardware ports and constants
; =====================================================================

; ---- Gate Array (port #7Fxx) ----------------------------------------
GA_PORT         equ #7F00
GA_PEN          equ #00             ; %000ppppp  select pen 0..15
GA_BORDER       equ #10             ; %0001xxxx  select border
GA_INK          equ #40             ; %010ccccc  hardware colour for selected pen
GA_RMR          equ #80             ; %100iulmm  ROM/mode register
GA_RMR_LOROM_OFF equ %00000100
GA_RMR_HIROM_OFF equ %00001000
GA_RMR_INT_RESET equ %00010000      ; reset the 52-line interrupt counter
GA_RAMCFG       equ #C0             ; %11bbbccc  RAM banking (6128)

; ---- CRTC 6845 ------------------------------------------------------
CRTC_SELECT     equ #BC00
CRTC_WRITE      equ #BD00

; ---- PPI 8255 -------------------------------------------------------
PPI_A           equ #F400
PPI_B           equ #F500           ; bit 0 = VSYNC
PPI_C           equ #F600
PPI_CONTROL     equ #F700

; ---- FDC uPD765 -----------------------------------------------------
FDC_MOTOR       equ #FA7E
FDC_STATUS      equ #FB7E
FDC_DATA        equ #FB7F
