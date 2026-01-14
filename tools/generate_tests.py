#!/usr/bin/env python3
"""
Simple script to generate test binary programs for HackVM.
These are hand-assembled examples until we have a proper assembler.
"""

import struct
import os

# Opcode definitions (from opcodes.zig)
NOP     = 0x00
HALT    = 0x01
DISPLAY = 0x02
RET     = 0x03
PUSHF   = 0x04
POPF    = 0x05

MOV     = 0x10
MOVI    = 0x11
LOAD    = 0x12
LOADB   = 0x13
STORE   = 0x14
STOREB  = 0x15
PUSH    = 0x16
POP     = 0x17

ADD     = 0x20
ADDI    = 0x21
SUB     = 0x22
SUBI    = 0x23
MUL     = 0x24
DIV     = 0x25
INC     = 0x26
DEC     = 0x27
NEG     = 0x28

AND     = 0x30
ANDI    = 0x31
OR      = 0x32
ORI     = 0x33
XOR     = 0x34
XORI    = 0x35
NOT     = 0x36
SHL     = 0x37
SHLI    = 0x38
SHR     = 0x39
SHRI    = 0x3A
SAR     = 0x3B
SARI    = 0x3C

CMP     = 0x40
CMPI    = 0x41
TEST    = 0x42
TESTI   = 0x43

JMP     = 0x50
JMPR    = 0x51
JZ      = 0x52
JNZ     = 0x53
JC      = 0x54
JNC     = 0x55
JN      = 0x56
JNN     = 0x57
JO      = 0x58
JNO     = 0x59
JA      = 0x5A
JBE     = 0x5B
JG      = 0x5C
JGE     = 0x5D
JL      = 0x5E
JLE     = 0x5F
CALL    = 0x60
CALLR   = 0x61

MEMCPY  = 0x70
MEMSET  = 0x71

def write_program(filename, bytecode):
    """Write bytecode to a binary file."""
    with open(filename, 'wb') as f:
        f.write(bytes(bytecode))
    print(f"Wrote {len(bytecode)} bytes to {filename}")

def reg_byte(rd, rs=0):
    """Encode register byte: [Rd:3][Rs:3][xx:2]"""
    return ((rd & 0x07) << 5) | ((rs & 0x07) << 2)

def imm16_le(val):
    """Return 16-bit value as little-endian bytes."""
    return [val & 0xFF, (val >> 8) & 0xFF]

# =============================================================================
# Test Program 1: Fill screen with red
# =============================================================================
def make_fill_red():
    code = []
    
    # MOVI R0, 0x4000
    code.append(MOVI)
    code.append(reg_byte(0, 0))
    code.extend(imm16_le(0x4000))
    
    # MOVI R1, 0xE0 (red)
    code.append(MOVI)
    code.append(reg_byte(1, 0))
    code.extend(imm16_le(0x00E0))
    
    # MOVI R2, 16384
    code.append(MOVI)
    code.append(reg_byte(2, 0))
    code.extend(imm16_le(16384))
    
    # MEMSET
    code.append(MEMSET)
    
    # DISPLAY
    code.append(DISPLAY)
    
    # HALT
    code.append(HALT)
    
    return code

# =============================================================================
# Test Program 2: Color gradient
# =============================================================================
def make_gradient():
    code = []
    
    # MOVI R4, 0x4000
    code.append(MOVI)
    code.append(reg_byte(4, 0))
    code.extend(imm16_le(0x4000))
    
    # MOVI R5, 0
    code.append(MOVI)
    code.append(reg_byte(5, 0))
    code.extend(imm16_le(0))
    
    # MOVI R6, 128
    code.append(MOVI)
    code.append(reg_byte(6, 0))
    code.extend(imm16_le(128))
    
    row_loop = len(code)
    
    # MOV R0, R4
    code.append(MOV)
    code.append(reg_byte(0, 4))
    
    # MOV R1, R5
    code.append(MOV)
    code.append(reg_byte(1, 5))
    
    # MOVI R2, 128
    code.append(MOVI)
    code.append(reg_byte(2, 0))
    code.extend(imm16_le(128))
    
    # MEMSET
    code.append(MEMSET)
    
    # MOVI R3, 128
    code.append(MOVI)
    code.append(reg_byte(3, 0))
    code.extend(imm16_le(128))
    
    # ADD R4, R3
    code.append(ADD)
    code.append(reg_byte(4, 3))
    
    # INC R5
    code.append(INC)
    code.append(reg_byte(5, 0))
    
    # DEC R6
    code.append(DEC)
    code.append(reg_byte(6, 0))
    
    # JNZ row_loop
    code.append(JNZ)
    code.extend(imm16_le(row_loop))
    
    # DISPLAY
    code.append(DISPLAY)
    
    # HALT
    code.append(HALT)
    
    return code

# =============================================================================
# Test Program 3: Animated color cycle
# =============================================================================
def make_color_cycle():
    code = []
    
    # MOVI R7, 0
    code.append(MOVI)
    code.append(reg_byte(7, 0))
    code.extend(imm16_le(0))
    
    frame_loop = len(code)
    
    # MOVI R0, 0x4000
    code.append(MOVI)
    code.append(reg_byte(0, 0))
    code.extend(imm16_le(0x4000))
    
    # MOV R1, R7
    code.append(MOV)
    code.append(reg_byte(1, 7))
    
    # MOVI R2, 16384
    code.append(MOVI)
    code.append(reg_byte(2, 0))
    code.extend(imm16_le(16384))
    
    # MEMSET
    code.append(MEMSET)
    
    # DISPLAY
    code.append(DISPLAY)
    
    # INC R7
    code.append(INC)
    code.append(reg_byte(7, 0))
    
    # JMP frame_loop
    code.append(JMP)
    code.extend(imm16_le(frame_loop))
    
    return code

# =============================================================================
# Test Program 4: Keyboard test - change color on keypress
# =============================================================================
def make_keyboard_test():
    code = []
    
    frame_loop = 0
    
    # MOVI R0, 0xFFF5 (KEY_STATE)
    code.append(MOVI)
    code.append(reg_byte(0, 0))
    code.extend(imm16_le(0xFFF5))
    
    # LOADB R1, [R0]
    code.append(LOADB)
    code.append(reg_byte(1, 0))
    
    # CMPI R1, 0
    code.append(CMPI)
    code.append(reg_byte(1, 0))
    code.append(0)
    
    # JZ no_key
    jz_addr = len(code)
    code.append(JZ)
    code.extend(imm16_le(0))  # Placeholder
    
    # MOVI R0, 0xFFF4 (KEY_CODE)
    code.append(MOVI)
    code.append(reg_byte(0, 0))
    code.extend(imm16_le(0xFFF4))
    
    # LOADB R7, [R0]
    code.append(LOADB)
    code.append(reg_byte(7, 0))
    
    no_key = len(code)
    
    # Patch JZ target
    code[jz_addr + 1] = no_key & 0xFF
    code[jz_addr + 2] = (no_key >> 8) & 0xFF
    
    # MOVI R0, 0x4000
    code.append(MOVI)
    code.append(reg_byte(0, 0))
    code.extend(imm16_le(0x4000))
    
    # MOV R1, R7
    code.append(MOV)
    code.append(reg_byte(1, 7))
    
    # MOVI R2, 16384
    code.append(MOVI)
    code.append(reg_byte(2, 0))
    code.extend(imm16_le(16384))
    
    # MEMSET
    code.append(MEMSET)
    
    # DISPLAY
    code.append(DISPLAY)
    
    # JMP frame_loop
    code.append(JMP)
    code.extend(imm16_le(frame_loop))
    
    return code

# =============================================================================
# Test Program 5: Moving pixel with arrow keys
# =============================================================================
def make_moving_pixel():
    code = []
    
    # Initialize position to center
    # MOVI R4, 64
    code.append(MOVI)
    code.append(reg_byte(4, 0))
    code.extend(imm16_le(64))
    
    # MOVI R5, 64
    code.append(MOVI)
    code.append(reg_byte(5, 0))
    code.extend(imm16_le(64))
    
    frame_loop = len(code)
    
    # === Clear screen ===
    # MOVI R0, 0x4000
    code.append(MOVI)
    code.append(reg_byte(0, 0))
    code.extend(imm16_le(0x4000))
    
    # MOVI R1, 0 (black)
    code.append(MOVI)
    code.append(reg_byte(1, 0))
    code.extend(imm16_le(0))
    
    # MOVI R2, 16384
    code.append(MOVI)
    code.append(reg_byte(2, 0))
    code.extend(imm16_le(16384))
    
    # MEMSET
    code.append(MEMSET)
    
    # === Handle input ===
    # MOVI R0, 0xFFF5 (KEY_STATE)
    code.append(MOVI)
    code.append(reg_byte(0, 0))
    code.extend(imm16_le(0xFFF5))
    
    # LOADB R1, [R0]
    code.append(LOADB)
    code.append(reg_byte(1, 0))
    
    # CMPI R1, 0
    code.append(CMPI)
    code.append(reg_byte(1, 0))
    code.append(0)
    
    # JZ draw_pixel
    jz_to_draw = len(code)
    code.append(JZ)
    code.extend(imm16_le(0))  # Placeholder
    
    # Read key code
    # MOVI R0, 0xFFF4
    code.append(MOVI)
    code.append(reg_byte(0, 0))
    code.extend(imm16_le(0xFFF4))
    
    # LOADB R1, [R0]
    code.append(LOADB)
    code.append(reg_byte(1, 0))
    
    # Check UP (0x80)
    code.append(CMPI)
    code.append(reg_byte(1, 0))
    code.append(0x80)
    
    jnz_not_up = len(code)
    code.append(JNZ)
    code.extend(imm16_le(0))
    
    # DEC R5 (Y--)
    code.append(DEC)
    code.append(reg_byte(5, 0))
    
    jmp_to_draw1 = len(code)
    code.append(JMP)
    code.extend(imm16_le(0))
    
    not_up = len(code)
    code[jnz_not_up + 1] = not_up & 0xFF
    code[jnz_not_up + 2] = (not_up >> 8) & 0xFF
    
    # Check DOWN (0x81)
    code.append(CMPI)
    code.append(reg_byte(1, 0))
    code.append(0x81)
    
    jnz_not_down = len(code)
    code.append(JNZ)
    code.extend(imm16_le(0))
    
    # INC R5 (Y++)
    code.append(INC)
    code.append(reg_byte(5, 0))
    
    jmp_to_draw2 = len(code)
    code.append(JMP)
    code.extend(imm16_le(0))
    
    not_down = len(code)
    code[jnz_not_down + 1] = not_down & 0xFF
    code[jnz_not_down + 2] = (not_down >> 8) & 0xFF
    
    # Check LEFT (0x82)
    code.append(CMPI)
    code.append(reg_byte(1, 0))
    code.append(0x82)
    
    jnz_not_left = len(code)
    code.append(JNZ)
    code.extend(imm16_le(0))
    
    # DEC R4 (X--)
    code.append(DEC)
    code.append(reg_byte(4, 0))
    
    jmp_to_draw3 = len(code)
    code.append(JMP)
    code.extend(imm16_le(0))
    
    not_left = len(code)
    code[jnz_not_left + 1] = not_left & 0xFF
    code[jnz_not_left + 2] = (not_left >> 8) & 0xFF
    
    # Check RIGHT (0x83)
    code.append(CMPI)
    code.append(reg_byte(1, 0))
    code.append(0x83)
    
    jnz_draw = len(code)
    code.append(JNZ)
    code.extend(imm16_le(0))
    
    # INC R4 (X++)
    code.append(INC)
    code.append(reg_byte(4, 0))
    
    # === Draw pixel ===
    draw_pixel = len(code)
    
    # Patch all jumps to draw_pixel
    for addr in [jz_to_draw, jmp_to_draw1, jmp_to_draw2, jmp_to_draw3, jnz_draw]:
        code[addr + 1] = draw_pixel & 0xFF
        code[addr + 2] = (draw_pixel >> 8) & 0xFF
    
    # Clamp positions with AND 0x7F
    code.append(ANDI)
    code.append(reg_byte(4, 0))
    code.append(0x7F)
    
    code.append(ANDI)
    code.append(reg_byte(5, 0))
    code.append(0x7F)
    
    # Calculate pixel address: 0x4000 + Y*128 + X
    # MOVI R3, 128
    code.append(MOVI)
    code.append(reg_byte(3, 0))
    code.extend(imm16_le(128))
    
    # MOV R0, R5
    code.append(MOV)
    code.append(reg_byte(0, 5))
    
    # MUL R0, R3
    code.append(MUL)
    code.append(reg_byte(0, 3))
    
    # ADD R0, R4
    code.append(ADD)
    code.append(reg_byte(0, 4))
    
    # MOVI R3, 0x4000
    code.append(MOVI)
    code.append(reg_byte(3, 0))
    code.extend(imm16_le(0x4000))
    
    # ADD R0, R3
    code.append(ADD)
    code.append(reg_byte(0, 3))
    
    # MOVI R1, 0xFF (white)
    code.append(MOVI)
    code.append(reg_byte(1, 0))
    code.extend(imm16_le(0xFF))
    
    # STOREB [R0], R1
    code.append(STOREB)
    code.append(reg_byte(0, 1))
    
    # DISPLAY
    code.append(DISPLAY)
    
    # JMP frame_loop
    code.append(JMP)
    code.extend(imm16_le(frame_loop))
    
    return code


if __name__ == '__main__':
    # Get the script's directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    examples_dir = os.path.join(project_dir, 'examples')
    
    # Ensure examples directory exists
    os.makedirs(examples_dir, exist_ok=True)
    
    write_program(os.path.join(examples_dir, 'fill_red.bin'), make_fill_red())
    write_program(os.path.join(examples_dir, 'gradient.bin'), make_gradient())
    write_program(os.path.join(examples_dir, 'color_cycle.bin'), make_color_cycle())
    write_program(os.path.join(examples_dir, 'keyboard_test.bin'), make_keyboard_test())
    write_program(os.path.join(examples_dir, 'moving_pixel.bin'), make_moving_pixel())
    
    print("\nAll test programs generated!")
    print("Build the emulator with: zig build wasm")
    print("Then open web/index.html and load a .bin file")
