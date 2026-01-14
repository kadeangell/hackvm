//! HackVM Native Entry Point
//!
//! Unified command-line interface for emulator and assembler.

const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Memory = @import("memory.zig").Memory;
const Assembler = @import("assembler.zig").Assembler;

const Command = enum {
    run,
    assemble,
    help,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage(args[0]);
        return;
    }

    // Determine command
    const cmd_str = args[1];
    const command: Command = if (std.mem.eql(u8, cmd_str, "run"))
        .run
    else if (std.mem.eql(u8, cmd_str, "asm") or std.mem.eql(u8, cmd_str, "assemble"))
        .assemble
    else if (std.mem.eql(u8, cmd_str, "help") or std.mem.eql(u8, cmd_str, "--help") or std.mem.eql(u8, cmd_str, "-h"))
        .help
    else blk: {
        // Legacy: if first arg is a file, assume "run"
        if (std.mem.endsWith(u8, cmd_str, ".bin") or std.mem.endsWith(u8, cmd_str, ".hvm")) {
            break :blk .run;
        }
        printUsage(args[0]);
        return;
    };

    switch (command) {
        .run => try runEmulator(allocator, args),
        .assemble => try runAssembler(allocator, args),
        .help => printUsage(args[0]),
    }
}

fn runEmulator(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Find program file (skip "run" if present)
    const start_idx: usize = if (args.len > 1 and std.mem.eql(u8, args[1], "run")) 2 else 1;

    if (args.len <= start_idx) {
        std.debug.print("Error: No program file specified\n", .{});
        std.debug.print("Usage: hackvm run <program.bin> [options]\n", .{});
        return;
    }

    const program_path = args[start_idx];

    var debug_mode = false;
    var max_cycles: u64 = 1_000_000;

    var i: usize = start_idx + 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--debug") or std.mem.eql(u8, args[i], "-d")) {
            debug_mode = true;
        } else if (std.mem.eql(u8, args[i], "--max-cycles") or std.mem.eql(u8, args[i], "-m")) {
            if (i + 1 < args.len) {
                max_cycles = try std.fmt.parseInt(u64, args[i + 1], 10);
                i += 1;
            }
        }
    }

    // Load program
    const file = std.fs.cwd().openFile(program_path, .{}) catch |err| {
        std.debug.print("Error: Cannot open '{s}': {s}\n", .{ program_path, @errorName(err) });
        return;
    };
    defer file.close();

    const program = try file.readToEndAlloc(allocator, 16384);
    defer allocator.free(program);

    std.debug.print("Loaded program: {s} ({d} bytes)\n", .{ program_path, program.len });

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
        }
    }

    std.debug.print("\n=== Execution Complete ===\n", .{});
    std.debug.print("Instructions executed: {d}\n", .{instruction_count});
    std.debug.print("Total cycles: {d}\n", .{total_cycles});
    std.debug.print("Halted: {}\n", .{cpu.halted});

    printCPUState(&cpu);

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

fn runAssembler(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Error: No input file specified\n", .{});
        std.debug.print("Usage: hackvm asm <input.asm> [-o output.bin]\n", .{});
        return;
    }

    const input_path = args[2];
    var output_path: ?[]const u8 = null;
    var output_path_owned = false;

    // Parse options
    var i: usize = 3;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-o") or std.mem.eql(u8, args[i], "--output")) {
            if (i + 1 < args.len) {
                output_path = args[i + 1];
                i += 1;
            }
        }
    }

    // Default output path
    if (output_path == null) {
        // Replace .asm with .bin
        if (std.mem.endsWith(u8, input_path, ".asm")) {
            const base = input_path[0 .. input_path.len - 4];
            output_path = try std.fmt.allocPrint(allocator, "{s}.bin", .{base});
        } else {
            output_path = try std.fmt.allocPrint(allocator, "{s}.bin", .{input_path});
        }
        output_path_owned = true;
    }
    defer if (output_path_owned) allocator.free(output_path.?);

    // Read source file
    const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
        std.debug.print("Error: Cannot open '{s}': {s}\n", .{ input_path, @errorName(err) });
        return;
    };
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    std.debug.print("Assembling: {s}\n", .{input_path});

    // Assemble
    var asm_instance = Assembler.init(allocator);
    defer asm_instance.deinit();

    const output = asm_instance.assemble(source) catch |err| {
        std.debug.print("Assembly failed: {s}\n", .{@errorName(err)});
        for (asm_instance.getErrors()) |e| {
            std.debug.print("  Line {d}: {s}\n", .{ e.line, e.message });
        }
        return;
    };

    // Write output
    const out_file = std.fs.cwd().createFile(output_path.?, .{}) catch |err| {
        std.debug.print("Error: Cannot create '{s}': {s}\n", .{ output_path.?, @errorName(err) });
        return;
    };
    defer out_file.close();

    try out_file.writeAll(output);

    std.debug.print("Output: {s} ({d} bytes)\n", .{ output_path.?, output.len });
    std.debug.print("Assembly successful!\n", .{});
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

fn printUsage(program_name: []const u8) void {
    std.debug.print(
        \\HackVM - 16-bit Virtual Machine
        \\
        \\Usage: {s} <command> [options]
        \\
        \\Commands:
        \\  run <program.bin>     Run a binary program
        \\  asm <input.asm>       Assemble source code
        \\  help                  Show this help message
        \\
        \\Run Options:
        \\  --debug, -d           Print CPU state after each instruction
        \\  --max-cycles, -m N    Maximum cycles to execute (default: 1000000)
        \\
        \\Assembler Options:
        \\  -o, --output FILE     Output file (default: input.bin)
        \\
        \\Examples:
        \\  {s} run examples/fill_red.bin
        \\  {s} asm examples/game.asm -o game.bin
        \\  {s} run game.bin --debug
        \\
    , .{ program_name, program_name, program_name, program_name });
}
