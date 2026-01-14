//! HackVM Assembler - Lexer
//!
//! Tokenizes assembly source code into a stream of tokens.

const std = @import("std");

pub const TokenType = enum {
    // Identifiers and literals
    identifier, // Labels, mnemonics, register names
    number, // Numeric literals (decimal, hex, binary)
    string, // String literals "..."
    char_literal, // Character literals 'x'

    // Punctuation
    comma, // ,
    colon, // :
    lbracket, // [
    rbracket, // ]
    dot, // .
    plus, // +
    minus, // -
    star, // *

    // Special
    newline,
    eof,
    invalid,
};

pub const Token = struct {
    type: TokenType,
    text: []const u8,
    line: u32,
    column: u32,

    pub fn format(self: Token, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}:{d}:{d} '{s}'", .{ @tagName(self.type), self.line, self.column, self.text });
    }
};

pub const Lexer = struct {
    source: []const u8,
    pos: usize,
    line: u32,
    column: u32,
    line_start: usize,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
            .column = 1,
            .line_start = 0,
        };
    }

    pub fn next(self: *Lexer) Token {
        self.skipWhitespaceAndComments();

        if (self.isAtEnd()) {
            return self.makeToken(.eof, "");
        }

        const start = self.pos;
        const start_col = self.column;
        const c = self.advance();

        // Newline
        if (c == '\n') {
            const tok = Token{
                .type = .newline,
                .text = self.source[start..self.pos],
                .line = self.line - 1, // Line was already incremented
                .column = start_col,
            };
            return tok;
        }

        // Punctuation
        switch (c) {
            ',' => return self.makeToken(.comma, self.source[start..self.pos]),
            ':' => return self.makeToken(.colon, self.source[start..self.pos]),
            '[' => return self.makeToken(.lbracket, self.source[start..self.pos]),
            ']' => return self.makeToken(.rbracket, self.source[start..self.pos]),
            '.' => return self.makeToken(.dot, self.source[start..self.pos]),
            '+' => return self.makeToken(.plus, self.source[start..self.pos]),
            '-' => return self.makeToken(.minus, self.source[start..self.pos]),
            '*' => return self.makeToken(.star, self.source[start..self.pos]),
            else => {},
        }

        // String literal
        if (c == '"') {
            return self.readString(start);
        }

        // Character literal
        if (c == '\'') {
            return self.readChar(start);
        }

        // Number (starts with digit or 0x/0b prefix)
        if (std.ascii.isDigit(c)) {
            return self.readNumber(start);
        }

        // Identifier (starts with letter or underscore)
        if (std.ascii.isAlphabetic(c) or c == '_') {
            return self.readIdentifier(start);
        }

        return self.makeToken(.invalid, self.source[start..self.pos]);
    }

    fn skipWhitespaceAndComments(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                ' ', '\t', '\r' => _ = self.advance(),
                ';' => {
                    // Skip comment until end of line
                    while (!self.isAtEnd() and self.peek() != '\n') {
                        _ = self.advance();
                    }
                },
                else => return,
            }
        }
    }

    fn readString(self: *Lexer, start: usize) Token {
        while (!self.isAtEnd() and self.peek() != '"' and self.peek() != '\n') {
            if (self.peek() == '\\') {
                _ = self.advance(); // Skip escape char
                if (!self.isAtEnd()) _ = self.advance();
            } else {
                _ = self.advance();
            }
        }

        if (self.isAtEnd() or self.peek() == '\n') {
            return self.makeToken(.invalid, self.source[start..self.pos]);
        }

        _ = self.advance(); // Closing quote
        return self.makeToken(.string, self.source[start..self.pos]);
    }

    fn readChar(self: *Lexer, start: usize) Token {
        if (self.isAtEnd()) {
            return self.makeToken(.invalid, self.source[start..self.pos]);
        }

        if (self.peek() == '\\') {
            _ = self.advance(); // Backslash
            if (!self.isAtEnd()) _ = self.advance(); // Escaped char
        } else {
            _ = self.advance(); // Regular char
        }

        if (self.isAtEnd() or self.peek() != '\'') {
            return self.makeToken(.invalid, self.source[start..self.pos]);
        }

        _ = self.advance(); // Closing quote
        return self.makeToken(.char_literal, self.source[start..self.pos]);
    }

    fn readNumber(self: *Lexer, start: usize) Token {
        // Check for hex (0x) or binary (0b) prefix
        if (self.source[start] == '0' and !self.isAtEnd()) {
            const next_char = self.peek();
            if (next_char == 'x' or next_char == 'X') {
                _ = self.advance(); // Skip 'x'
                while (!self.isAtEnd() and std.ascii.isHex(self.peek())) {
                    _ = self.advance();
                }
                return self.makeToken(.number, self.source[start..self.pos]);
            } else if (next_char == 'b' or next_char == 'B') {
                _ = self.advance(); // Skip 'b'
                while (!self.isAtEnd() and (self.peek() == '0' or self.peek() == '1')) {
                    _ = self.advance();
                }
                return self.makeToken(.number, self.source[start..self.pos]);
            }
        }

        // Decimal number
        while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }

        return self.makeToken(.number, self.source[start..self.pos]);
    }

    fn readIdentifier(self: *Lexer, start: usize) Token {
        while (!self.isAtEnd()) {
            const c = self.peek();
            if (std.ascii.isAlphanumeric(c) or c == '_') {
                _ = self.advance();
            } else {
                break;
            }
        }

        return self.makeToken(.identifier, self.source[start..self.pos]);
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.pos];
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.pos];
        self.pos += 1;
        if (c == '\n') {
            self.line += 1;
            self.column = 1;
            self.line_start = self.pos;
        } else {
            self.column += 1;
        }
        return c;
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.source.len;
    }

    fn makeToken(self: *Lexer, token_type: TokenType, text: []const u8) Token {
        return Token{
            .type = token_type,
            .text = text,
            .line = self.line,
            .column = @intCast(self.pos - self.line_start - text.len + 1),
        };
    }
};

test "lexer basics" {
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
}

test "lexer numbers" {
    const source = "123 0xFF 0b1010";
    var lexer = Lexer.init(source);

    const t1 = lexer.next();
    try std.testing.expectEqualStrings("123", t1.text);

    const t2 = lexer.next();
    try std.testing.expectEqualStrings("0xFF", t2.text);

    const t3 = lexer.next();
    try std.testing.expectEqualStrings("0b1010", t3.text);
}
