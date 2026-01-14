# HackVM

A 16-bit virtual machine designed for hackathon competitions. Features a simple instruction set, 128x128 pixel graphics with 8-bit color, keyboard input, and timer support.

## Features

- **16-bit architecture** with 8 general-purpose registers
- **64KB address space** with memory-mapped I/O
- **128x128 display** with RGB332 color (256 colors)
- **4 MHz clock speed** with cycle-accurate emulation
- **Keyboard input** for interactive programs
- **System and countdown timers** for game timing
- **MEMSET/MEMCPY** instructions for fast graphics operations

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/) 0.13.0 or later
- [Node.js](https://nodejs.org/) 18+ and npm
- Python 3 (for generating test programs)

### Build & Run

```bash
# Build WASM emulator
zig build wasm

# Generate test programs
python3 tools/generate_tests.py

# Install web dependencies and start dev server
cd web
npm install
npm run dev
```

Open http://localhost:3000 in your browser, load a `.bin` file from `examples/`, and click Run!

### Production Build

```bash
cd web
npm run build
```

The production build will be in `web/dist/`.

## Project Structure

```
hackvm/
├── src/                    # Zig emulator source
│   ├── main.zig           # WASM entry point
│   ├── native_main.zig    # CLI for testing
│   ├── cpu.zig            # CPU implementation
│   ├── memory.zig         # Memory system
│   └── opcodes.zig        # Opcode definitions
├── web/                    # React frontend
│   ├── src/
│   │   ├── components/    # React components
│   │   ├── hooks/         # Custom hooks
│   │   ├── App.tsx        # Main app
│   │   └── types.ts       # TypeScript types
│   ├── public/
│   │   └── hackvm.wasm    # Built WASM binary
│   └── package.json
├── tools/
│   └── generate_tests.py  # Test program generator
├── examples/              # Example .bin programs
└── build.zig              # Zig build config
```

## Example Programs

Generate the example programs with:

```bash
python3 tools/generate_tests.py
```

| Program | Description |
|---------|-------------|
| `fill_red.bin` | Fills the screen with red |
| `gradient.bin` | Displays a color gradient |
| `color_cycle.bin` | Animates through all 256 colors |
| `keyboard_test.bin` | Changes screen color based on key pressed |
| `moving_pixel.bin` | Move a white pixel with arrow keys |

## Architecture Overview

### Registers

| Register | Description |
|----------|-------------|
| R0-R7 | General purpose (16-bit) |
| PC | Program Counter |
| SP | Stack Pointer (initialized to 0xFFEF) |
| FLAGS | Z (Zero), C (Carry), N (Negative), V (Overflow) |

### Memory Map

| Address Range | Description |
|---------------|-------------|
| 0x0000-0x3FFF | Program memory (16KB) |
| 0x4000-0x7FFF | Framebuffer (128x128 pixels) |
| 0x8000-0xFFEF | General RAM |
| 0xFFF0-0xFFF1 | System timer (read-only) |
| 0xFFF2-0xFFF3 | Countdown timer (read/write) |
| 0xFFF4 | Keyboard keycode (read-only) |
| 0xFFF5 | Keyboard state (read-only) |

### Color Format (RGB332)

Each pixel is one byte: `RRRGGGBB`

| Color | Hex Value |
|-------|-----------|
| Black | 0x00 |
| White | 0xFF |
| Red | 0xE0 |
| Green | 0x1C |
| Blue | 0x03 |

### Key Instructions

| Instruction | Description | Cycles |
|-------------|-------------|--------|
| `MOVI Rd, imm16` | Load 16-bit immediate | 3 |
| `LOAD Rd, [Rs]` | Load 16-bit from memory | 4 |
| `STOREB [Rd], Rs` | Store byte to memory | 3 |
| `MEMSET` | Fill R2 bytes at [R0] with R1 | 5+N |
| `MEMCPY` | Copy R2 bytes from [R0] to [R1] | 5+N |
| `DISPLAY` | Render framebuffer | 1000 |
| `JNZ addr` | Jump if not zero | 2/4 |

## Writing Programs

Until we have an assembler, you can:

1. **Hand-assemble** using the Python script as a reference
2. **Modify `tools/generate_tests.py`** to create new programs
3. **Write a compiler** that targets this instruction set (bonus points!)

### Assembly Example

```asm
; Fill screen with red
    MOVI    R0, 0x4000      ; Framebuffer address
    MOVI    R1, 0xE0        ; Red color
    MOVI    R2, 16384       ; Screen size in bytes
    MEMSET                   ; Fill memory
    DISPLAY                  ; Show on screen
    HALT                     ; Stop
```

## Tech Stack

- **Emulator**: Zig → WebAssembly
- **Frontend**: React + TypeScript + Tailwind CSS + Vite
- **Icons**: Lucide React

## License

MIT

## Contributing

This is a hackathon project! Feel free to:

- Add new example programs
- Build an assembler
- Build a compiler targeting this VM
- Add sound support
- Improve the web UI
