; gradient.asm
; Displays a color gradient - each row is a different color
;
; This demonstrates:
; - Loop structures with conditional jumps
; - Working with the framebuffer row by row
; - MEMSET for efficient row filling

.equ    FRAMEBUFFER, 0x4000
.equ    ROW_SIZE, 128

.org    0x0000

start:
    MOVI    R4, FRAMEBUFFER     ; Current row address
    MOVI    R5, 0               ; Current color (0-127)
    MOVI    R6, 128             ; Row counter

row_loop:
    ; Fill this row with current color using MEMSET
    MOV     R0, R4              ; dst = current row
    MOV     R1, R5              ; val = current color
    MOVI    R2, ROW_SIZE        ; count = 128 bytes (one row)
    MEMSET
    
    ; Advance to next row
    MOVI    R3, ROW_SIZE
    ADD     R4, R3              ; address += 128
    
    ; Next color
    INC     R5
    
    ; Decrement row counter
    DEC     R6
    JNZ     row_loop            ; Loop if rows remaining
    
    ; Display and halt
    DISPLAY
    HALT
