; keyboard_test.asm
; Changes screen color based on which key is pressed
;
; This demonstrates:
; - Reading keyboard input from I/O registers
; - Conditional branching based on key state
; - Interactive programs

.equ    FRAMEBUFFER, 0x4000
.equ    SCREEN_SIZE, 16384
.equ    KEY_CODE, 0xFFF4
.equ    KEY_STATE, 0xFFF5

.org    0x0000

start:
    MOVI    R7, 0               ; Current color (starts black)

frame_loop:
    ; Check if a key is pressed
    MOVI    R0, KEY_STATE
    LOADB   R1, [R0]            ; Read key state
    CMPI    R1, 0
    JZ      no_key              ; Skip if no key pressed
    
    ; Key is pressed - read the key code as color
    MOVI    R0, KEY_CODE
    LOADB   R7, [R0]            ; R7 = keycode becomes color

no_key:
    ; Fill screen with current color
    MOVI    R0, FRAMEBUFFER
    MOV     R1, R7
    MOVI    R2, SCREEN_SIZE
    MEMSET
    
    ; Display
    DISPLAY
    
    ; Loop
    JMP     frame_loop
