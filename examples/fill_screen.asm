; fill_screen.asm
; Fills the screen with red color using MEMSET
;
; This is a simple test program for HackVM

.equ    FRAMEBUFFER, 0x4000
.equ    SCREEN_SIZE, 16384
.equ    RED, 0xE0

.org    0x0000

start:
    ; Set up MEMSET registers
    ; R0 = destination address
    ; R1 = fill value
    ; R2 = byte count
    
    MOVI    R0, FRAMEBUFFER     ; R0 = 0x4000
    MOVI    R1, RED             ; R1 = 0xE0 (red)
    MOVI    R2, SCREEN_SIZE     ; R2 = 16384
    
    MEMSET                      ; Fill screen
    
    DISPLAY                     ; Show result
    
    HALT                        ; Stop
