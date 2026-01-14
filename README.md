# HackVM

A 16-bit virtual machine designed for hackathon competitions. Features a simple instruction set, 128x128 pixel graphics with 8-bit color, keyboard input, and timer support. Includes a built-in assembler.

## Features

- **16-bit architecture** with 8 general-purpose registers
- **64KB address space** with memory-mapped I/O
- **128x128 display** with RGB332 color (256 colors)
- **4 MHz clock speed** with cycle-accurate emulation
- **Keyboard input** for interactive programs
- **System and countdown timers** for game timing
- **MEMSET/MEMCPY** instructions for fast graphics operations
- **Built-in assembler** - write and run assembly in the browser!

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/) 0.13.0 or later
- [Node.js](https://nodejs.org/) 18+ and npm

### Build & Run

```bash
# Build both WASM binaries (emulator + assembler)
zig build wasm

# Install web dependencies and start dev server
cd web
npm install
npm run dev
```

Open http://localhost:3000 in your browser. Write assembly code in the editor and click "Assemble & Run"!

### Native CLI

The native binary supports both running programs and assembling source files:

```bash
# Build native CLI
zig build

# Assemble a source file
./zig-out/bin/hackvm asm examples/fill_red.asm -o fill_red.bin

# Run a binary program
./zig-out/bin/hackvm run fill_red.bin

# Run with debug output
./zig-out/bin/hackvm run fill_red.bin --debug
```

## Project Structure

```
hackvm/
├── src/                    # Zig source code
│   ├── main.zig           # Emulator WASM entry point
│   ├── asm_main.zig       # Assembler WASM entry point
│   ├── native_main.zig    # Native CLI (unified)
│   ├── cpu.zig            # CPU implementation
│   ├── memory.zig         # Memory system
│   ├── opcodes.zig        # Opcode definitions
│   ├── assembler.zig      # Assembler core
│   └── lexer.zig          # Assembly lexer
├── web/                    # React frontend
│   ├── src/
│   │   ├── components/    # React components
│   │   ├── hooks/         # useEmulator, useAssembler
│   │   └── App.tsx        # Main app with editor
│   └── public/
│       ├── hackvm.wasm    # Emulator WASM
│       └── hackvm-asm.wasm # Assembler WASM
├── examples/              # Example .asm files
└── build.zig
```

## Assembly Language

### Syntax

```asm
; This is a comment
.equ    CONSTANT, 0x4000    ; Define constant
.org    0x0000              ; Set origin address

label:
    MOVI    R0, 0x1234      ; Instruction
    JMP     label           ; Jump to label
```

### Registers

| Register | Description |
|----------|-------------|
| R0-R7 | General purpose (16-bit) |
| PC | Program Counter |
| SP | Stack Pointer (init: 0xFFEF) |
| FLAGS | Z, C, N, V |

### Instructions

| Category | Instructions |
|----------|--------------|
| Data | MOV, MOVI, LOAD, LOADB, STORE, STOREB, PUSH, POP |
| Arithmetic | ADD, ADDI, SUB, SUBI, MUL, DIV, INC, DEC, NEG |
| Logical | AND, ANDI, OR, ORI, XOR, XORI, NOT, SHL, SHR, SAR |
| Compare | CMP, CMPI, TEST, TESTI |
| Control | JMP, JZ, JNZ, JC, JNC, JN, JA, JG, JL, CALL, RET |
| Memory | MEMSET, MEMCPY |
| System | DISPLAY, HALT, NOP |

### Directives

| Directive | Description |
|-----------|-------------|
| `.equ name, value` | Define constant |
| `.org address` | Set assembly address |
| `.db val, ...` | Define bytes |
| `.dw val, ...` | Define words (16-bit) |
| `.ds count` | Reserve space |

### Memory Map

| Address | Description |
|---------|-------------|
| 0x0000-0x3FFF | Program (16KB) |
| 0x4000-0x7FFF | Framebuffer (128x128) |
| 0x8000-0xFFEF | RAM |
| 0xFFF0-0xFFF1 | System Timer |
| 0xFFF2-0xFFF3 | Countdown Timer |
| 0xFFF4 | Key Code |
| 0xFFF5 | Key State |

### Colors (RGB332)

| Color | Value |
|-------|-------|
| Black | 0x00 |
| White | 0xFF |
| Red | 0xE0 |
| Green | 0x1C |
| Blue | 0x03 |

### Key Codes

| Key | Code |
|-----|------|
| Arrow Up | 0x80 |
| Arrow Down | 0x81 |
| Arrow Left | 0x82 |
| Arrow Right | 0x83 |
| A-Z | 0x41-0x5A |
| 0-9 | 0x30-0x39 |
| Space | 0x20 |

## Example Program

```asm
; Fill screen with animated colors

.equ    FRAMEBUFFER, 0x4000
.equ    SCREEN_SIZE, 16384

.org    0x0000

    MOVI    R7, 0           ; Color counter

loop:
    ; Fill screen
    MOVI    R0, FRAMEBUFFER
    MOV     R1, R7
    MOVI    R2, SCREEN_SIZE
    MEMSET
    
    ; Show frame
    DISPLAY
    
    ; Next color
    INC     R7
    JMP     loop
```

## Build Targets

```bash
zig build wasm      # Build both WASM files
zig build           # Build native CLI
zig build test      # Run all tests
zig build run -- asm file.asm   # Assemble file
zig build run -- run file.bin   # Run program
```

## Tech Stack

- **Emulator & Assembler**: Zig → WebAssembly
- **Frontend**: React + TypeScript + Tailwind CSS + Vite
- **Icons**: Lucide React

## License

MIT
