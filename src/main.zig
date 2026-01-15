//! HackVM WASM Entry Point
//!
//! Exports functions for JavaScript to control the emulator.

const CPU = @import("cpu.zig").CPU;
const Memory = @import("memory.zig").Memory;

// Global state
var memory: Memory = Memory.init();
var cpu: CPU = CPU.init(&memory);

// ============ Exported Functions ============

/// Initialize/reset the emulator
export fn init() void {
    memory.reset();
    cpu = CPU.init(&memory);
}

/// Reset CPU state but keep memory contents
export fn reset() void {
    cpu.reset();
}

/// Run for up to max_cycles cycles or until DISPLAY/HALT/waiting for input
/// Returns: cycles actually executed
export fn run(max_cycles: u32) u32 {
    var cycles_run: u32 = 0;
    cpu.display_requested = false;

    while (cycles_run < max_cycles and !cpu.halted and !cpu.display_requested) {
        const step_cycles = cpu.step();
        cycles_run += step_cycles;

        // If waiting for input and no cycles executed, break to let JS handle it
        if (cpu.waiting_for_input and step_cycles == 0) {
            break;
        }
    }

    return cycles_run;
}

/// Check if CPU is halted
export fn isHalted() bool {
    return cpu.halted;
}

/// Check if DISPLAY was requested
export fn displayRequested() bool {
    return cpu.display_requested;
}

/// Get pointer to framebuffer (16KB at 0x4000)
export fn getFramebufferPtr() [*]u8 {
    return memory.getFramebufferPtr();
}

/// Get pointer to full memory (for program loading)
export fn getMemoryPtr() [*]u8 {
    return memory.getMemoryPtr();
}

/// Set keyboard state from host
export fn setKeyState(code: u8, pressed: u8) void {
    memory.setKeyState(code, pressed != 0);
}

/// Update timers from host (call with elapsed milliseconds)
export fn updateTimers(delta_ms: u16) void {
    memory.updateTimers(delta_ms);
}

/// Get total cycles executed
export fn getCyclesExecuted() u64 {
    return cpu.cycles;
}

/// Get current PC value
export fn getPC() u16 {
    return cpu.pc;
}

/// Get current SP value
export fn getSP() u16 {
    return cpu.sp;
}

/// Get register value
export fn getRegister(index: u8) u16 {
    if (index < 8) {
        return cpu.r[index];
    }
    return 0;
}

/// Get flags as byte
export fn getFlags() u8 {
    return cpu.flags.toU8();
}

// ============ Console I/O ============

/// Get pointer to console buffer
export fn getConsoleBufferPtr() [*]const u8 {
    return @ptrCast(&cpu.console_buffer);
}

/// Get console buffer write position (for circular buffer handling)
export fn getConsoleWritePos() u16 {
    return cpu.console_write_pos;
}

/// Get console buffer length (valid bytes)
export fn getConsoleLength() u16 {
    return cpu.console_length;
}

/// Check if console has new output and clear the flag
export fn consumeConsoleUpdate() bool {
    return cpu.consumeConsoleUpdate();
}

/// Clear console buffer
export fn clearConsole() void {
    cpu.clearConsole();
}

// ============ Console Input ============

/// Push a character to the input buffer
export fn pushConsoleInput(ch: u8) void {
    cpu.pushInput(ch);
}

/// Check if CPU is waiting for input
export fn isWaitingForInput() bool {
    return cpu.isWaitingForInput();
}

/// Get current input mode (0=none, 1=GETC, 2=GETS)
export fn getInputMode() u8 {
    return cpu.getInputMode();
}

/// Clear input buffer
export fn clearInput() void {
    cpu.clearInput();
}
