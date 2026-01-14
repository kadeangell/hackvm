//! HackVM Assembler Tests
//!
//! Comprehensive tests for the assembler including:
//! - Lexer tests
//! - Individual instruction encoding
//! - Directives
//! - Label resolution
//! - Error handling

const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("lexer.zig").TokenType;
const Assembler = @import("assembler.zig").Assembler;
const Opcode = @import("opcodes.zig").Opcode;

// ============================================================================
// Lexer Tests
// ============================================================================

test "lexer: basic tokens" {
    const source = "MOV R0, R1\n";
    var lexer = Lexer.init(source);

    const t1 = lexer.next();
    try std.testing.expectEqual(TokenType.identifier, t1.type);
    try std.testing.expectEqualStrings("MOV", t1.text);

    const t2 = lexer.next();
    try std.testing.expectEqual(TokenType.identifier, t2.type);
    try std.testing.expectEqualStrings("R0", t2.text);

    const t3 = lexer.next();
    try std.testing.expectEqual(TokenType.comma, t3.type);

    const t4 = lexer.next();
    try std.testing.expectEqual(TokenType.identifier, t4.type);
    try std.testing.expectEqualStrings("R1", t4.text);

    const t5 = lexer.next();
    try std.testing.expectEqual(TokenType.newline, t5.type);

    const t6 = lexer.next();
    try std.testing.expectEqual(TokenType.eof, t6.type);
}

test "lexer: decimal numbers" {
    const source = "123 456 0 65535";
    var lexer = Lexer.init(source);

    try std.testing.expectEqualStrings("123", lexer.next().text);
    try std.testing.expectEqualStrings("456", lexer.next().text);
    try std.testing.expectEqualStrings("0", lexer.next().text);
    try std.testing.expectEqualStrings("65535", lexer.next().text);
}

test "lexer: hex numbers" {
    const source = "0x00 0xFF 0x4000 0xABCD";
    var lexer = Lexer.init(source);

    try std.testing.expectEqualStrings("0x00", lexer.next().text);
    try std.testing.expectEqualStrings("0xFF", lexer.next().text);
    try std.testing.expectEqualStrings("0x4000", lexer.next().text);
    try std.testing.expectEqualStrings("0xABCD", lexer.next().text);
}

test "lexer: binary numbers" {
    const source = "0b0000 0b1111 0b10101010";
    var lexer = Lexer.init(source);

    try std.testing.expectEqualStrings("0b0000", lexer.next().text);
    try std.testing.expectEqualStrings("0b1111", lexer.next().text);
    try std.testing.expectEqualStrings("0b10101010", lexer.next().text);
}

test "lexer: comments are skipped" {
    const source = "MOV ; this is a comment\nHALT";
    var lexer = Lexer.init(source);

    try std.testing.expectEqualStrings("MOV", lexer.next().text);
    try std.testing.expectEqual(TokenType.newline, lexer.next().type);
    try std.testing.expectEqualStrings("HALT", lexer.next().text);
}

test "lexer: labels with colon" {
    const source = "start: MOV R0, R1";
    var lexer = Lexer.init(source);

    try std.testing.expectEqualStrings("start", lexer.next().text);
    try std.testing.expectEqual(TokenType.colon, lexer.next().type);
    try std.testing.expectEqualStrings("MOV", lexer.next().text);
}

test "lexer: brackets" {
    const source = "LOAD R0, [R1]";
    var lexer = Lexer.init(source);

    try std.testing.expectEqualStrings("LOAD", lexer.next().text);
    try std.testing.expectEqualStrings("R0", lexer.next().text);
    try std.testing.expectEqual(TokenType.comma, lexer.next().type);
    try std.testing.expectEqual(TokenType.lbracket, lexer.next().type);
    try std.testing.expectEqualStrings("R1", lexer.next().text);
    try std.testing.expectEqual(TokenType.rbracket, lexer.next().type);
}

test "lexer: directives with dot" {
    const source = ".equ .org .db";
    var lexer = Lexer.init(source);

    try std.testing.expectEqual(TokenType.dot, lexer.next().type);
    try std.testing.expectEqualStrings("equ", lexer.next().text);
    try std.testing.expectEqual(TokenType.dot, lexer.next().type);
    try std.testing.expectEqualStrings("org", lexer.next().text);
    try std.testing.expectEqual(TokenType.dot, lexer.next().type);
    try std.testing.expectEqualStrings("db", lexer.next().text);
}

test "lexer: character literals" {
    const source = "'A' 'z' '0'";
    var lexer = Lexer.init(source);

    const t1 = lexer.next();
    try std.testing.expectEqual(TokenType.char_literal, t1.type);
    try std.testing.expectEqualStrings("'A'", t1.text);

    const t2 = lexer.next();
    try std.testing.expectEqual(TokenType.char_literal, t2.type);
    try std.testing.expectEqualStrings("'z'", t2.text);

    const t3 = lexer.next();
    try std.testing.expectEqual(TokenType.char_literal, t3.type);
    try std.testing.expectEqualStrings("'0'", t3.text);
}

test "lexer: string literals" {
    const source = "\"Hello\" \"World\"";
    var lexer = Lexer.init(source);

    const t1 = lexer.next();
    try std.testing.expectEqual(TokenType.string, t1.type);
    try std.testing.expectEqualStrings("\"Hello\"", t1.text);

    const t2 = lexer.next();
    try std.testing.expectEqual(TokenType.string, t2.type);
    try std.testing.expectEqualStrings("\"World\"", t2.text);
}

test "lexer: line numbers" {
    const source = "A\nB\nC";
    var lexer = Lexer.init(source);

    const t1 = lexer.next();
    try std.testing.expectEqual(@as(u32, 1), t1.line);

    _ = lexer.next(); // newline

    const t2 = lexer.next();
    try std.testing.expectEqual(@as(u32, 2), t2.line);

    _ = lexer.next(); // newline

    const t3 = lexer.next();
    try std.testing.expectEqual(@as(u32, 3), t3.line);
}

// ============================================================================
// Assembler - Basic Instructions
// ============================================================================

fn expectBytes(expected: []const u8, actual: []const u8) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, 0..) |exp, i| {
        try std.testing.expectEqual(exp, actual[i]);
    }
}

test "asm: NOP" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("NOP");
    try expectBytes(&[_]u8{0x00}, output);
}

test "asm: HALT" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("HALT");
    try expectBytes(&[_]u8{0x01}, output);
}

test "asm: DISPLAY" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("DISPLAY");
    try expectBytes(&[_]u8{0x02}, output);
}

test "asm: RET" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("RET");
    try expectBytes(&[_]u8{0x03}, output);
}

test "asm: MEMSET" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("MEMSET");
    try expectBytes(&[_]u8{0x71}, output);
}

test "asm: MEMCPY" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("MEMCPY");
    try expectBytes(&[_]u8{0x70}, output);
}

// ============================================================================
// Assembler - Register Instructions
// ============================================================================

test "asm: MOV Rd, Rs" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // MOV R0, R1 -> opcode=0x10, reg_byte = (0<<5)|(1<<2) = 0x04
    const output = try asm_inst.assemble("MOV R0, R1");
    try expectBytes(&[_]u8{ 0x10, 0x04 }, output);
}

test "asm: MOV R3, R5" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // reg_byte = (3<<5)|(5<<2) = 0x60 | 0x14 = 0x74
    const output = try asm_inst.assemble("MOV R3, R5");
    try expectBytes(&[_]u8{ 0x10, 0x74 }, output);
}

test "asm: MOV R7, R7" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // reg_byte = (7<<5)|(7<<2) = 0xE0 | 0x1C = 0xFC
    const output = try asm_inst.assemble("MOV R7, R7");
    try expectBytes(&[_]u8{ 0x10, 0xFC }, output);
}

test "asm: ADD R2, R4" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // reg_byte = (2<<5)|(4<<2) = 0x40 | 0x10 = 0x50
    const output = try asm_inst.assemble("ADD R2, R4");
    try expectBytes(&[_]u8{ 0x20, 0x50 }, output);
}

test "asm: SUB R1, R6" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("SUB R1, R6");
    try expectBytes(&[_]u8{ 0x22, 0x38 }, output);
}

test "asm: INC R5" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // INC Rd -> reg_byte = (5<<5)|0 = 0xA0
    const output = try asm_inst.assemble("INC R5");
    try expectBytes(&[_]u8{ 0x26, 0xA0 }, output);
}

test "asm: DEC R0" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("DEC R0");
    try expectBytes(&[_]u8{ 0x27, 0x00 }, output);
}

test "asm: NOT R3" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("NOT R3");
    try expectBytes(&[_]u8{ 0x36, 0x60 }, output);
}

test "asm: NEG R2" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("NEG R2");
    try expectBytes(&[_]u8{ 0x28, 0x40 }, output);
}

// ============================================================================
// Assembler - Immediate Instructions
// ============================================================================

test "asm: MOVI R0, 0x4000" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // MOVI: opcode=0x11, reg_byte=(0<<5)=0x00, imm16=0x4000 (little endian: 0x00, 0x40)
    const output = try asm_inst.assemble("MOVI R0, 0x4000");
    try expectBytes(&[_]u8{ 0x11, 0x00, 0x00, 0x40 }, output);
}

test "asm: MOVI R1, 255" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("MOVI R1, 255");
    try expectBytes(&[_]u8{ 0x11, 0x20, 0xFF, 0x00 }, output);
}

test "asm: MOVI R7, 0xFFFF" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("MOVI R7, 0xFFFF");
    try expectBytes(&[_]u8{ 0x11, 0xE0, 0xFF, 0xFF }, output);
}

test "asm: ADDI R2, 100" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // ADDI: opcode=0x21, reg_byte=(2<<5)=0x40, imm8=100
    const output = try asm_inst.assemble("ADDI R2, 100");
    try expectBytes(&[_]u8{ 0x21, 0x40, 100 }, output);
}

test "asm: SUBI R0, 0xFF" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("SUBI R0, 0xFF");
    try expectBytes(&[_]u8{ 0x23, 0x00, 0xFF }, output);
}

test "asm: ANDI R4, 0x7F" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("ANDI R4, 0x7F");
    try expectBytes(&[_]u8{ 0x31, 0x80, 0x7F }, output);
}

test "asm: CMPI R1, 0" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("CMPI R1, 0");
    try expectBytes(&[_]u8{ 0x41, 0x20, 0x00 }, output);
}

test "asm: SHLI R3, 4" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // SHLI: opcode=0x38, reg_byte = (3<<5)|(4<<2) = 0x60 | 0x10 = 0x70
    const output = try asm_inst.assemble("SHLI R3, 4");
    try expectBytes(&[_]u8{ 0x38, 0x70 }, output);
}

test "asm: SHRI R0, 8" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("SHRI R0, 8");
    try expectBytes(&[_]u8{ 0x3A, 0x20 }, output);
}

// ============================================================================
// Assembler - Memory Instructions
// ============================================================================

test "asm: LOAD R0, [R1]" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("LOAD R0, [R1]");
    try expectBytes(&[_]u8{ 0x12, 0x04 }, output);
}

test "asm: LOADB R2, [R3]" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("LOADB R2, [R3]");
    try expectBytes(&[_]u8{ 0x13, 0x4C }, output);
}

test "asm: STORE [R0], R1" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("STORE [R0], R1");
    try expectBytes(&[_]u8{ 0x14, 0x04 }, output);
}

test "asm: STOREB [R4], R5" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("STOREB [R4], R5");
    try expectBytes(&[_]u8{ 0x15, 0x94 }, output);
}

test "asm: PUSH R6" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // PUSH uses Rs field: reg_byte = (0<<5)|(6<<2) = 0x18
    const output = try asm_inst.assemble("PUSH R6");
    try expectBytes(&[_]u8{ 0x16, 0x18 }, output);
}

test "asm: POP R7" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    // POP uses Rd field: reg_byte = (7<<5)|0 = 0xE0
    const output = try asm_inst.assemble("POP R7");
    try expectBytes(&[_]u8{ 0x17, 0xE0 }, output);
}

// ============================================================================
// Assembler - Jump Instructions
// ============================================================================

test "asm: JMP with address" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("JMP 0x0100");
    try expectBytes(&[_]u8{ 0x50, 0x00, 0x01 }, output);
}

test "asm: JZ with address" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("JZ 0x0050");
    try expectBytes(&[_]u8{ 0x52, 0x50, 0x00 }, output);
}

test "asm: JNZ with address" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("JNZ 0x1234");
    try expectBytes(&[_]u8{ 0x53, 0x34, 0x12 }, output);
}

test "asm: CALL with address" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("CALL 0x0200");
    try expectBytes(&[_]u8{ 0x60, 0x00, 0x02 }, output);
}

test "asm: JMPR R3" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("JMPR R3");
    try expectBytes(&[_]u8{ 0x51, 0x0C }, output);
}

test "asm: CALLR R5" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("CALLR R5");
    try expectBytes(&[_]u8{ 0x61, 0x14 }, output);
}

// ============================================================================
// Assembler - Jump Aliases
// ============================================================================

test "asm: JE is alias for JZ" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("JE 0x0010");
    try expectBytes(&[_]u8{ 0x52, 0x10, 0x00 }, output);
}

test "asm: JNE is alias for JNZ" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("JNE 0x0020");
    try expectBytes(&[_]u8{ 0x53, 0x20, 0x00 }, output);
}

test "asm: JB is alias for JC" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("JB 0x0030");
    try expectBytes(&[_]u8{ 0x54, 0x30, 0x00 }, output);
}

test "asm: JAE is alias for JNC" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output = try asm_inst.assemble("JAE 0x0040");
    try expectBytes(&[_]u8{ 0x55, 0x40, 0x00 }, output);
}

// ============================================================================
// Assembler - Labels
// ============================================================================

test "asm: forward label reference" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\    JMP end
        \\    NOP
        \\end:
        \\    HALT
    ;

    const output = try asm_inst.assemble(source);
    // JMP end -> JMP 0x0004 (JMP=3 bytes + NOP=1 byte)
    // NOP
    // HALT
    try std.testing.expectEqual(@as(usize, 5), output.len);
    try std.testing.expectEqual(@as(u8, 0x50), output[0]); // JMP
    try std.testing.expectEqual(@as(u8, 0x04), output[1]); // addr low
    try std.testing.expectEqual(@as(u8, 0x00), output[2]); // addr high
    try std.testing.expectEqual(@as(u8, 0x00), output[3]); // NOP
    try std.testing.expectEqual(@as(u8, 0x01), output[4]); // HALT
}

test "asm: backward label reference" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\loop:
        \\    NOP
        \\    JMP loop
    ;

    const output = try asm_inst.assemble(source);
    // NOP at 0x0000
    // JMP loop -> JMP 0x0000
    try std.testing.expectEqual(@as(usize, 4), output.len);
    try std.testing.expectEqual(@as(u8, 0x00), output[0]); // NOP
    try std.testing.expectEqual(@as(u8, 0x50), output[1]); // JMP
    try std.testing.expectEqual(@as(u8, 0x00), output[2]); // addr low
    try std.testing.expectEqual(@as(u8, 0x00), output[3]); // addr high
}

test "asm: multiple labels" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\start:
        \\    JMP middle
        \\middle:
        \\    JMP end
        \\end:
        \\    HALT
    ;

    const output = try asm_inst.assemble(source);
    // JMP middle (0x0003) at 0x0000
    // JMP end (0x0006) at 0x0003
    // HALT at 0x0006
    try std.testing.expectEqual(@as(usize, 7), output.len);
    try std.testing.expectEqual(@as(u8, 0x03), output[1]); // middle addr
    try std.testing.expectEqual(@as(u8, 0x06), output[4]); // end addr
}

test "asm: label in MOVI" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\    MOVI R0, data
        \\    HALT
        \\data:
        \\    .db 0x12, 0x34
    ;

    const output = try asm_inst.assemble(source);
    // MOVI R0, data -> MOVI R0, 0x0005
    // HALT
    // data bytes
    try std.testing.expectEqual(@as(usize, 7), output.len);
    try std.testing.expectEqual(@as(u8, 0x05), output[2]); // addr low
    try std.testing.expectEqual(@as(u8, 0x00), output[3]); // addr high
}

// ============================================================================
// Assembler - Directives
// ============================================================================

test "asm: .equ constant" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\.equ SCREEN, 0x4000
        \\    MOVI R0, SCREEN
    ;

    const output = try asm_inst.assemble(source);
    try std.testing.expectEqual(@as(u8, 0x00), output[2]); // 0x4000 low
    try std.testing.expectEqual(@as(u8, 0x40), output[3]); // 0x4000 high
}

test "asm: .equ with expression in immediate" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\.equ VALUE, 128
        \\    ADDI R1, VALUE
    ;

    const output = try asm_inst.assemble(source);
    try std.testing.expectEqual(@as(u8, 128), output[2]);
}

test "asm: .org directive" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\.org 0x0010
        \\    HALT
    ;

    const output = try asm_inst.assemble(source);
    // Output should be padded to 0x0010, then HALT
    try std.testing.expectEqual(@as(usize, 17), output.len);
    try std.testing.expectEqual(@as(u8, 0x00), output[0]); // Padding
    try std.testing.expectEqual(@as(u8, 0x01), output[16]); // HALT
}

test "asm: .db bytes" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source = ".db 0x12, 0x34, 0x56";

    const output = try asm_inst.assemble(source);
    try expectBytes(&[_]u8{ 0x12, 0x34, 0x56 }, output);
}

test "asm: .db with decimal" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source = ".db 10, 20, 30";

    const output = try asm_inst.assemble(source);
    try expectBytes(&[_]u8{ 10, 20, 30 }, output);
}

test "asm: .db with character literal" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source = ".db 'A', 'B', 'C'";

    const output = try asm_inst.assemble(source);
    try expectBytes(&[_]u8{ 'A', 'B', 'C' }, output);
}

test "asm: .dw words" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source = ".dw 0x1234, 0xABCD";

    const output = try asm_inst.assemble(source);
    // Little endian
    try expectBytes(&[_]u8{ 0x34, 0x12, 0xCD, 0xAB }, output);
}

test "asm: .ds reserve space" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\.ds 4
        \\    HALT
    ;

    const output = try asm_inst.assemble(source);
    try std.testing.expectEqual(@as(usize, 5), output.len);
    try std.testing.expectEqual(@as(u8, 0x00), output[0]);
    try std.testing.expectEqual(@as(u8, 0x00), output[1]);
    try std.testing.expectEqual(@as(u8, 0x00), output[2]);
    try std.testing.expectEqual(@as(u8, 0x00), output[3]);
    try std.testing.expectEqual(@as(u8, 0x01), output[4]); // HALT
}

// ============================================================================
// Assembler - Case Insensitivity
// ============================================================================

test "asm: case insensitive mnemonics" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output1 = try asm_inst.assemble("halt");
    const output2 = try asm_inst.assemble("HALT");
    const output3 = try asm_inst.assemble("Halt");

    try expectBytes(output1, output2);
    try expectBytes(output2, output3);
}

test "asm: case insensitive registers" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output1 = try asm_inst.assemble("MOV r0, r1");
    const output2 = try asm_inst.assemble("MOV R0, R1");

    try expectBytes(output1, output2);
}

test "asm: case insensitive directives" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const output1 = try asm_inst.assemble(".EQU X, 1\nMOVI R0, X");
    const output2 = try asm_inst.assemble(".equ X, 1\nMOVI R0, X");

    try expectBytes(output1, output2);
}

// ============================================================================
// Assembler - Complete Programs
// ============================================================================

test "asm: fill screen program" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\.equ FRAMEBUFFER, 0x4000
        \\.equ SCREEN_SIZE, 16384
        \\.equ RED, 0xE0
        \\
        \\    MOVI R0, FRAMEBUFFER
        \\    MOVI R1, RED
        \\    MOVI R2, SCREEN_SIZE
        \\    MEMSET
        \\    DISPLAY
        \\    HALT
    ;

    const output = try asm_inst.assemble(source);

    // Expected: 3 MOVI (4 bytes each) + MEMSET (1) + DISPLAY (1) + HALT (1) = 15 bytes
    try std.testing.expectEqual(@as(usize, 15), output.len);

    // Check MOVI R0, 0x4000
    try std.testing.expectEqual(@as(u8, 0x11), output[0]); // MOVI opcode
    try std.testing.expectEqual(@as(u8, 0x00), output[2]); // 0x4000 low
    try std.testing.expectEqual(@as(u8, 0x40), output[3]); // 0x4000 high

    // Check MOVI R1, 0xE0
    try std.testing.expectEqual(@as(u8, 0xE0), output[6]); // 0xE0

    // Check MOVI R2, 16384 (0x4000)
    try std.testing.expectEqual(@as(u8, 0x00), output[10]); // 16384 low
    try std.testing.expectEqual(@as(u8, 0x40), output[11]); // 16384 high

    // Check final instructions
    try std.testing.expectEqual(@as(u8, 0x71), output[12]); // MEMSET
    try std.testing.expectEqual(@as(u8, 0x02), output[13]); // DISPLAY
    try std.testing.expectEqual(@as(u8, 0x01), output[14]); // HALT
}

test "asm: loop with conditional jump" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\    MOVI R0, 10
        \\loop:
        \\    DEC R0
        \\    JNZ loop
        \\    HALT
    ;

    const output = try asm_inst.assemble(source);

    // MOVI R0, 10 (4 bytes) at 0x0000
    // DEC R0 (2 bytes) at 0x0004
    // JNZ loop (3 bytes) at 0x0006, jump to 0x0004
    // HALT (1 byte) at 0x0009
    try std.testing.expectEqual(@as(usize, 10), output.len);
    try std.testing.expectEqual(@as(u8, 0x04), output[7]); // loop address low
}

test "asm: subroutine call" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const source =
        \\main:
        \\    CALL sub
        \\    HALT
        \\sub:
        \\    NOP
        \\    RET
    ;

    const output = try asm_inst.assemble(source);

    // CALL sub (3 bytes) at 0x0000, sub at 0x0004
    // HALT (1 byte) at 0x0003
    // NOP (1 byte) at 0x0004
    // RET (1 byte) at 0x0005
    try std.testing.expectEqual(@as(usize, 6), output.len);
    try std.testing.expectEqual(@as(u8, 0x60), output[0]); // CALL
    try std.testing.expectEqual(@as(u8, 0x04), output[1]); // sub address low
    try std.testing.expectEqual(@as(u8, 0x03), output[5]); // RET
}

// ============================================================================
// Assembler - Error Handling
// ============================================================================

test "asm: error on undefined label" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const result = asm_inst.assemble("JMP undefined_label");
    try std.testing.expectError(error.UndefinedLabel, result);
}

test "asm: error on invalid register" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const result = asm_inst.assemble("MOV R8, R0");
    try std.testing.expectError(error.InvalidRegister, result);
}

test "asm: error on invalid mnemonic" {
    var asm_inst = Assembler.init(std.testing.allocator);
    defer asm_inst.deinit();

    const result = asm_inst.assemble("INVALID R0, R1");
    try std.testing.expectError(error.InvalidMnemonic, result);
}

// ============================================================================
// Assembler - All Conditional Jumps
// ============================================================================

test "asm: all conditional jumps" {
    const jumps = [_]struct { mnemonic: []const u8, opcode: u8 }{
        .{ .mnemonic = "JZ", .opcode = 0x52 },
        .{ .mnemonic = "JNZ", .opcode = 0x53 },
        .{ .mnemonic = "JC", .opcode = 0x54 },
        .{ .mnemonic = "JNC", .opcode = 0x55 },
        .{ .mnemonic = "JN", .opcode = 0x56 },
        .{ .mnemonic = "JNN", .opcode = 0x57 },
        .{ .mnemonic = "JO", .opcode = 0x58 },
        .{ .mnemonic = "JNO", .opcode = 0x59 },
        .{ .mnemonic = "JA", .opcode = 0x5A },
        .{ .mnemonic = "JBE", .opcode = 0x5B },
        .{ .mnemonic = "JG", .opcode = 0x5C },
        .{ .mnemonic = "JGE", .opcode = 0x5D },
        .{ .mnemonic = "JL", .opcode = 0x5E },
        .{ .mnemonic = "JLE", .opcode = 0x5F },
    };

    for (jumps) |j| {
        var asm_inst = Assembler.init(std.testing.allocator);
        defer asm_inst.deinit();

        var buf: [32]u8 = undefined;
        const source = std.fmt.bufPrint(&buf, "{s} 0x0000", .{j.mnemonic}) catch unreachable;

        const output = asm_inst.assemble(source) catch |err| {
            std.debug.print("Failed on {s}: {}\n", .{ j.mnemonic, err });
            return err;
        };

        try std.testing.expectEqual(j.opcode, output[0]);
    }
}

// ============================================================================
// Assembler - All Arithmetic/Logical Instructions
// ============================================================================

test "asm: all two-register instructions" {
    const instrs = [_]struct { mnemonic: []const u8, opcode: u8 }{
        .{ .mnemonic = "ADD", .opcode = 0x20 },
        .{ .mnemonic = "SUB", .opcode = 0x22 },
        .{ .mnemonic = "MUL", .opcode = 0x24 },
        .{ .mnemonic = "DIV", .opcode = 0x25 },
        .{ .mnemonic = "AND", .opcode = 0x30 },
        .{ .mnemonic = "OR", .opcode = 0x32 },
        .{ .mnemonic = "XOR", .opcode = 0x34 },
        .{ .mnemonic = "SHL", .opcode = 0x37 },
        .{ .mnemonic = "SHR", .opcode = 0x39 },
        .{ .mnemonic = "SAR", .opcode = 0x3B },
        .{ .mnemonic = "CMP", .opcode = 0x40 },
        .{ .mnemonic = "TEST", .opcode = 0x42 },
    };

    for (instrs) |instr| {
        var asm_inst = Assembler.init(std.testing.allocator);
        defer asm_inst.deinit();

        var buf: [32]u8 = undefined;
        const source = std.fmt.bufPrint(&buf, "{s} R0, R1", .{instr.mnemonic}) catch unreachable;

        const output = asm_inst.assemble(source) catch |err| {
            std.debug.print("Failed on {s}: {}\n", .{ instr.mnemonic, err });
            return err;
        };

        try std.testing.expectEqual(instr.opcode, output[0]);
    }
}

test "asm: all single-register instructions" {
    const instrs = [_]struct { mnemonic: []const u8, opcode: u8 }{
        .{ .mnemonic = "INC", .opcode = 0x26 },
        .{ .mnemonic = "DEC", .opcode = 0x27 },
        .{ .mnemonic = "NEG", .opcode = 0x28 },
        .{ .mnemonic = "NOT", .opcode = 0x36 },
        .{ .mnemonic = "POP", .opcode = 0x17 },
    };

    for (instrs) |instr| {
        var asm_inst = Assembler.init(std.testing.allocator);
        defer asm_inst.deinit();

        var buf: [32]u8 = undefined;
        const source = std.fmt.bufPrint(&buf, "{s} R0", .{instr.mnemonic}) catch unreachable;

        const output = asm_inst.assemble(source) catch |err| {
            std.debug.print("Failed on {s}: {}\n", .{ instr.mnemonic, err });
            return err;
        };

        try std.testing.expectEqual(instr.opcode, output[0]);
    }
}
