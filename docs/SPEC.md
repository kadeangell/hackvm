# HackVM: Instruction Set Architecture & System Design Specification

**Version:** 1.2  
**Target:** Hackathon Competition Platform

---

## Table of Contents

1. [Overview](#1-overview)
2. [System Architecture](#2-system-architecture)
3. [Memory Map](#3-memory-map)
4. [Registers](#4-registers)
5. [Instruction Set](#5-instruction-set)
6. [Instruction Encoding](#6-instruction-encoding)
7. [Flags Register](#7-flags-register)
8. [Memory-Mapped I/O](#8-memory-mapped-io)
9. [Display System](#9-display-system)
10. [Console System](#10-console-system)
11. [Keyboard Input](#11-keyboard-input)
12. [Timer System](#12-timer-system)
13. [Assembly Language Syntax](#13-assembly-language-syntax)
14. [Execution Model](#14-execution-model)
15. [Example Programs](#15-example-programs)

---

## 1. Overview

HackVM is a 16-bit virtual machine designed for hackathon competitions. It features a simple but capable instruction set, 128x128 pixel graphics with 8-bit color, text console output, keyboard input, and timer support. The emulator is implemented in Zig and compiled to WebAssembly for cross-platform browser-based execution.

### Design Goals

- Accessible to programmers of varying skill levels
- Powerful enough to create games, demos, and interactive applications
- Simple instruction encoding that can be hand-assembled if needed
- Clear memory layout with no hidden complexity
- Text console for debugging and text-based output

---

## 2. System Architecture

| Property | Value |
|----------|-------|
| Word Size | 16-bit |
| Address Space | 64KB (65,536 bytes) |
| Endianness | Little-endian |
| Registers | 8 general-purpose + PC + SP + FLAGS |
| Stack | Grows downward |
| Clock Speed | 4 MHz (4,000,000 cycles/second) |
| Display | 128x128 pixels, 8-bit color (RGB332) |
| Console | Text output buffer (4KB) |

---

## 3. Memory Map

```
+------------------+------------------+---------------------------+
| Start Address    | End Address      | Description               |
+------------------+------------------+---------------------------+
| 0x0000           | 0x3FFF           | Program Memory (16KB)     |
| 0x4000           | 0x7FFF           | Framebuffer (16KB)        |
| 0x8000           | 0xFFEF           | General RAM (32,496 bytes)|
| 0xFFF0           | 0xFFF1           | System Timer (16-bit)     |
| 0xFFF2           | 0xFFF3           | Countdown Timer (16-bit)  |
| 0xFFF4           | 0xFFF4           | Keyboard Keycode (8-bit)  |
| 0xFFF5           | 0xFFF5           | Keyboard State (8-bit)    |
| 0xFFF6           | 0xFFFF           | Reserved (10 bytes)       |
+------------------+------------------+---------------------------+
```

### Memory Regions

**Program Memory (0x0000 - 0x3FFF):** Contains executable code. The program counter (PC) is initialized to 0x0000 at startup. Programs are loaded starting at this address.

**Framebuffer (0x4000 - 0x7FFF):** A 16,384-byte region representing the 128x128 pixel display. Each byte represents one pixel in RGB332 format. The pixel at screen coordinate (x, y) is located at address `0x4000 + (y * 128) + x`.

**General RAM (0x8000 - 0xFFEF):** Available for stack, heap, and data storage. The stack pointer (SP) is initialized to 0xFFEF (top of general RAM) and grows downward.

**Memory-Mapped I/O (0xFFF0 - 0xFFFF):** Special registers for timers and keyboard input.

---

## 4. Registers

### General Purpose Registers

| Register | Encoding | Description |
|----------|----------|-------------|
| R0 | 0b000 | General purpose, often used as accumulator |
| R1 | 0b001 | General purpose |
| R2 | 0b010 | General purpose |
| R3 | 0b011 | General purpose |
| R4 | 0b100 | General purpose |
| R5 | 0b101 | General purpose |
| R6 | 0b110 | General purpose |
| R7 | 0b111 | General purpose |

All general-purpose registers are 16 bits wide and can be used interchangeably for any operation.

### Special Registers

| Register | Width | Description |
|----------|-------|-------------|
| PC | 16-bit | Program Counter - address of next instruction |
| SP | 16-bit | Stack Pointer - points to top of stack |
| FLAGS | 8-bit | Status flags (Zero, Carry, Negative, Overflow) |

---

## 5. Instruction Set

### Instruction Categories

The instruction set is divided into the following categories:

1. **Data Movement** - Moving data between registers and memory
2. **Arithmetic** - Mathematical operations
3. **Logical** - Bitwise operations
4. **Control Flow** - Jumps and subroutine calls
5. **Stack Operations** - Push and pop operations
6. **System** - Display, console, and halt operations

---

### 5.1 Data Movement Instructions

| Mnemonic | Operands | Description | Flags Affected |
|----------|----------|-------------|----------------|
| `MOV` | Rd, Rs | Copy Rs to Rd | None |
| `MOVI` | Rd, imm16 | Load 16-bit immediate into Rd | None |
| `LOAD` | Rd, [Rs] | Load 16-bit value from memory address in Rs | None |
| `LOADB` | Rd, [Rs] | Load 8-bit value from memory (zero-extended) | None |
| `STORE` | [Rd], Rs | Store 16-bit value Rs to memory address in Rd | None |
| `STOREB` | [Rd], Rs | Store low 8 bits of Rs to memory address in Rd | None |

**Notes:**
- `LOAD` and `STORE` operate on 16-bit values and expect even-aligned addresses
- `LOADB` and `STOREB` operate on single bytes, useful for framebuffer access
- Memory operations use the address contained in the register, not the register number

---

### 5.2 Arithmetic Instructions

| Mnemonic | Operands | Description | Flags Affected |
|----------|----------|-------------|----------------|
| `ADD` | Rd, Rs | Rd = Rd + Rs | Z, C, N, V |
| `ADDI` | Rd, imm8 | Rd = Rd + imm8 (unsigned) | Z, C, N, V |
| `SUB` | Rd, Rs | Rd = Rd - Rs | Z, C, N, V |
| `SUBI` | Rd, imm8 | Rd = Rd - imm8 (unsigned) | Z, C, N, V |
| `MUL` | Rd, Rs | Rd = (Rd * Rs) & 0xFFFF (low 16 bits) | Z, N |
| `DIV` | Rd, Rs | Rd = Rd / Rs (unsigned), R0 = remainder | Z, N |
| `INC` | Rd | Rd = Rd + 1 | Z, C, N, V |
| `DEC` | Rd | Rd = Rd - 1 | Z, C, N, V |
| `NEG` | Rd | Rd = -Rd (two's complement) | Z, C, N, V |

**Notes:**
- Division by zero sets Rd to 0xFFFF and R0 (remainder) to the original dividend
- `MUL` discards the upper 16 bits of the result
- `NEG` computes two's complement negation

---

### 5.3 Logical Instructions

| Mnemonic | Operands | Description | Flags Affected |
|----------|----------|-------------|----------------|
| `AND` | Rd, Rs | Rd = Rd & Rs | Z, N |
| `ANDI` | Rd, imm8 | Rd = Rd & imm8 | Z, N |
| `OR` | Rd, Rs | Rd = Rd \| Rs | Z, N |
| `ORI` | Rd, imm8 | Rd = Rd \| imm8 | Z, N |
| `XOR` | Rd, Rs | Rd = Rd ^ Rs | Z, N |
| `XORI` | Rd, imm8 | Rd = Rd ^ imm8 | Z, N |
| `NOT` | Rd | Rd = ~Rd | Z, N |
| `SHL` | Rd, Rs | Rd = Rd << (Rs & 0xF) | Z, C, N |
| `SHLI` | Rd, imm4 | Rd = Rd << imm4 | Z, C, N |
| `SHR` | Rd, Rs | Rd = Rd >> (Rs & 0xF) (logical) | Z, C, N |
| `SHRI` | Rd, imm4 | Rd = Rd >> imm4 (logical) | Z, C, N |
| `SAR` | Rd, Rs | Rd = Rd >> (Rs & 0xF) (arithmetic) | Z, C, N |
| `SARI` | Rd, imm4 | Rd = Rd >> imm4 (arithmetic) | Z, C, N |

**Notes:**
- Shift amounts are masked to 4 bits (0-15)
- `SHR` is logical shift (fills with zeros)
- `SAR` is arithmetic shift (preserves sign bit)
- Carry flag receives the last bit shifted out

---

### 5.4 Comparison Instructions

| Mnemonic | Operands | Description | Flags Affected |
|----------|----------|-------------|----------------|
| `CMP` | Rd, Rs | Compare Rd with Rs (compute Rd - Rs, discard result) | Z, C, N, V |
| `CMPI` | Rd, imm8 | Compare Rd with immediate | Z, C, N, V |
| `TEST` | Rd, Rs | Test bits (compute Rd & Rs, discard result) | Z, N |
| `TESTI` | Rd, imm8 | Test bits with immediate | Z, N |

**Notes:**
- These instructions only affect flags; they do not modify registers
- Use before conditional jumps to make decisions

---

### 5.5 Control Flow Instructions

| Mnemonic | Operands | Description | Condition |
|----------|----------|-------------|-----------|
| `JMP` | addr16 | Unconditional jump | Always |
| `JMPR` | Rs | Jump to address in register | Always |
| `JZ` / `JE` | addr16 | Jump if zero / equal | Z = 1 |
| `JNZ` / `JNE` | addr16 | Jump if not zero / not equal | Z = 0 |
| `JC` / `JB` | addr16 | Jump if carry / below (unsigned) | C = 1 |
| `JNC` / `JAE` | addr16 | Jump if no carry / above or equal | C = 0 |
| `JN` / `JS` | addr16 | Jump if negative / sign set | N = 1 |
| `JNN` / `JNS` | addr16 | Jump if not negative | N = 0 |
| `JO` | addr16 | Jump if overflow | V = 1 |
| `JNO` | addr16 | Jump if no overflow | V = 0 |
| `JA` | addr16 | Jump if above (unsigned) | C = 0 and Z = 0 |
| `JBE` | addr16 | Jump if below or equal (unsigned) | C = 1 or Z = 1 |
| `JG` | addr16 | Jump if greater (signed) | Z = 0 and N = V |
| `JGE` | addr16 | Jump if greater or equal (signed) | N = V |
| `JL` | addr16 | Jump if less (signed) | N ≠ V |
| `JLE` | addr16 | Jump if less or equal (signed) | Z = 1 or N ≠ V |
| `CALL` | addr16 | Push PC+3, jump to address | Always |
| `CALLR` | Rs | Push PC+1, jump to address in Rs | Always |
| `RET` | - | Pop PC from stack | Always |

**Notes:**
- `JE`/`JNE` are aliases for `JZ`/`JNZ` for readability after `CMP`
- `JB`/`JAE`/`JA`/`JBE` are for unsigned comparisons
- `JL`/`JGE`/`JG`/`JLE` are for signed comparisons
- `CALL` pushes the address of the instruction following the call

---

### 5.6 Stack Instructions

| Mnemonic | Operands | Description | Flags Affected |
|----------|----------|-------------|----------------|
| `PUSH` | Rs | Decrement SP by 2, store Rs at [SP] | None |
| `POP` | Rd | Load Rd from [SP], increment SP by 2 | None |
| `PUSHF` | - | Push FLAGS register (as 16-bit, upper 8 bits zero) | None |
| `POPF` | - | Pop FLAGS register | All |

**Notes:**
- Stack grows downward (PUSH decrements SP, POP increments SP)
- SP always points to the last pushed value
- Stack operations are 16-bit aligned

---

### 5.7 Memory Block Instructions

| Mnemonic | Operands | Description | Flags Affected |
|----------|----------|-------------|----------------|
| `MEMCPY` | - | Copy R2 bytes from address [R0] to address [R1] | None |
| `MEMSET` | - | Fill R2 bytes at address [R0] with low byte of R1 | None |

**Register Conventions:**
```
MEMCPY:  R0 = source address
         R1 = destination address
         R2 = byte count

MEMSET:  R0 = destination address
         R1 = value (low 8 bits used)
         R2 = byte count
```

**Notes:**
- Both instructions modify R0, R1, and R2 during execution (they are not preserved)
- After execution: R0 and R1 point past the end of their respective regions, R2 = 0
- `MEMCPY` behavior is undefined if source and destination regions overlap; use manual loops for overlapping copies
- Cycle cost is `5 + N` where N is the byte count, making large copies expensive
- If R2 = 0, no bytes are copied/set and the instruction completes in 5 cycles

**Example Usage:**
```asm
; Clear screen to black (fast)
    MOVI    R0, 0x4000          ; Framebuffer start
    MOVI    R1, 0x00            ; Black color
    MOVI    R2, 16384           ; Screen size
    MEMSET                      ; Fill! (16,389 cycles)

; Copy sprite from ROM to screen position
    MOVI    R0, sprite_data     ; Source
    MOVI    R1, 0x4000          ; Destination (top-left)
    MOVI    R2, 64              ; 8x8 sprite = 64 bytes
    MEMCPY                      ; Copy! (69 cycles)
```

---

### 5.8 System Instructions

| Mnemonic | Operands | Description | Flags Affected |
|----------|----------|-------------|----------------|
| `DISPLAY` | - | Render framebuffer to screen | None |
| `HALT` | - | Stop execution | None |
| `NOP` | - | No operation | None |

**Notes:**
- `DISPLAY` triggers the emulator to copy the framebuffer to the visible display
- `HALT` stops the CPU; the emulator will need to be reset to continue
- Programs should call `DISPLAY` once per frame in their main loop

---

### 5.9 Console Instructions

| Mnemonic | Operands | Description | Flags Affected |
|----------|----------|-------------|----------------|
| `PUTC` | Rs | Write low byte of Rs as ASCII character to console | None |
| `PUTS` | Rs | Write null-terminated string at address [Rs] to console | None |
| `PUTI` | Rs | Write Rs as unsigned decimal integer to console | None |
| `PUTX` | Rs | Write Rs as 4-digit hexadecimal (with 0x prefix) to console | None |

**Notes:**
- Console output is displayed in a text area below the graphics display
- The console buffer is 4KB and operates as a circular buffer (oldest text discarded when full)
- `PUTC` writes a single ASCII character (0x20-0x7E printable, plus `\n` for newline)
- `PUTS` writes characters until a null byte (0x00) is encountered; max 256 chars per call
- `PUTI` converts the 16-bit unsigned value to decimal (0-65535)
- `PUTX` outputs format `0xNNNN` (always 4 hex digits, uppercase)
- Control characters: `\n` (0x0A) creates a new line, `\r` (0x0D) is ignored

**Cycle Costs:**
| Instruction | Cycles | Notes |
|-------------|--------|-------|
| `PUTC` | 2 | Single character output |
| `PUTS` | 3 + N | N = string length (max 256) |
| `PUTI` | 8 | Decimal conversion + output |
| `PUTX` | 6 | Hex conversion + output |

**Example Usage:**
```asm
; Print a single character
    MOVI    R0, 'H'
    PUTC    R0              ; Output: H

; Print a string
    MOVI    R0, message
    PUTS    R0              ; Output: Hello, World!

; Print a number in decimal
    MOVI    R0, 12345
    PUTI    R0              ; Output: 12345

; Print a number in hex
    MOVI    R0, 0x4000
    PUTX    R0              ; Output: 0x4000

; Print newline
    MOVI    R0, 0x0A
    PUTC    R0              ; Output: (newline)

; Data section
message:
    .db "Hello, World!", 0
```

**Debugging Example:**
```asm
; Print register value for debugging
debug_r0:
    PUSH    R0
    PUSH    R1
    MOVI    R1, debug_msg
    PUTS    R1              ; "R0 = "
    PUTX    R0              ; 0xNNNN
    MOVI    R1, 0x0A
    PUTC    R1              ; newline
    POP     R1
    POP     R0
    RET

debug_msg:
    .db "R0 = ", 0
```

---

## 6. Instruction Encoding

Instructions use variable-length encoding (1-4 bytes) to balance code density with simplicity.

### Encoding Format

```
Byte 0: [OPCODE (6 bits)][MODE (2 bits)]
Byte 1: [Rd (3 bits)][Rs (3 bits)][EXT (2 bits)]  (if needed)
Byte 2: [IMM_LOW]                                   (if needed)
Byte 3: [IMM_HIGH]                                  (if needed)
```

### Opcode Table

| Opcode | Mnemonic | Format | Size |
|--------|----------|--------|------|
| 0x00 | NOP | - | 1 |
| 0x01 | HALT | - | 1 |
| 0x02 | DISPLAY | - | 1 |
| 0x03 | RET | - | 1 |
| 0x04 | PUSHF | - | 1 |
| 0x05 | POPF | - | 1 |
| 0x06 | PUTC | Rs | 2 |
| 0x07 | PUTS | Rs | 2 |
| 0x08 | PUTI | Rs | 2 |
| 0x09 | PUTX | Rs | 2 |
| 0x10 | MOV | Rd, Rs | 2 |
| 0x11 | MOVI | Rd, imm16 | 4 |
| 0x12 | LOAD | Rd, [Rs] | 2 |
| 0x13 | LOADB | Rd, [Rs] | 2 |
| 0x14 | STORE | [Rd], Rs | 2 |
| 0x15 | STOREB | [Rd], Rs | 2 |
| 0x16 | PUSH | Rs | 2 |
| 0x17 | POP | Rd | 2 |
| 0x20 | ADD | Rd, Rs | 2 |
| 0x21 | ADDI | Rd, imm8 | 3 |
| 0x22 | SUB | Rd, Rs | 2 |
| 0x23 | SUBI | Rd, imm8 | 3 |
| 0x24 | MUL | Rd, Rs | 2 |
| 0x25 | DIV | Rd, Rs | 2 |
| 0x26 | INC | Rd | 2 |
| 0x27 | DEC | Rd | 2 |
| 0x28 | NEG | Rd | 2 |
| 0x30 | AND | Rd, Rs | 2 |
| 0x31 | ANDI | Rd, imm8 | 3 |
| 0x32 | OR | Rd, Rs | 2 |
| 0x33 | ORI | Rd, imm8 | 3 |
| 0x34 | XOR | Rd, Rs | 2 |
| 0x35 | XORI | Rd, imm8 | 3 |
| 0x36 | NOT | Rd | 2 |
| 0x37 | SHL | Rd, Rs | 2 |
| 0x38 | SHLI | Rd, imm4 | 2 |
| 0x39 | SHR | Rd, Rs | 2 |
| 0x3A | SHRI | Rd, imm4 | 2 |
| 0x3B | SAR | Rd, Rs | 2 |
| 0x3C | SARI | Rd, imm4 | 2 |
| 0x40 | CMP | Rd, Rs | 2 |
| 0x41 | CMPI | Rd, imm8 | 3 |
| 0x42 | TEST | Rd, Rs | 2 |
| 0x43 | TESTI | Rd, imm8 | 3 |
| 0x50 | JMP | addr16 | 3 |
| 0x51 | JMPR | Rs | 2 |
| 0x52 | JZ | addr16 | 3 |
| 0x53 | JNZ | addr16 | 3 |
| 0x54 | JC | addr16 | 3 |
| 0x55 | JNC | addr16 | 3 |
| 0x56 | JN | addr16 | 3 |
| 0x57 | JNN | addr16 | 3 |
| 0x58 | JO | addr16 | 3 |
| 0x59 | JNO | addr16 | 3 |
| 0x5A | JA | addr16 | 3 |
| 0x5B | JBE | addr16 | 3 |
| 0x5C | JG | addr16 | 3 |
| 0x5D | JGE | addr16 | 3 |
| 0x5E | JL | addr16 | 3 |
| 0x5F | JLE | addr16 | 3 |
| 0x60 | CALL | addr16 | 3 |
| 0x61 | CALLR | Rs | 2 |
| 0x70 | MEMCPY | - | 1 |
| 0x71 | MEMSET | - | 1 |

### Encoding Examples

**`NOP`** (1 byte):
```
[0x00]
```

**`MOV R3, R5`** (2 bytes):
```
[0x10][0x74]
       └─ Rd=3 (011), Rs=5 (101), EXT=00 → 0b01110100 = 0x74
```

**`MOVI R2, 0x4000`** (4 bytes):
```
[0x11][0x40][0x00][0x40]
       └─ Rd=2 (010), Rs=0 (000), EXT=00 → 0x40
             └─ Low byte of 0x4000
                   └─ High byte of 0x4000
```

**`JNZ 0x0100`** (3 bytes):
```
[0x53][0x00][0x01]
       └─ Low byte of address
             └─ High byte of address
```

**`PUTC R0`** (2 bytes):
```
[0x06][0x00]
       └─ Rd=0 (000), Rs=0 (000), EXT=00 → 0x00
```

**`PUTS R3`** (2 bytes):
```
[0x07][0x0C]
       └─ Rd=0 (000), Rs=3 (011), EXT=00 → 0x0C
```

---

## 6.1 Instruction Cycle Costs

All instructions have a fixed cycle cost. At 4 MHz, one cycle = 250 nanoseconds.

### Timing Reference

| Cycles | Time @ 4MHz | Per Frame @60fps |
|--------|-------------|------------------|
| 1 | 250 ns | 66,667 available |
| 4 | 1 µs | 16,667 available |
| 100 | 25 µs | 667 available |
| 1000 | 250 µs | 67 available |

### Cycle Costs by Instruction

**System (1-1000 cycles):**
| Instruction | Cycles |
|-------------|--------|
| NOP | 1 |
| HALT | 1 |
| DISPLAY | 1000 |

**Console (2-8+ cycles):**
| Instruction | Cycles | Notes |
|-------------|--------|-------|
| PUTC | 2 | Single character |
| PUTS | 3 + N | N = string length |
| PUTI | 8 | Decimal conversion |
| PUTX | 6 | Hex conversion |

**Data Movement (2-4 cycles):**
| Instruction | Cycles | Notes |
|-------------|--------|-------|
| MOV | 2 | Register to register |
| MOVI | 3 | Load 16-bit immediate |
| LOAD | 4 | Memory read (16-bit) |
| LOADB | 3 | Memory read (8-bit) |
| STORE | 4 | Memory write (16-bit) |
| STOREB | 3 | Memory write (8-bit) |

**Arithmetic (2-12 cycles):**
| Instruction | Cycles | Notes |
|-------------|--------|-------|
| ADD, SUB | 2 | Register-register |
| ADDI, SUBI | 3 | With immediate |
| INC, DEC | 2 | |
| NEG | 2 | |
| MUL | 8 | Multiplication is expensive |
| DIV | 12 | Division is very expensive |

**Logical (2-3 cycles):**
| Instruction | Cycles | Notes |
|-------------|--------|-------|
| AND, OR, XOR, NOT | 2 | Register operations |
| ANDI, ORI, XORI | 3 | With immediate |
| SHL, SHR, SAR | 2 | Register shift amount |
| SHLI, SHRI, SARI | 2 | Immediate shift amount |

**Comparison (2-3 cycles):**
| Instruction | Cycles |
|-------------|--------|
| CMP, TEST | 2 |
| CMPI, TESTI | 3 |

**Control Flow (2-6 cycles):**
| Instruction | Cycles | Notes |
|-------------|--------|-------|
| JMP | 3 | Unconditional |
| JMPR | 2 | Register indirect |
| Jcc (taken) | 4 | Conditional jump, branch taken |
| Jcc (not taken) | 2 | Conditional jump, branch not taken |
| CALL | 6 | Push + jump |
| CALLR | 5 | Register indirect call |
| RET | 5 | Pop + jump |

**Stack (3-4 cycles):**
| Instruction | Cycles |
|-------------|--------|
| PUSH | 4 |
| POP | 4 |
| PUSHF | 3 |
| POPF | 3 |

**Memory Block (variable):**
| Instruction | Cycles | Notes |
|-------------|--------|-------|
| MEMCPY | 5 + N | N = byte count in R2 |
| MEMSET | 5 + N | N = byte count in R2 |

### Cycle Budget Examples

At 60 FPS, you have **66,667 cycles per frame**. Here's what that buys you:

| Operation | Cycles | Times/Frame |
|-----------|--------|-------------|
| Clear screen (MEMSET 16KB) | 16,389 | 4× |
| Copy 8×8 sprite (MEMCPY 64B) | 69 | 966× |
| Single pixel write (STOREB) | 3 | 22,222× |
| Full-screen pixel loop (manual) | ~82,000 | <1× |
| Multiply operation | 8 | 8,333× |
| Function call + return | 11 | 6,060× |
| Print short string (10 chars) | 13 | 5,128× |
| Print hex value | 6 | 11,111× |

**Optimization insight:** Using MEMSET to clear the screen takes ~16K cycles. A manual loop would take approximately `16384 × 5 = 82K` cycles - more than an entire frame! The block operations are essential for real-time graphics.

---

## 7. Flags Register

The FLAGS register is an 8-bit register with the following layout:

```
Bit:  7   6   5   4   3   2   1   0
      -   -   -   -   V   N   C   Z
```

| Bit | Name | Description |
|-----|------|-------------|
| 0 | Z (Zero) | Set if result is zero |
| 1 | C (Carry) | Set if unsigned overflow/borrow occurred |
| 2 | N (Negative) | Set if result has bit 15 set (negative in two's complement) |
| 3 | V (Overflow) | Set if signed overflow occurred |
| 4-7 | - | Reserved (always 0) |

### Flag Behavior

**Zero (Z):** Set when the result of an operation is exactly 0x0000.

**Carry (C):** 
- For addition: set if the result exceeds 0xFFFF (unsigned overflow)
- For subtraction: set if a borrow occurred (Rd < Rs for unsigned)
- For shifts: contains the last bit shifted out

**Negative (N):** Copies bit 15 of the result. In two's complement, this indicates a negative number.

**Overflow (V):** Set when signed overflow occurs:
- Adding two positive numbers yields a negative result
- Adding two negative numbers yields a positive result
- Subtracting a negative from a positive yields a negative result
- Subtracting a positive from a negative yields a positive result

---

## 8. Memory-Mapped I/O

All I/O is performed through memory-mapped registers in the range 0xFFF0-0xFFFF.

| Address | Size | Name | Access | Description |
|---------|------|------|--------|-------------|
| 0xFFF0-0xFFF1 | 16-bit | SYS_TIMER | Read | System timer (milliseconds) |
| 0xFFF2-0xFFF3 | 16-bit | COUNTDOWN | Read/Write | Countdown timer |
| 0xFFF4 | 8-bit | KEY_CODE | Read | Last key pressed |
| 0xFFF5 | 8-bit | KEY_STATE | Read | Current key state |
| 0xFFF6-0xFFFF | 10 bytes | RESERVED | - | Reserved for future use |

---

## 9. Display System

### Framebuffer Layout

The framebuffer occupies addresses 0x4000-0x7FFF (16,384 bytes) and represents a 128x128 pixel display.

**Pixel Addressing:**
```
address = 0x4000 + (y * 128) + x
```

Where:
- x is the horizontal coordinate (0-127, left to right)
- y is the vertical coordinate (0-127, top to bottom)

**Coordinate System:**
```
(0,0) ─────────────────► X (127,0)
  │
  │
  │
  ▼
Y (0,127)              (127,127)
```

### Color Format (RGB332)

Each pixel is one byte in RGB332 format:

```
Bit:  7   6   5   4   3   2   1   0
      R2  R1  R0  G2  G1  G0  B1  B0
```

| Component | Bits | Values | Range |
|-----------|------|--------|-------|
| Red | 7-5 | 3 bits | 0-7 (8 levels) |
| Green | 4-2 | 3 bits | 0-7 (8 levels) |
| Blue | 1-0 | 2 bits | 0-3 (4 levels) |

**Common Colors:**
| Color | R | G | B | Hex Value |
|-------|---|---|---|-----------|
| Black | 0 | 0 | 0 | 0x00 |
| White | 7 | 7 | 3 | 0xFF |
| Red | 7 | 0 | 0 | 0xE0 |
| Green | 0 | 7 | 0 | 0x1C |
| Blue | 0 | 0 | 3 | 0x03 |
| Yellow | 7 | 7 | 0 | 0xFC |
| Cyan | 0 | 7 | 3 | 0x1F |
| Magenta | 7 | 0 | 3 | 0xE3 |
| Orange | 7 | 4 | 0 | 0xF0 |
| Gray (50%) | 3 | 3 | 1 | 0x6D |

### DISPLAY Instruction

The `DISPLAY` instruction copies the framebuffer to the visible screen. The emulator will:

1. Read all 16,384 bytes from the framebuffer region
2. Convert RGB332 to the display's native format
3. Present the frame to the user

**Recommended Usage:**
- Call `DISPLAY` once per frame at the end of your render loop
- Target 30-60 frames per second for smooth animation
- The instruction does not block; rendering is asynchronous

---

## 10. Console System

### Overview

The console provides a text output channel separate from the graphics display. It appears below the main screen in the emulator UI and is useful for:

- Debugging output (register values, state information)
- Text-based game messages
- Error reporting
- Score displays and status messages

### Console Characteristics

| Property | Value |
|----------|-------|
| Buffer Size | 4096 characters |
| Character Set | ASCII (0x20-0x7E printable) |
| Control Characters | 0x0A (newline) |
| Buffer Type | Circular (oldest discarded when full) |
| Max String Length | 256 characters per PUTS call |

### Console Instructions

**PUTC Rs** - Write single character
- Writes the low byte of Rs as an ASCII character
- Non-printable characters (except newline) are ignored
- Cycle cost: 2

**PUTS Rs** - Write null-terminated string
- Rs contains the memory address of the string
- Writes characters until null byte (0x00) is found
- Maximum 256 characters per call (truncated if longer)
- Cycle cost: 3 + N (where N is string length)

**PUTI Rs** - Write unsigned decimal
- Converts Rs to decimal string and outputs
- Range: 0 to 65535
- No leading zeros (except for value 0)
- Cycle cost: 8

**PUTX Rs** - Write hexadecimal
- Outputs Rs in format `0xNNNN`
- Always 4 hex digits, uppercase (A-F)
- Cycle cost: 6

### Console Output Examples

```asm
; Output: "Score: 1234\n"
    MOVI    R0, score_label
    PUTS    R0                  ; "Score: "
    MOVI    R0, 1234
    PUTI    R0                  ; "1234"
    MOVI    R0, 0x0A
    PUTC    R0                  ; newline

score_label:
    .db "Score: ", 0

; Output: "Address: 0x4000\n"
    MOVI    R0, addr_label
    PUTS    R0                  ; "Address: "
    MOVI    R0, 0x4000
    PUTX    R0                  ; "0x4000"
    MOVI    R0, 0x0A
    PUTC    R0                  ; newline

addr_label:
    .db "Address: ", 0
```

### Debugging Utilities

```asm
; Print all registers (useful for debugging)
print_regs:
    PUSH    R0
    PUSH    R1
    
    ; Print R0
    MOVI    R1, r0_label
    PUTS    R1
    POP     R1                  ; Get original R0
    PUSH    R1                  ; Save it again
    MOV     R0, R1
    PUTX    R0
    MOVI    R0, 0x0A
    PUTC    R0
    
    ; ... repeat for other registers ...
    
    POP     R1
    POP     R0
    RET

r0_label:
    .db "R0=", 0
```

### Console vs Graphics

| Feature | Console | Graphics |
|---------|---------|----------|
| Output type | Text | Pixels |
| Update trigger | Immediate | DISPLAY instruction |
| Buffer | 4KB circular | 16KB framebuffer |
| Use case | Debug, messages | Games, visuals |
| Persistence | Scrolling history | Replaced each frame |

---

## 11. Keyboard Input

### Keyboard Registers

**KEY_CODE (0xFFF4):** Contains the keycode of the most recently pressed key. This value persists until another key is pressed.

**KEY_STATE (0xFFF5):** Indicates whether a key is currently being held down:
- 0x00 = No key pressed
- 0x01 = Key is currently pressed

### Keycode Table

| Key | Code | Key | Code | Key | Code |
|-----|------|-----|------|-----|------|
| A | 0x41 | N | 0x4E | 0 | 0x30 |
| B | 0x42 | O | 0x4F | 1 | 0x31 |
| C | 0x43 | P | 0x50 | 2 | 0x32 |
| D | 0x44 | Q | 0x51 | 3 | 0x33 |
| E | 0x45 | R | 0x52 | 4 | 0x34 |
| F | 0x46 | S | 0x53 | 5 | 0x35 |
| G | 0x47 | T | 0x54 | 6 | 0x36 |
| H | 0x48 | U | 0x55 | 7 | 0x37 |
| I | 0x49 | V | 0x56 | 8 | 0x38 |
| J | 0x4A | W | 0x57 | 9 | 0x39 |
| K | 0x4B | X | 0x58 | Space | 0x20 |
| L | 0x4C | Y | 0x59 | Enter | 0x0D |
| M | 0x4D | Z | 0x5A | Escape | 0x1B |

| Key | Code | Key | Code |
|-----|------|-----|------|
| Up Arrow | 0x80 | F1 | 0x90 |
| Down Arrow | 0x81 | F2 | 0x91 |
| Left Arrow | 0x82 | F3 | 0x92 |
| Right Arrow | 0x83 | F4 | 0x93 |
| Backspace | 0x08 | F5 | 0x94 |
| Tab | 0x09 | F6 | 0x95 |
| Shift | 0x84 | F7 | 0x96 |
| Control | 0x85 | F8 | 0x97 |
| Alt | 0x86 | F9 | 0x98 |

### Polling for Input

```asm
; Check if any key is pressed
    MOVI    R0, 0xFFF5      ; KEY_STATE address
    LOADB   R1, [R0]        ; Load key state
    CMPI    R1, 0           ; Is a key pressed?
    JZ      no_key          ; No key pressed

; Read which key
    MOVI    R0, 0xFFF4      ; KEY_CODE address
    LOADB   R1, [R0]        ; Load keycode
    
; Check for specific key (e.g., Space = 0x20)
    CMPI    R1, 0x20
    JZ      space_pressed
```

---

## 12. Timer System

### System Timer (SYS_TIMER)

**Address:** 0xFFF0-0xFFF1 (16-bit, little-endian)
**Behavior:** Increments every millisecond, wraps from 0xFFFF to 0x0000
**Access:** Read-only

The system timer provides a monotonically increasing time reference. It wraps approximately every 65.5 seconds.

**Reading the Timer:**
```asm
    MOVI    R0, 0xFFF0      ; SYS_TIMER address
    LOAD    R1, [R0]        ; Read current time
```

**Calculating Delta Time:**
```asm
; Assumes R7 holds the previous frame's timer value
    MOVI    R0, 0xFFF0
    LOAD    R1, [R0]        ; current_time
    MOV     R2, R1          ; save for next frame
    SUB     R1, R7          ; delta = current - previous (handles wrap correctly)
    MOV     R7, R2          ; update previous time
    ; R1 now contains milliseconds since last frame
```

### Countdown Timer (COUNTDOWN)

**Address:** 0xFFF2-0xFFF3 (16-bit, little-endian)
**Behavior:** Decrements every millisecond, stops at 0x0000
**Access:** Read/Write

Write a value to start a countdown. The timer decrements each millisecond and stops at zero.

**Setting a Delay:**
```asm
; Wait for 500ms
    MOVI    R0, 0xFFF2      ; COUNTDOWN address
    MOVI    R1, 500         ; 500 milliseconds
    STORE   [R0], R1        ; Start countdown

wait_loop:
    LOAD    R1, [R0]        ; Check countdown
    CMPI    R1, 0           ; Has it reached zero?
    JNZ     wait_loop       ; Keep waiting
    ; 500ms have elapsed
```

**Non-Blocking Timer Check:**
```asm
; Check if a previously set timer has elapsed
    MOVI    R0, 0xFFF2
    LOAD    R1, [R0]
    CMPI    R1, 0
    JNZ     timer_running
    ; Timer elapsed, do something
timer_running:
    ; Timer still running, continue with other work
```

---

## 13. Assembly Language Syntax

### General Format

```asm
[label:]    MNEMONIC    [operand1], [operand2]    ; comment
```

### Operand Types

| Syntax | Type | Example |
|--------|------|---------|
| `R0`-`R7` | Register | `MOV R0, R1` |
| `123` | Decimal immediate | `MOVI R0, 255` |
| `0xFF` | Hexadecimal immediate | `MOVI R0, 0x4000` |
| `0b1010` | Binary immediate | `ANDI R0, 0b00001111` |
| `[R0]` | Register indirect | `LOAD R1, [R0]` |
| `label` | Label reference | `JMP main_loop` |

### Directives

| Directive | Description | Example |
|-----------|-------------|---------|
| `.org addr` | Set assembly address | `.org 0x0000` |
| `.db val, ...` | Define bytes | `.db 0x00, 0xFF, 'A'` |
| `.dw val, ...` | Define words (16-bit) | `.dw 0x1234, label` |
| `.ds count` | Define space (reserve bytes) | `.ds 100` |
| `.equ name, val` | Define constant | `.equ SCREEN, 0x4000` |
| `.include "file"` | Include another file | `.include "utils.asm"` |

### Example Program Structure

```asm
; Constants
.equ    FRAMEBUFFER, 0x4000
.equ    KEY_STATE, 0xFFF5
.equ    WHITE, 0xFF
.equ    BLACK, 0x00

; Program entry point
.org    0x0000

start:
    ; Print startup message
    MOVI    R0, startup_msg
    PUTS    R0
    
    ; Initialize stack pointer (already done by emulator, but explicit)
    MOVI    SP, 0xFFEF
    
    ; Clear screen
    CALL    clear_screen
    
main_loop:
    ; Game logic here
    CALL    handle_input
    CALL    update_game
    CALL    render
    
    ; Display frame
    DISPLAY
    
    ; Loop forever
    JMP     main_loop

; Subroutine: Clear screen to black
clear_screen:
    MOVI    R0, FRAMEBUFFER     ; Destination
    MOVI    R1, BLACK           ; Color
    MOVI    R2, 16384           ; Count
    MEMSET                      ; Fast fill
    RET

; Data
startup_msg:
    .db "Game starting...", 0x0A, 0

; ... more subroutines ...
```

---

## 14. Execution Model

### Clock Speed

The emulator runs at a fixed **4 MHz** clock speed (4,000,000 cycles per second). Each instruction consumes a specific number of cycles as documented in Section 6.1.

**Timing characteristics:**
- 1 cycle = 250 nanoseconds
- 66,667 cycles available per frame at 60 FPS
- 133,333 cycles available per frame at 30 FPS

### Startup

1. All memory is initialized to 0x00
2. Program binary is loaded starting at address 0x0000
3. All registers (R0-R7) are set to 0x0000
4. PC is set to 0x0000
5. SP is set to 0xFFEF
6. FLAGS is set to 0x00
7. Timers begin running (system timer starts at 0)
8. Console buffer is cleared
9. Cycle counter begins
10. Execution begins

### Instruction Cycle

1. Fetch instruction byte(s) from memory at PC
2. Decode instruction
3. Execute instruction
4. Add instruction's cycle cost to cycle counter
5. Update PC (unless instruction modified it)
6. If cycle counter >= cycles per time slice, synchronize with wall clock
7. Repeat

### Emulator Timing

The emulator maintains real-time synchronization:

1. **Cycle accumulator:** Tracks cycles executed since last sync point
2. **Wall clock comparison:** Periodically compares accumulated cycles to elapsed real time
3. **Throttling:** If running too fast, the emulator sleeps to maintain 4 MHz rate
4. **Catching up:** If running too slow (host can't keep up), cycles are not skipped - the emulation runs slower than real-time

This ensures:
- Timer values correspond to real wall-clock time
- Programs behave consistently across different host machines
- The experience is deterministic for competition fairness

### Frame Timing

For smooth 60 FPS animation, programs should:

1. Complete all game logic and rendering within ~66,000 cycles
2. Call `DISPLAY` to present the frame
3. Use the system timer to measure frame time and maintain consistent pacing

**Example frame loop:**
```asm
.equ FRAME_CYCLES, 66667    ; Target cycles per frame
.equ SYS_TIMER, 0xFFF0

main_loop:
    ; Store frame start time
    MOVI    R7, SYS_TIMER
    LOAD    R6, [R7]        ; R6 = frame start time
    
    ; --- Game logic and rendering here ---
    CALL    update
    CALL    render
    
    ; Present frame
    DISPLAY
    
    ; Wait for frame boundary (simple busy-wait)
.wait:
    LOAD    R0, [R7]        ; Current time
    SUB     R0, R6          ; Elapsed ms
    CMPI    R0, 16          ; 16ms = ~60fps
    JL      .wait
    
    JMP     main_loop
```

### Halting

The `HALT` instruction stops execution. The emulator will:
1. Stop the instruction cycle
2. Display final cycle count and execution time
3. Keep the last frame displayed
4. Keep console output visible
5. Require a reset/reload to continue

---

## 15. Example Programs

### Example 1: Hello World (Console)

```asm
.org    0x0000

    MOVI    R0, hello_msg
    PUTS    R0
    HALT

hello_msg:
    .db "Hello, World!", 0x0A, 0
```

### Example 2: Fill Screen with Color

```asm
.equ    FRAMEBUFFER, 0x4000
.equ    SCREEN_SIZE, 16384
.equ    COLOR, 0xE0             ; Red

.org    0x0000

    ; Print status
    MOVI    R0, msg
    PUTS    R0

    ; Using MEMSET - the fast way!
    MOVI    R0, FRAMEBUFFER     ; Destination address
    MOVI    R1, COLOR           ; Fill value
    MOVI    R2, SCREEN_SIZE     ; Byte count
    MEMSET                      ; Done in ~16,389 cycles
    
    DISPLAY                     ; Show result
    HALT                        ; Stop

msg:
    .db "Filling screen with red...", 0x0A, 0
```

### Example 3: Counter with Console Output

```asm
.org    0x0000

    MOVI    R7, 0               ; Counter

loop:
    ; Print "Count: NNNN\n"
    MOVI    R0, count_msg
    PUTS    R0
    MOV     R0, R7
    PUTI    R0
    MOVI    R0, 0x0A
    PUTC    R0
    
    ; Increment and loop
    INC     R7
    CMPI    R7, 10
    JL      loop
    
    ; Done
    MOVI    R0, done_msg
    PUTS    R0
    HALT

count_msg:
    .db "Count: ", 0

done_msg:
    .db "Done!", 0x0A, 0
```

### Example 4: Moving Square with Debug Output

```asm
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

    ; Print instructions
    MOVI    R0, help_msg
    PUTS    R0

    ; R4 = X position (0-127)
    ; R5 = Y position (0-127)
    MOVI    R4, 60              ; Start X
    MOVI    R5, 60              ; Start Y

main_loop:
    ; Clear screen (using MEMSET - fast!)
    MOVI    R0, FRAMEBUFFER     ; Destination
    MOVI    R1, BLACK           ; Color
    MOVI    R2, SCREEN_SIZE     ; Count
    MEMSET                      ; ~16,389 cycles
    
    ; Handle input
    CALL    handle_input
    
    ; Draw square at (R4, R5)
    CALL    draw_square
    
    ; Display
    DISPLAY
    
    JMP     main_loop

handle_input:
    MOVI    R0, KEY_STATE
    LOADB   R1, [R0]
    CMPI    R1, 0
    JZ      .no_input           ; No key pressed
    
    MOVI    R0, KEY_CODE
    LOADB   R1, [R0]
    
    ; Check Up
    CMPI    R1, KEY_UP
    JNZ     .not_up
    DEC     R5                  ; Y--
    CALL    print_pos           ; Debug output
    JMP     .clamp
.not_up:
    ; Check Down
    CMPI    R1, KEY_DOWN
    JNZ     .not_down
    INC     R5                  ; Y++
    CALL    print_pos
    JMP     .clamp
.not_down:
    ; Check Left
    CMPI    R1, KEY_LEFT
    JNZ     .not_left
    DEC     R4                  ; X--
    CALL    print_pos
    JMP     .clamp
.not_left:
    ; Check Right
    CMPI    R1, KEY_RIGHT
    JNZ     .no_input
    INC     R4                  ; X++
    CALL    print_pos

.clamp:
    ; Clamp X to 0-119 (square is 8x8)
    CMPI    R4, 0
    JGE     .x_not_neg
    MOVI    R4, 0
.x_not_neg:
    CMPI    R4, 120
    JLE     .x_not_big
    MOVI    R4, 120
.x_not_big:
    ; Clamp Y to 0-119
    CMPI    R5, 0
    JGE     .y_not_neg
    MOVI    R5, 0
.y_not_neg:
    CMPI    R5, 120
    JLE     .y_not_big
    MOVI    R5, 120
.y_not_big:
.no_input:
    RET

; Print current position to console
print_pos:
    PUSH    R0
    MOVI    R0, pos_x_msg
    PUTS    R0
    MOV     R0, R4
    PUTI    R0
    MOVI    R0, pos_y_msg
    PUTS    R0
    MOV     R0, R5
    PUTI    R0
    MOVI    R0, 0x0A
    PUTC    R0
    POP     R0
    RET

; Draw 8x8 white square at (R4, R5)
draw_square:
    ; Calculate starting address: FRAMEBUFFER + Y*128 + X
    MOV     R0, R5              ; Y
    MOVI    R1, 128
    MUL     R0, R1              ; Y * 128
    ADD     R0, R4              ; + X
    MOVI    R1, FRAMEBUFFER
    ADD     R0, R1              ; + FRAMEBUFFER base
    
    MOVI    R3, 8               ; Row counter
.row_loop:
    MOVI    R2, 8               ; Column counter
    MOV     R6, R0              ; Save row start
.col_loop:
    MOVI    R1, WHITE
    STOREB  [R0], R1            ; Draw pixel
    INC     R0                  ; Next column
    DEC     R2
    JNZ     .col_loop
    
    ; Move to next row
    MOV     R0, R6              ; Restore row start
    ADDI    R0, 128             ; Add row stride
    DEC     R3
    JNZ     .row_loop
    RET

; Data
help_msg:
    .db "Use arrow keys to move the square", 0x0A, 0

pos_x_msg:
    .db "X=", 0

pos_y_msg:
    .db " Y=", 0
```

### Example 5: Memory Dump Utility

```asm
; Utility to dump memory contents to console
; Useful for debugging

.org    0x0000

    ; Dump first 32 bytes of RAM
    MOVI    R4, 0x8000          ; Start address
    MOVI    R5, 32              ; Bytes to dump

    MOVI    R0, header_msg
    PUTS    R0

dump_loop:
    ; Print address
    MOV     R0, R4
    PUTX    R0
    MOVI    R0, ':'
    PUTC    R0
    MOVI    R0, ' '
    PUTC    R0
    
    ; Print 8 bytes per line
    MOVI    R6, 8
.line_loop:
    LOADB   R0, [R4]
    PUTX    R0
    MOVI    R0, ' '
    PUTC    R0
    INC     R4
    DEC     R5
    JZ      .done
    DEC     R6
    JNZ     .line_loop
    
    ; Newline
    MOVI    R0, 0x0A
    PUTC    R0
    JMP     dump_loop

.done:
    MOVI    R0, 0x0A
    PUTC    R0
    MOVI    R0, done_msg
    PUTS    R0
    HALT

header_msg:
    .db "Memory Dump:", 0x0A, 0

done_msg:
    .db "Done.", 0x0A, 0
```

---

## Appendix A: Quick Reference Card

### System Specs
```
Clock Speed:  4 MHz (66,667 cycles/frame @60fps)
Word Size:    16-bit, little-endian
Console:      4KB text buffer
```

### Registers
```
R0-R7   General purpose (16-bit)
PC      Program counter
SP      Stack pointer (init: 0xFFEF)
FLAGS   Z C N V (bits 0-3)
```

### Memory Map
```
0x0000-0x3FFF  Program (16KB)
0x4000-0x7FFF  Framebuffer (128x128, RGB332)
0x8000-0xFFEF  RAM
0xFFF0-0xFFF1  System Timer (r/o)
0xFFF2-0xFFF3  Countdown Timer (r/w)
0xFFF4         Key Code (r/o)
0xFFF5         Key State (r/o)
```

### Common Instructions (with cycle costs)
```
MOV Rd, Rs      [2]     MOVI Rd, imm16  [3]
LOAD Rd, [Rs]   [4]     LOADB Rd, [Rs]  [3]
STORE [Rd], Rs  [4]     STOREB [Rd], Rs [3]
ADD Rd, Rs      [2]     SUB Rd, Rs      [2]
MUL Rd, Rs      [8]     DIV Rd, Rs      [12]
CMP Rd, Rs      [2]     CMPI Rd, imm8   [3]
AND Rd, Rs      [2]     OR Rd, Rs       [2]
XOR Rd, Rs      [2]     NOT Rd          [2]
SHL Rd, Rs      [2]     SHR Rd, Rs      [2]
JMP addr        [3]     Jcc addr        [2/4]
CALL addr       [6]     RET             [5]
PUSH Rs         [4]     POP Rd          [4]
MEMCPY          [5+N]   MEMSET          [5+N]
DISPLAY         [1000]  HALT            [1]
```

### Console Instructions
```
PUTC Rs         [2]     Write character (low byte of Rs)
PUTS Rs         [3+N]   Write string at [Rs]
PUTI Rs         [8]     Write Rs as decimal
PUTX Rs         [6]     Write Rs as hex (0xNNNN)
```

### MEMCPY / MEMSET Register Convention
```
MEMCPY: R0=src, R1=dst, R2=count  (copies R2 bytes from [R0] to [R1])
MEMSET: R0=dst, R1=val, R2=count  (fills R2 bytes at [R0] with R1.low)
```

### RGB332 Colors
```
Black   0x00    White   0xFF    Red     0xE0
Green   0x1C    Blue    0x03    Yellow  0xFC
Cyan    0x1F    Magenta 0xE3    Orange  0xF0
```

### Arrow Key Codes
```
Up      0x80    Down    0x81
Left    0x82    Right   0x83
```

### Cycle Budget @60fps (66,667 cycles)
```
Clear screen (MEMSET)   16,389 cycles
8x8 sprite (MEMCPY)         69 cycles
Single pixel write           3 cycles
Multiply                     8 cycles
Function call+return        11 cycles
Print short string          ~13 cycles
Print hex value              6 cycles
```

---

*End of HackVM Specification v1.2*
