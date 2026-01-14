; color_cycle.asm
; Animates through all 256 colors continuously
;
; This demonstrates:
; - Animation loops
; - Continuous execution (no HALT in main loop)
; - DISPLAY instruction for vsync

.equ    FRAMEBUFFER, 0x4000
.equ    SCREEN_SIZE, 16384

.org    0x0000

start:
    MOVI    R7, 0               ; Current color

frame_loop:
    ; Fill screen with current color
    MOVI    R0, FRAMEBUFFER
    MOV     R1, R7              ; Use current color
    MOVI    R2, SCREEN_SIZE
    MEMSET
    
    ; Display the frame
    DISPLAY
    
    ; Next color (wraps automatically at 256 due to 8-bit truncation)
    INC     R7
    
    ; Loop forever
    JMP     frame_loop
