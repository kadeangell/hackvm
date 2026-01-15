//! HackVM Assembler - Parser and Code Generator
//!
//! Two-pass assembler:
//! - Pass 1: Collect labels and calculate addresses
//! - Pass 2: Generate machine code, resolve label references

const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lexer.zig").Token;
const TokenType = @import("lexer.zig").TokenType;
const Opcode = @import("opcodes.zig").Opcode;
const instruction_sizes = @import("opcodes.zig").instruction_sizes;

pub const AssemblerError = error{
    UnexpectedToken,
    InvalidMnemonic,
    InvalidRegister,
    InvalidOperand,
    UndefinedLabel,
    DuplicateLabel,
    NumberOutOfRange,
    InvalidDirective,
    UnterminatedString,
    OutOfMemory,
};

pub const Diagnostic = struct {
    line: u32,
    column: u32,
    message: []const u8,
};

pub const Assembler = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    output: std.ArrayListUnmanaged(u8),
    labels: std.StringHashMapUnmanaged(u16),
    constants: std.StringHashMapUnmanaged(i32),
    fixups: std.ArrayListUnmanaged(Fixup),
    diagnostics: std.ArrayListUnmanaged(Diagnostic),
    current_address: u16,
    buffered_token: ?Token,

    const Fixup = struct {
        address: u16,
        label: []const u8,
        line: u32,
        is_relative: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Assembler {
        return .{
            .allocator = allocator,
            .source = "",
            .output = .{},
            .labels = .{},
            .constants = .{},
            .fixups = .{},
            .diagnostics = .{},
            .current_address = 0,
            .buffered_token = null,
        };
    }

    /// Get next token, checking buffer first
    fn nextToken(self: *Assembler, lexer: *Lexer) Token {
        if (self.buffered_token) |tok| {
            self.buffered_token = null;
            return tok;
        }
        return lexer.next();
    }

    /// Put a token back to be returned by next nextToken call
    fn unreadToken(self: *Assembler, token: Token) void {
        self.buffered_token = token;
    }

    pub fn deinit(self: *Assembler) void {
        self.output.deinit(self.allocator);
        self.labels.deinit(self.allocator);
        self.constants.deinit(self.allocator);
        self.fixups.deinit(self.allocator);
        for (self.diagnostics.items) |d| {
            self.allocator.free(d.message);
        }
        self.diagnostics.deinit(self.allocator);
    }

    pub fn assemble(self: *Assembler, source: []const u8) ![]const u8 {
        self.source = source;
        self.output.clearRetainingCapacity();
        self.labels.clearRetainingCapacity();
        self.constants.clearRetainingCapacity();
        self.fixups.clearRetainingCapacity();
        self.current_address = 0;

        // Pass 1: Collect labels
        try self.pass1();

        // Pass 2: Generate code
        self.current_address = 0;
        self.output.clearRetainingCapacity();
        try self.pass2();

        // Resolve fixups
        try self.resolveFixups();

        return self.output.items;
    }

    fn pass1(self: *Assembler) !void {
        var lexer = Lexer.init(self.source);
        self.buffered_token = null;

        while (true) {
            const token = self.nextToken(&lexer);
            if (token.type == .eof) break;
            if (token.type == .newline) continue;

            // Check for label definition
            if (token.type == .identifier) {
                const next = self.nextToken(&lexer);
                if (next.type == .colon) {
                    // Label definition
                    if (self.labels.contains(token.text)) {
                        try self.addDiagnostic(token.line, token.column, "Duplicate label");
                        return error.DuplicateLabel;
                    }
                    try self.labels.put(self.allocator, token.text, self.current_address);
                    continue;
                }
                // Not a label - put back token and calculate instruction size
                self.unreadToken(next);
                try self.calculateSize(token, &lexer);
            } else if (token.type == .dot) {
                try self.handleDirectivePass1(&lexer);
            }

            // Skip to end of line
            self.skipToNewline(&lexer);
        }
    }

    fn pass2(self: *Assembler) !void {
        var lexer = Lexer.init(self.source);
        self.buffered_token = null;

        while (true) {
            const token = self.nextToken(&lexer);
            if (token.type == .eof) break;
            if (token.type == .newline) continue;

            // Skip label definitions
            if (token.type == .identifier) {
                const next = self.nextToken(&lexer);
                if (next.type == .colon) {
                    continue; // Label already processed
                }
                // Not a label - put back the token we read
                self.unreadToken(next);
                // Instruction
                try self.assembleInstruction(token, &lexer);
            } else if (token.type == .dot) {
                try self.handleDirectivePass2(&lexer);
            }
        }
    }

    fn calculateSize(self: *Assembler, mnemonic: Token, lexer: *Lexer) !void {
        const upper = self.toUpper(mnemonic.text);
        const size = self.getInstructionSize(upper) orelse {
            try self.addDiagnostic(mnemonic.line, mnemonic.column, "Unknown mnemonic");
            return error.InvalidMnemonic;
        };
        self.current_address +%= size;
        _ = lexer;
    }

    fn assembleInstruction(self: *Assembler, mnemonic: Token, lexer: *Lexer) !void {
        const upper = self.toUpper(mnemonic.text);

        // Get opcode
        const opcode = self.getOpcode(upper) orelse {
            try self.addDiagnostic(mnemonic.line, mnemonic.column, "Unknown mnemonic");
            return error.InvalidMnemonic;
        };

        try self.output.append(self.allocator,@intFromEnum(opcode));
        self.current_address +%= 1;

        // Parse operands based on instruction type
        switch (opcode) {
            // No operands
            .NOP, .HALT, .DISPLAY, .RET, .PUSHF, .POPF, .MEMCPY, .MEMSET => {},

            // Rd, Rs
            .MOV, .ADD, .SUB, .MUL, .DIV, .AND, .OR, .XOR, .SHL, .SHR, .SAR, .CMP, .TEST => {
                const rd = try self.parseRegister(lexer, mnemonic.line);
                try self.expectToken(lexer, .comma, mnemonic.line);
                const rs = try self.parseRegister(lexer, mnemonic.line);
                try self.output.append(self.allocator,regByte(rd, rs));
                self.current_address +%= 1;
            },

            // [Rd], Rs (store)
            .STORE, .STOREB => {
                try self.expectToken(lexer, .lbracket, mnemonic.line);
                const rd = try self.parseRegister(lexer, mnemonic.line);
                try self.expectToken(lexer, .rbracket, mnemonic.line);
                try self.expectToken(lexer, .comma, mnemonic.line);
                const rs = try self.parseRegister(lexer, mnemonic.line);
                try self.output.append(self.allocator,regByte(rd, rs));
                self.current_address +%= 1;
            },

            // Rd, [Rs] (load)
            .LOAD, .LOADB => {
                const rd = try self.parseRegister(lexer, mnemonic.line);
                try self.expectToken(lexer, .comma, mnemonic.line);
                try self.expectToken(lexer, .lbracket, mnemonic.line);
                const rs = try self.parseRegister(lexer, mnemonic.line);
                try self.expectToken(lexer, .rbracket, mnemonic.line);
                try self.output.append(self.allocator,regByte(rd, rs));
                self.current_address +%= 1;
            },

            // Rd only
            .INC, .DEC, .NEG, .NOT, .POP, .GETC, .GETS, .KBHIT => {
                const rd = try self.parseRegister(lexer, mnemonic.line);
                try self.output.append(self.allocator, regByte(rd, 0));
                self.current_address +%= 1;
            },

            // Rs only (PUSH and console I/O use Rs field)
            .PUSH, .PUTC, .PUTS, .PUTI, .PUTX => {
                const rs = try self.parseRegister(lexer, mnemonic.line);
                try self.output.append(self.allocator, regByte(0, rs));
                self.current_address +%= 1;
            },

            // Rd, imm16
            .MOVI => {
                const rd = try self.parseRegister(lexer, mnemonic.line);
                try self.expectToken(lexer, .comma, mnemonic.line);
                const imm = try self.parseImmediateOrLabel(lexer, mnemonic.line, true);
                try self.output.append(self.allocator,regByte(rd, 0));
                try self.emitWord(imm);
                self.current_address +%= 3;
            },

            // Rd, imm8
            .ADDI, .SUBI, .ANDI, .ORI, .XORI, .CMPI, .TESTI => {
                const rd = try self.parseRegister(lexer, mnemonic.line);
                try self.expectToken(lexer, .comma, mnemonic.line);
                const imm = try self.parseImmediate(lexer, mnemonic.line);
                if (imm > 255 or imm < -128) {
                    try self.addDiagnostic(mnemonic.line, 0, "Immediate value out of range for 8-bit");
                    return error.NumberOutOfRange;
                }
                try self.output.append(self.allocator,regByte(rd, 0));
                try self.output.append(self.allocator,@truncate(@as(u16, @bitCast(@as(i16, @truncate(imm))))));
                self.current_address +%= 2;
            },

            // Rd, imm3 (shift immediate - imm is in Rs field, 3 bits only)
            .SHLI, .SHRI, .SARI => {
                const rd = try self.parseRegister(lexer, mnemonic.line);
                try self.expectToken(lexer, .comma, mnemonic.line);
                const imm = try self.parseImmediate(lexer, mnemonic.line);
                if (imm > 7 or imm < 0) {
                    try self.addDiagnostic(mnemonic.line, 0, "Shift amount must be 0-7");
                    return error.NumberOutOfRange;
                }
                try self.output.append(self.allocator, regByte(rd, @truncate(@as(u8, @intCast(imm)))));
                self.current_address +%= 1;
            },

            // addr16 (jumps)
            .JMP, .JZ, .JNZ, .JC, .JNC, .JN, .JNN, .JO, .JNO, .JA, .JBE, .JG, .JGE, .JL, .JLE, .CALL => {
                const addr = try self.parseImmediateOrLabel(lexer, mnemonic.line, true);
                try self.emitWord(addr);
                self.current_address +%= 2;
            },

            // Rs (register indirect jump/call)
            .JMPR, .CALLR => {
                const rs = try self.parseRegister(lexer, mnemonic.line);
                try self.output.append(self.allocator,regByte(0, rs));
                self.current_address +%= 1;
            },

            _ => {
                try self.addDiagnostic(mnemonic.line, mnemonic.column, "Unhandled opcode");
                return error.InvalidMnemonic;
            },
        }
    }

    fn handleDirectivePass1(self: *Assembler, lexer: *Lexer) !void {
        const directive = self.nextToken(lexer);
        if (directive.type != .identifier) {
            return error.InvalidDirective;
        }

        const upper = self.toUpper(directive.text);

        if (std.mem.eql(u8, upper, "ORG")) {
            const addr = try self.parseImmediate(lexer, directive.line);
            self.current_address = @intCast(@as(u32, @bitCast(addr)) & 0xFFFF);
        } else if (std.mem.eql(u8, upper, "EQU")) {
            const name = self.nextToken(lexer);
            if (name.type != .identifier) return error.InvalidDirective;
            try self.expectToken(lexer, .comma, directive.line);
            const value = try self.parseImmediate(lexer, directive.line);
            try self.constants.put(self.allocator, name.text, value);
        } else if (std.mem.eql(u8, upper, "DB")) {
            // Count bytes
            var count: u16 = 0;
            while (true) {
                const tok = self.nextToken(lexer);
                if (tok.type == .newline or tok.type == .eof) {
                    self.unreadToken(tok); // Put back so skipToNewline can find it
                    break;
                }
                if (tok.type == .comma) continue;
                if (tok.type == .number or tok.type == .identifier or tok.type == .char_literal) {
                    count += 1;
                } else if (tok.type == .string) {
                    count += @intCast(tok.text.len - 2); // Exclude quotes
                }
            }
            self.current_address +%= count;
        } else if (std.mem.eql(u8, upper, "DW")) {
            var count: u16 = 0;
            while (true) {
                const tok = self.nextToken(lexer);
                if (tok.type == .newline or tok.type == .eof) {
                    self.unreadToken(tok); // Put back so skipToNewline can find it
                    break;
                }
                if (tok.type == .comma) continue;
                if (tok.type == .number or tok.type == .identifier) {
                    count += 2;
                }
            }
            self.current_address +%= count;
        } else if (std.mem.eql(u8, upper, "DS")) {
            const size = try self.parseImmediate(lexer, directive.line);
            self.current_address +%= @intCast(@as(u32, @bitCast(size)) & 0xFFFF);
        }
    }

    fn handleDirectivePass2(self: *Assembler, lexer: *Lexer) !void {
        const directive = self.nextToken(lexer);
        if (directive.type != .identifier) {
            return error.InvalidDirective;
        }

        const upper = self.toUpper(directive.text);

        if (std.mem.eql(u8, upper, "ORG")) {
            const addr = try self.parseImmediate(lexer, directive.line);
            const target: u16 = @intCast(@as(u32, @bitCast(addr)) & 0xFFFF);
            // Pad output to reach target address
            while (self.output.items.len < target) {
                try self.output.append(self.allocator,0);
            }
            self.current_address = target;
        } else if (std.mem.eql(u8, upper, "EQU")) {
            // Already handled in pass 1, skip
            _ = self.nextToken(lexer); // name
            _ = self.nextToken(lexer); // comma
            _ = self.nextToken(lexer); // value
        } else if (std.mem.eql(u8, upper, "DB")) {
            while (true) {
                const tok = self.nextToken(lexer);
                if (tok.type == .newline or tok.type == .eof) {
                    self.unreadToken(tok); // Put back so pass2 loop handles it
                    break;
                }
                if (tok.type == .comma) continue;

                if (tok.type == .number) {
                    const val = try self.parseNumber(tok.text);
                    try self.output.append(self.allocator,@truncate(@as(u16, @bitCast(@as(i16, @truncate(val))))));
                    self.current_address +%= 1;
                } else if (tok.type == .char_literal) {
                    const ch = self.parseCharLiteral(tok.text);
                    try self.output.append(self.allocator,ch);
                    self.current_address +%= 1;
                } else if (tok.type == .string) {
                    const str = tok.text[1 .. tok.text.len - 1]; // Remove quotes
                    for (str) |c| {
                        try self.output.append(self.allocator,c);
                        self.current_address +%= 1;
                    }
                } else if (tok.type == .identifier) {
                    const val = try self.resolveIdentifier(tok.text, tok.line);
                    try self.output.append(self.allocator,@truncate(@as(u16, @bitCast(@as(i16, @truncate(val))))));
                    self.current_address +%= 1;
                }
            }
        } else if (std.mem.eql(u8, upper, "DW")) {
            while (true) {
                const tok = self.nextToken(lexer);
                if (tok.type == .newline or tok.type == .eof) {
                    self.unreadToken(tok); // Put back so pass2 loop handles it
                    break;
                }
                if (tok.type == .comma) continue;

                if (tok.type == .number) {
                    const val = try self.parseNumber(tok.text);
                    try self.emitWord(@bitCast(@as(i16, @truncate(val))));
                    self.current_address +%= 2;
                } else if (tok.type == .identifier) {
                    const val = try self.resolveIdentifier(tok.text, tok.line);
                    try self.emitWord(@bitCast(@as(i16, @truncate(val))));
                    self.current_address +%= 2;
                }
            }
        } else if (std.mem.eql(u8, upper, "DS")) {
            const size = try self.parseImmediate(lexer, directive.line);
            const count: u16 = @intCast(@as(u32, @bitCast(size)) & 0xFFFF);
            var i: u16 = 0;
            while (i < count) : (i += 1) {
                try self.output.append(self.allocator,0);
            }
            self.current_address +%= count;
        }
    }

    fn parseRegister(self: *Assembler, lexer: *Lexer, line: u32) !u3 {
        const tok = self.nextToken(lexer);
        if (tok.type != .identifier) {
            try self.addDiagnostic(line, tok.column, "Expected register");
            return error.InvalidRegister;
        }

        const upper = self.toUpper(tok.text);
        if (upper.len == 2 and upper[0] == 'R' and upper[1] >= '0' and upper[1] <= '7') {
            return @intCast(upper[1] - '0');
        }

        try self.addDiagnostic(line, tok.column, "Invalid register name");
        return error.InvalidRegister;
    }

    fn parseImmediate(self: *Assembler, lexer: *Lexer, line: u32) !i32 {
        var negative = false;
        var tok = self.nextToken(lexer);

        if (tok.type == .minus) {
            negative = true;
            tok = self.nextToken(lexer);
        }

        if (tok.type == .number) {
            var val = try self.parseNumber(tok.text);
            if (negative) val = -val;
            return val;
        } else if (tok.type == .identifier) {
            var val = try self.resolveIdentifier(tok.text, line);
            if (negative) val = -val;
            return val;
        } else if (tok.type == .char_literal) {
            var val: i32 = self.parseCharLiteral(tok.text);
            if (negative) val = -val;
            return val;
        }

        try self.addDiagnostic(line, tok.column, "Expected number or identifier");
        return error.InvalidOperand;
    }

    fn parseImmediateOrLabel(self: *Assembler, lexer: *Lexer, line: u32, allow_fixup: bool) !u16 {
        const tok = self.nextToken(lexer);

        if (tok.type == .number) {
            const val = try self.parseNumber(tok.text);
            return @bitCast(@as(i16, @truncate(val)));
        } else if (tok.type == .char_literal) {
            const val = self.parseCharLiteral(tok.text);
            return @as(u16, val);
        } else if (tok.type == .identifier) {
            // Check constants first
            if (self.constants.get(tok.text)) |val| {
                return @bitCast(@as(i16, @truncate(val)));
            }
            // Check labels
            if (self.labels.get(tok.text)) |addr| {
                return addr;
            }
            // Add fixup for forward reference
            if (allow_fixup) {
                try self.fixups.append(self.allocator, .{
                    .address = @intCast(self.output.items.len),
                    .label = tok.text,
                    .line = line,
                    .is_relative = false,
                });
                return 0; // Placeholder
            }
            try self.addDiagnostic(line, tok.column, "Undefined label");
            return error.UndefinedLabel;
        }

        try self.addDiagnostic(line, tok.column, "Expected address");
        return error.InvalidOperand;
    }

    fn resolveIdentifier(self: *Assembler, name: []const u8, line: u32) !i32 {
        if (self.constants.get(name)) |val| {
            return val;
        }
        if (self.labels.get(name)) |addr| {
            return @intCast(addr);
        }
        try self.addDiagnostic(line, 0, "Undefined identifier");
        return error.UndefinedLabel;
    }

    fn parseNumber(self: *Assembler, text: []const u8) !i32 {
        _ = self;
        if (text.len > 2) {
            if (text[0] == '0' and (text[1] == 'x' or text[1] == 'X')) {
                return std.fmt.parseInt(i32, text[2..], 16) catch return error.NumberOutOfRange;
            }
            if (text[0] == '0' and (text[1] == 'b' or text[1] == 'B')) {
                return std.fmt.parseInt(i32, text[2..], 2) catch return error.NumberOutOfRange;
            }
        }
        return std.fmt.parseInt(i32, text, 10) catch return error.NumberOutOfRange;
    }

    fn parseCharLiteral(self: *Assembler, text: []const u8) u8 {
        _ = self;
        if (text.len < 3) return 0;
        if (text[1] == '\\' and text.len >= 4) {
            return switch (text[2]) {
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                '0' => 0,
                '\\' => '\\',
                '\'' => '\'',
                else => text[2],
            };
        }
        return text[1];
    }

    fn expectToken(self: *Assembler, lexer: *Lexer, expected: TokenType, line: u32) !void {
        const tok = self.nextToken(lexer);
        if (tok.type != expected) {
            try self.addDiagnostic(line, tok.column, "Unexpected token");
            return error.UnexpectedToken;
        }
    }

    fn emitWord(self: *Assembler, value: u16) !void {
        try self.output.append(self.allocator,@truncate(value)); // Low byte
        try self.output.append(self.allocator,@truncate(value >> 8)); // High byte
    }

    fn resolveFixups(self: *Assembler) !void {
        for (self.fixups.items) |fixup| {
            const addr = self.labels.get(fixup.label) orelse {
                try self.addDiagnostic(fixup.line, 0, "Undefined label in fixup");
                return error.UndefinedLabel;
            };

            self.output.items[fixup.address] = @truncate(addr);
            self.output.items[fixup.address + 1] = @truncate(addr >> 8);
        }
    }

    fn skipToNewline(self: *Assembler, lexer: *Lexer) void {
        while (true) {
            const tok = self.nextToken(lexer);
            if (tok.type == .newline or tok.type == .eof) break;
        }
    }

    fn addDiagnostic(self: *Assembler, line: u32, column: u32, message: []const u8) !void {
        const msg = try self.allocator.dupe(u8, message);
        try self.diagnostics.append(self.allocator, .{
            .line = line,
            .column = column,
            .message = msg,
        });
    }

    // Static buffer for uppercase conversion
    var upper_buf: [64]u8 = undefined;

    fn toUpper(self: *Assembler, text: []const u8) []const u8 {
        _ = self;
        const len = @min(text.len, upper_buf.len);
        for (text[0..len], 0..) |c, i| {
            upper_buf[i] = std.ascii.toUpper(c);
        }
        return upper_buf[0..len];
    }

    fn getInstructionSize(self: *Assembler, mnemonic: []const u8) ?u8 {
        const opcode = self.getOpcode(mnemonic) orelse return null;
        return instruction_sizes[@intFromEnum(opcode)];
    }

    fn getOpcode(self: *Assembler, mnemonic: []const u8) ?Opcode {
        _ = self;
        // Map mnemonic string to opcode
        const map = std.StaticStringMap(Opcode).initComptime(.{
            .{ "NOP", .NOP },
            .{ "HALT", .HALT },
            .{ "DISPLAY", .DISPLAY },
            .{ "RET", .RET },
            .{ "PUSHF", .PUSHF },
            .{ "POPF", .POPF },
            .{ "PUTC", .PUTC },
            .{ "PUTS", .PUTS },
            .{ "PUTI", .PUTI },
            .{ "PUTX", .PUTX },
            .{ "GETC", .GETC },
            .{ "GETS", .GETS },
            .{ "KBHIT", .KBHIT },
            .{ "MOV", .MOV },
            .{ "MOVI", .MOVI },
            .{ "LOAD", .LOAD },
            .{ "LOADB", .LOADB },
            .{ "STORE", .STORE },
            .{ "STOREB", .STOREB },
            .{ "PUSH", .PUSH },
            .{ "POP", .POP },
            .{ "ADD", .ADD },
            .{ "ADDI", .ADDI },
            .{ "SUB", .SUB },
            .{ "SUBI", .SUBI },
            .{ "MUL", .MUL },
            .{ "DIV", .DIV },
            .{ "INC", .INC },
            .{ "DEC", .DEC },
            .{ "NEG", .NEG },
            .{ "AND", .AND },
            .{ "ANDI", .ANDI },
            .{ "OR", .OR },
            .{ "ORI", .ORI },
            .{ "XOR", .XOR },
            .{ "XORI", .XORI },
            .{ "NOT", .NOT },
            .{ "SHL", .SHL },
            .{ "SHLI", .SHLI },
            .{ "SHR", .SHR },
            .{ "SHRI", .SHRI },
            .{ "SAR", .SAR },
            .{ "SARI", .SARI },
            .{ "CMP", .CMP },
            .{ "CMPI", .CMPI },
            .{ "TEST", .TEST },
            .{ "TESTI", .TESTI },
            .{ "JMP", .JMP },
            .{ "JMPR", .JMPR },
            .{ "JZ", .JZ },
            .{ "JE", .JZ }, // Alias
            .{ "JNZ", .JNZ },
            .{ "JNE", .JNZ }, // Alias
            .{ "JC", .JC },
            .{ "JB", .JC }, // Alias
            .{ "JNC", .JNC },
            .{ "JAE", .JNC }, // Alias
            .{ "JN", .JN },
            .{ "JS", .JN }, // Alias
            .{ "JNN", .JNN },
            .{ "JNS", .JNN }, // Alias
            .{ "JO", .JO },
            .{ "JNO", .JNO },
            .{ "JA", .JA },
            .{ "JBE", .JBE },
            .{ "JG", .JG },
            .{ "JGE", .JGE },
            .{ "JL", .JL },
            .{ "JLE", .JLE },
            .{ "CALL", .CALL },
            .{ "CALLR", .CALLR },
            .{ "MEMCPY", .MEMCPY },
            .{ "MEMSET", .MEMSET },
        });

        return map.get(mnemonic);
    }

    fn regByte(rd: u3, rs: u3) u8 {
        return (@as(u8, rd) << 5) | (@as(u8, rs) << 2);
    }

    pub fn getErrors(self: *Assembler) []const Diagnostic {
        return self.diagnostics.items;
    }
};

test "assemble simple program" {
    const source =
        \\.equ SCREEN, 0x4000
        \\
        \\start:
        \\    MOVI R0, SCREEN
        \\    MOVI R1, 0xFF
        \\    HALT
    ;

    var asm_instance = Assembler.init(std.testing.allocator);
    defer asm_instance.deinit();

    const output = try asm_instance.assemble(source);

    // MOVI R0, 0x4000 = [0x11, 0x00, 0x00, 0x40]
    // MOVI R1, 0xFF = [0x11, 0x20, 0xFF, 0x00]
    // HALT = [0x01]
    try std.testing.expectEqual(@as(usize, 9), output.len);
    try std.testing.expectEqual(@as(u8, 0x11), output[0]); // MOVI
    try std.testing.expectEqual(@as(u8, 0x01), output[8]); // HALT
}
