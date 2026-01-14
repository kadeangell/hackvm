; moving_pixel.asm
; Move a white pixel around with arrow keys
;
; This demonstrates:
; - Multi-key input handling
; - Position tracking
; - Screen coordinate calculations (y * 128 + x)
; - Boundary clamping

.equ    FRAMEBUFFER, 0x4000
.equ    SCREEN_SIZE, 16384
.equ    KEY_CODE, 0xFFF4
.equ    KEY_STATE, 0xFFF5

.equ    BLACK, 0x00
.equ    WHITE, 0xFF

.equ    KEY_UP, 0x80
.equ    KEY_DOWN, 0x81
.equ    KEY_LEFT, 0x82
.equ    KEY_RIGHT, 0x83

.org    0x0000

start:
    ; Initialize position to center of screen
    MOVI    R4, 64              ; X position
    MOVI    R5, 64              ; Y position

frame_loop:
    ; === Clear screen ===
    MOVI    R0, FRAMEBUFFER
    MOVI    R1, BLACK
    MOVI    R2, SCREEN_SIZE
    MEMSET
    
    ; === Handle input ===
    MOVI    R0, KEY_STATE
    LOADB   R1, [R0]
    CMPI    R1, 0
    JZ      draw_pixel          ; No key pressed, skip to draw
    
    ; Read key code
    MOVI    R0, KEY_CODE
    LOADB   R1, [R0]
    
    ; Check UP
    CMPI    R1, KEY_UP
    JNZ     not_up
    DEC     R5                  ; Y--
    JMP     clamp
not_up:
    ; Check DOWN
    CMPI    R1, KEY_DOWN
    JNZ     not_down
    INC     R5                  ; Y++
    JMP     clamp
not_down:
    ; Check LEFT
    CMPI    R1, KEY_LEFT
    JNZ     not_left
    DEC     R4                  ; X--
    JMP     clamp
not_left:
    ; Check RIGHT
    CMPI    R1, KEY_RIGHT
    JNZ     draw_pixel
    INC     R4                  ; X++

clamp:
    ; Clamp X and Y to 0-127 using AND mask
    ANDI    R4, 0x7F
    ANDI    R5, 0x7F

draw_pixel:
    ; Calculate pixel address: FRAMEBUFFER + Y*128 + X
    MOVI    R3, 128
    MOV     R0, R5              ; R0 = Y
    MUL     R0, R3              ; R0 = Y * 128
    ADD     R0, R4              ; R0 = Y * 128 + X
    MOVI    R3, FRAMEBUFFER
    ADD     R0, R3              ; R0 = address
    
    ; Draw white pixel
    MOVI    R1, WHITE
    STOREB  [R0], R1
    
    ; Display
    DISPLAY
    
    ; Loop
    JMP     frame_loop
