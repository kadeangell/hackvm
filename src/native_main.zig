//! HackVM Native Entry Point
//!
//! Command-line interface for testing programs without a browser.

const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Memory = @import("memory.zig").Memory;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <program.bin> [--debug] [--max-cycles N]\n", .{args[0]});
        std.debug.print("\nOptions:\n", .{});
        std.debug.print("  --debug       Print CPU state after each instruction\n", .{});
        std.debug.print("  --max-cycles  Maximum cycles to execute (default: 1000000)\n", .{});
        return;
    }

    var debug_mode = false;
    var max_cycles: u64 = 1_000_000;

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--debug")) {
            debug_mode = true;
        } else if (std.mem.eql(u8, args[i], "--max-cycles")) {
            if (i + 1 < args.len) {
                max_cycles = try std.fmt.parseInt(u64, args[i + 1], 10);
                i += 1;
            }
        }
    }

    // Load program
    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();

    const program = try file.readToEndAlloc(allocator, 16384);
    defer allocator.free(program);

    std.debug.print("Loaded program: {s} ({d} bytes)\n", .{ args[1], program.len });

    // Initialize emulator
    var memory = Memory.init();
    memory.loadProgram(program);

    var cpu = CPU.init(&memory);

    std.debug.print("Starting execution...\n\n", .{});

    // Run emulator
    var total_cycles: u64 = 0;
    var instruction_count: u64 = 0;

    while (!cpu.halted and total_cycles < max_cycles) {
        if (debug_mode) {
            printCPUState(&cpu);
        }

        const cycles = cpu.step();
        total_cycles += cycles;
        instruction_count += 1;

        if (cpu.display_requested) {
            std.debug.print("\n[DISPLAY requested at cycle {d}]\n", .{total_cycles});
            cpu.display_requested = false;

            // In native mode, we could dump framebuffer to a file or ASCII art
            // For now, just acknowledge it
        }
    }

    std.debug.print("\n=== Execution Complete ===\n", .{});
    std.debug.print("Instructions executed: {d}\n", .{instruction_count});
    std.debug.print("Total cycles: {d}\n", .{total_cycles});
    std.debug.print("Halted: {}\n", .{cpu.halted});

    printCPUState(&cpu);

    // Optionally dump framebuffer
    if (debug_mode) {
        std.debug.print("\n=== Framebuffer (first 128 bytes) ===\n", .{});
        for (0..8) |row| {
            for (0..16) |col| {
                const addr = 0x4000 + row * 16 + col;
                std.debug.print("{X:0>2} ", .{memory.data[addr]});
            }
            std.debug.print("\n", .{});
        }
    }
}

fn printCPUState(cpu: *const CPU) void {
    std.debug.print("PC:{X:0>4} SP:{X:0>4} ", .{ cpu.pc, cpu.sp });
    std.debug.print("R0:{X:0>4} R1:{X:0>4} R2:{X:0>4} R3:{X:0>4} ", .{ cpu.r[0], cpu.r[1], cpu.r[2], cpu.r[3] });
    std.debug.print("R4:{X:0>4} R5:{X:0>4} R6:{X:0>4} R7:{X:0>4} ", .{ cpu.r[4], cpu.r[5], cpu.r[6], cpu.r[7] });
    std.debug.print("[{s}{s}{s}{s}]\n", .{
        if (cpu.flags.z) "Z" else "-",
        if (cpu.flags.c) "C" else "-",
        if (cpu.flags.n) "N" else "-",
        if (cpu.flags.v) "V" else "-",
    });
}
