; fill_red.asm
; Fills the entire screen with red color
;
; This demonstrates basic assembly syntax:
; - Constants with .equ
; - Labels
; - MOVI, MEMSET, DISPLAY, HALT instructions

.equ    FRAMEBUFFER, 0x4000
.equ    SCREEN_SIZE, 16384
.equ    RED, 0xE0

.org    0x0000

start:
    ; Set up MEMSET registers:
    ; R0 = destination address
    ; R1 = fill value (low byte used)
    ; R2 = byte count
    
    MOVI    R0, FRAMEBUFFER     ; R0 = 0x4000
    MOVI    R1, RED             ; R1 = 0xE0 (red in RGB332)
    MOVI    R2, SCREEN_SIZE     ; R2 = 16384
    
    MEMSET                      ; Fill the screen
    
    DISPLAY                     ; Show the result
    
    HALT                        ; Stop execution
