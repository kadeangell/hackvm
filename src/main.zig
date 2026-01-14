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

/// Run for up to max_cycles cycles or until DISPLAY/HALT
/// Returns: cycles actually executed
export fn run(max_cycles: u32) u32 {
    var cycles_run: u32 = 0;
    cpu.display_requested = false;

    while (cycles_run < max_cycles and !cpu.halted and !cpu.display_requested) {
        cycles_run += cpu.step();
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
