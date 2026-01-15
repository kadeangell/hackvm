//! Console I/O Integration Tests
//!
//! These tests verify the complete pipeline: assembler -> CPU -> console output

const std = @import("std");
const Assembler = @import("assembler.zig").Assembler;
const Memory = @import("memory.zig").Memory;
const CPU = @import("cpu.zig").CPU;

/// Helper to run a program and get console output
fn runProgram(source: []const u8) ![]const u8 {
    // Assemble
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    // Load into memory
    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    // Run CPU
    var cpu = CPU.init(&mem);

    var iterations: u32 = 0;
    const max_iterations: u32 = 100000;

    while (!cpu.halted and iterations < max_iterations) {
        _ = cpu.step();
        iterations += 1;
    }

    // Return console output
    return cpu.console_buffer[0..cpu.console_length];
}

// ============================================================================
// Integration Tests - Hello World
// ============================================================================

test "integration: hello world" {
    const source =
        \\    MOVI R0, msg
        \\    PUTS R0
        \\    HALT
        \\msg:
        \\    .db "Hello, World!", 0
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("Hello, World!", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: number printing" {
    const source =
        \\    MOVI R0, 42
        \\    PUTI R0
        \\    HALT
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("42", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: hex printing" {
    const source =
        \\    MOVI R0, 0xCAFE
        \\    PUTX R0
        \\    HALT
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("0xCAFE", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: mixed output" {
    const source =
        \\    MOVI R0, msg1
        \\    PUTS R0
        \\    MOVI R1, 12345
        \\    PUTI R1
        \\    MOVI R2, 10
        \\    PUTC R2
        \\    MOVI R0, msg2
        \\    PUTS R0
        \\    MOVI R1, 0xABCD
        \\    PUTX R1
        \\    HALT
        \\msg1:
        \\    .db "Value: ", 0
        \\msg2:
        \\    .db "Hex: ", 0
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("Value: 12345\nHex: 0xABCD", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: character output" {
    const source =
        \\    MOVI R0, 'H'
        \\    PUTC R0
        \\    MOVI R0, 'i'
        \\    PUTC R0
        \\    MOVI R0, '!'
        \\    PUTC R0
        \\    HALT
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("Hi!", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: loop counting" {
    const source =
        \\    MOVI R0, 5          ; counter
        \\loop:
        \\    PUTI R0             ; print counter
        \\    MOVI R1, ' '
        \\    PUTC R1             ; print space
        \\    DEC R0              ; decrement
        \\    JNZ loop            ; loop if not zero
        \\    MOVI R0, msg
        \\    PUTS R0
        \\    HALT
        \\msg:
        \\    .db "done", 0
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    var iterations: u32 = 0;
    while (!cpu.halted and iterations < 10000) {
        _ = cpu.step();
        iterations += 1;
    }

    try std.testing.expectEqualStrings("5 4 3 2 1 done", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: fibonacci sequence" {
    const source =
        \\; Print first 10 Fibonacci numbers
        \\    MOVI R0, 0          ; a = 0
        \\    MOVI R1, 1          ; b = 1
        \\    MOVI R5, 10         ; counter
        \\
        \\fib_loop:
        \\    PUTI R0             ; print current
        \\    MOVI R2, ' '
        \\    PUTC R2             ; print space
        \\
        \\    MOV R2, R0          ; temp = a
        \\    ADD R2, R1          ; temp = a + b
        \\    MOV R0, R1          ; a = b
        \\    MOV R1, R2          ; b = temp
        \\
        \\    DEC R5              ; counter--
        \\    JNZ fib_loop        ; loop if counter != 0
        \\
        \\    HALT
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    var iterations: u32 = 0;
    while (!cpu.halted and iterations < 100000) {
        _ = cpu.step();
        iterations += 1;
    }

    try std.testing.expectEqualStrings("0 1 1 2 3 5 8 13 21 34 ", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: string from subroutine" {
    const source =
        \\    CALL print_hello
        \\    CALL print_world
        \\    HALT
        \\
        \\print_hello:
        \\    MOVI R0, hello_msg
        \\    PUTS R0
        \\    RET
        \\
        \\print_world:
        \\    MOVI R0, world_msg
        \\    PUTS R0
        \\    RET
        \\
        \\hello_msg:
        \\    .db "Hello ", 0
        \\world_msg:
        \\    .db "World!", 0
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("Hello World!", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: multiply and print" {
    const source =
        \\    MOVI R0, 7
        \\    MOVI R1, 6
        \\    MUL R0, R1          ; R0 = 7 * 6 = 42
        \\    PUTI R0
        \\    HALT
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("42", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: address display" {
    const source =
        \\    MOVI R0, prefix
        \\    PUTS R0
        \\    MOVI R0, 0x4000     ; Framebuffer address
        \\    PUTX R0
        \\    HALT
        \\prefix:
        \\    .db "Framebuffer at ", 0
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("Framebuffer at 0x4000", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: zero edge case" {
    const source =
        \\    MOVI R0, 0
        \\    PUTI R0             ; print 0
        \\    MOVI R1, ','
        \\    PUTC R1
        \\    PUTX R0             ; print 0x0000
        \\    HALT
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("0,0x0000", cpu.console_buffer[0..cpu.console_length]);
}

test "integration: max value edge case" {
    const source =
        \\    MOVI R0, 65535
        \\    PUTI R0             ; print 65535
        \\    MOVI R1, ','
        \\    PUTC R1
        \\    MOVI R0, 0xFFFF
        \\    PUTX R0             ; print 0xFFFF
        \\    HALT
    ;

    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const binary = try asm_inst.assemble(source);

    var mem = Memory.init();
    @memcpy(mem.data[0..binary.len], binary);

    var cpu = CPU.init(&mem);

    while (!cpu.halted) {
        _ = cpu.step();
    }

    try std.testing.expectEqualStrings("65535,0xFFFF", cpu.console_buffer[0..cpu.console_length]);
}
