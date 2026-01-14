//! HackVM CPU Implementation
//!
//! 16-bit CPU with 8 general-purpose registers, stack, and flags.

const std = @import("std");
const Memory = @import("memory.zig").Memory;
const opcodes = @import("opcodes.zig");
const Opcode = opcodes.Opcode;

/// CPU Flags
pub const Flags = packed struct(u8) {
    z: bool = false, // Zero
    c: bool = false, // Carry
    n: bool = false, // Negative
    v: bool = false, // Overflow
    _pad: u4 = 0,

    pub fn toU8(self: Flags) u8 {
        return @bitCast(self);
    }

    pub fn fromU8(val: u8) Flags {
        return @bitCast(val);
    }
};

pub const CPU = struct {
    /// General purpose registers R0-R7
    r: [8]u16,

    /// Program Counter
    pc: u16,

    /// Stack Pointer
    sp: u16,

    /// Status Flags
    flags: Flags,

    /// CPU halted flag
    halted: bool,

    /// Display requested flag (set by DISPLAY instruction)
    display_requested: bool,

    /// Total cycles executed
    cycles: u64,

    /// Memory reference
    mem: *Memory,

    const INITIAL_SP: u16 = 0xFFEF;

    pub fn init(mem: *Memory) CPU {
        return CPU{
            .r = [_]u16{0} ** 8,
            .pc = 0x0000,
            .sp = INITIAL_SP,
            .flags = Flags{},
            .halted = false,
            .display_requested = false,
            .cycles = 0,
            .mem = mem,
        };
    }

    pub fn reset(self: *CPU) void {
        self.r = [_]u16{0} ** 8;
        self.pc = 0x0000;
        self.sp = INITIAL_SP;
        self.flags = Flags{};
        self.halted = false;
        self.display_requested = false;
        self.cycles = 0;
    }

    /// Execute one instruction, return cycle cost
    pub fn step(self: *CPU) u32 {
        if (self.halted) return 0;

        const opcode_byte = self.fetch8();
        const cost = self.execute(opcode_byte);
        self.cycles += cost;
        return cost;
    }

    /// Fetch 8-bit value at PC and increment PC
    fn fetch8(self: *CPU) u8 {
        const val = self.mem.read8(self.pc);
        self.pc +%= 1;
        return val;
    }

    /// Fetch 16-bit value at PC (little-endian) and increment PC by 2
    fn fetch16(self: *CPU) u16 {
        const val = self.mem.read16(self.pc);
        self.pc +%= 2;
        return val;
    }

    /// Decode register byte: [Rd:3][Rs:3][xx:2]
    fn decodeRegs(byte: u8) struct { rd: u3, rs: u3 } {
        return .{
            .rd = @truncate(byte >> 5),
            .rs = @truncate((byte >> 2) & 0x07),
        };
    }

    /// Push 16-bit value onto stack
    fn push(self: *CPU, val: u16) void {
        self.sp -%= 2;
        self.mem.write16(self.sp, val);
    }

    /// Pop 16-bit value from stack
    fn pop(self: *CPU) u16 {
        const val = self.mem.read16(self.sp);
        self.sp +%= 2;
        return val;
    }

    /// Set flags for arithmetic operations
    fn setArithmeticFlags(self: *CPU, result: u16, a: u16, b: u16, is_sub: bool) void {
        self.flags.z = result == 0;
        self.flags.n = (result & 0x8000) != 0;

        if (is_sub) {
            // Subtraction: carry set if borrow occurred (a < b for unsigned)
            self.flags.c = a < b;
            // Overflow: sign of result differs from expected
            const a_neg = (a & 0x8000) != 0;
            const b_neg = (b & 0x8000) != 0;
            const r_neg = (result & 0x8000) != 0;
            self.flags.v = (a_neg != b_neg) and (r_neg == b_neg);
        } else {
            // Addition: carry set if result wrapped
            self.flags.c = result < a or result < b;
            // Overflow: both operands same sign, result different sign
            const a_neg = (a & 0x8000) != 0;
            const b_neg = (b & 0x8000) != 0;
            const r_neg = (result & 0x8000) != 0;
            self.flags.v = (a_neg == b_neg) and (r_neg != a_neg);
        }
    }

    /// Set flags for logical operations (only Z and N)
    fn setLogicalFlags(self: *CPU, result: u16) void {
        self.flags.z = result == 0;
        self.flags.n = (result & 0x8000) != 0;
    }

    /// Execute an instruction, return cycle cost
    fn execute(self: *CPU, opcode_byte: u8) u32 {
        const op: Opcode = @enumFromInt(opcode_byte);

        return switch (op) {
            // ============ System Instructions ============
            .NOP => 1,

            .HALT => {
                self.halted = true;
                return 1;
            },

            .DISPLAY => {
                self.display_requested = true;
                return 1000;
            },

            .RET => {
                self.pc = self.pop();
                return 5;
            },

            .PUSHF => {
                self.push(@as(u16, self.flags.toU8()));
                return 3;
            },

            .POPF => {
                self.flags = Flags.fromU8(@truncate(self.pop()));
                return 3;
            },

            // ============ Data Movement ============
            .MOV => {
                const regs = decodeRegs(self.fetch8());
                self.r[regs.rd] = self.r[regs.rs];
                return 2;
            },

            .MOVI => {
                const regs = decodeRegs(self.fetch8());
                const imm = self.fetch16();
                self.r[regs.rd] = imm;
                return 3;
            },

            .LOAD => {
                const regs = decodeRegs(self.fetch8());
                const addr = self.r[regs.rs];
                self.r[regs.rd] = self.mem.read16(addr);
                return 4;
            },

            .LOADB => {
                const regs = decodeRegs(self.fetch8());
                const addr = self.r[regs.rs];
                self.r[regs.rd] = self.mem.read8(addr);
                return 3;
            },

            .STORE => {
                const regs = decodeRegs(self.fetch8());
                const addr = self.r[regs.rd];
                self.mem.write16(addr, self.r[regs.rs]);
                return 4;
            },

            .STOREB => {
                const regs = decodeRegs(self.fetch8());
                const addr = self.r[regs.rd];
                self.mem.write8(addr, @truncate(self.r[regs.rs]));
                return 3;
            },

            .PUSH => {
                const regs = decodeRegs(self.fetch8());
                self.push(self.r[regs.rs]);
                return 4;
            },

            .POP => {
                const regs = decodeRegs(self.fetch8());
                self.r[regs.rd] = self.pop();
                return 4;
            },

            // ============ Arithmetic ============
            .ADD => {
                const regs = decodeRegs(self.fetch8());
                const a = self.r[regs.rd];
                const b = self.r[regs.rs];
                const result = a +% b;
                self.r[regs.rd] = result;
                self.setArithmeticFlags(result, a, b, false);
                return 2;
            },

            .ADDI => {
                const regs = decodeRegs(self.fetch8());
                const imm: u16 = self.fetch8();
                const a = self.r[regs.rd];
                const result = a +% imm;
                self.r[regs.rd] = result;
                self.setArithmeticFlags(result, a, imm, false);
                return 3;
            },

            .SUB => {
                const regs = decodeRegs(self.fetch8());
                const a = self.r[regs.rd];
                const b = self.r[regs.rs];
                const result = a -% b;
                self.r[regs.rd] = result;
                self.setArithmeticFlags(result, a, b, true);
                return 2;
            },

            .SUBI => {
                const regs = decodeRegs(self.fetch8());
                const imm: u16 = self.fetch8();
                const a = self.r[regs.rd];
                const result = a -% imm;
                self.r[regs.rd] = result;
                self.setArithmeticFlags(result, a, imm, true);
                return 3;
            },

            .MUL => {
                const regs = decodeRegs(self.fetch8());
                const a: u32 = self.r[regs.rd];
                const b: u32 = self.r[regs.rs];
                const result: u16 = @truncate(a * b);
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 8;
            },

            .DIV => {
                const regs = decodeRegs(self.fetch8());
                const a = self.r[regs.rd];
                const b = self.r[regs.rs];

                if (b == 0) {
                    // Division by zero: result = 0xFFFF, remainder (R0) = dividend
                    self.r[regs.rd] = 0xFFFF;
                    self.r[0] = a;
                } else {
                    self.r[regs.rd] = a / b;
                    self.r[0] = a % b;
                }
                self.setLogicalFlags(self.r[regs.rd]);
                return 12;
            },

            .INC => {
                const regs = decodeRegs(self.fetch8());
                const a = self.r[regs.rd];
                const result = a +% 1;
                self.r[regs.rd] = result;
                self.setArithmeticFlags(result, a, 1, false);
                return 2;
            },

            .DEC => {
                const regs = decodeRegs(self.fetch8());
                const a = self.r[regs.rd];
                const result = a -% 1;
                self.r[regs.rd] = result;
                self.setArithmeticFlags(result, a, 1, true);
                return 2;
            },

            .NEG => {
                const regs = decodeRegs(self.fetch8());
                const a = self.r[regs.rd];
                const result = 0 -% a;
                self.r[regs.rd] = result;
                self.setArithmeticFlags(result, 0, a, true);
                return 2;
            },

            // ============ Logical ============
            .AND => {
                const regs = decodeRegs(self.fetch8());
                const result = self.r[regs.rd] & self.r[regs.rs];
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .ANDI => {
                const regs = decodeRegs(self.fetch8());
                const imm: u16 = self.fetch8();
                const result = self.r[regs.rd] & imm;
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 3;
            },

            .OR => {
                const regs = decodeRegs(self.fetch8());
                const result = self.r[regs.rd] | self.r[regs.rs];
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .ORI => {
                const regs = decodeRegs(self.fetch8());
                const imm: u16 = self.fetch8();
                const result = self.r[regs.rd] | imm;
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 3;
            },

            .XOR => {
                const regs = decodeRegs(self.fetch8());
                const result = self.r[regs.rd] ^ self.r[regs.rs];
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .XORI => {
                const regs = decodeRegs(self.fetch8());
                const imm: u16 = self.fetch8();
                const result = self.r[regs.rd] ^ imm;
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 3;
            },

            .NOT => {
                const regs = decodeRegs(self.fetch8());
                const result = ~self.r[regs.rd];
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .SHL => {
                const regs = decodeRegs(self.fetch8());
                const shift: u4 = @truncate(self.r[regs.rs] & 0x0F);
                const val = self.r[regs.rd];

                if (shift > 0) {
                    self.flags.c = ((val >> @as(u4, @intCast(@as(u5, 16) - shift))) & 1) != 0;
                }

                const result = val << shift;
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .SHLI => {
                const regs = decodeRegs(self.fetch8());
                const shift: u4 = regs.rs; // Use rs field as immediate
                const val = self.r[regs.rd];

                if (shift > 0) {
                    self.flags.c = ((val >> @as(u4, @intCast(@as(u5, 16) - shift))) & 1) != 0;
                }

                const result = val << shift;
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .SHR => {
                const regs = decodeRegs(self.fetch8());
                const shift: u4 = @truncate(self.r[regs.rs] & 0x0F);
                const val = self.r[regs.rd];

                if (shift > 0) {
                    self.flags.c = ((val >> (shift - 1)) & 1) != 0;
                }

                const result = val >> shift;
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .SHRI => {
                const regs = decodeRegs(self.fetch8());
                const shift: u4 = regs.rs;
                const val = self.r[regs.rd];

                if (shift > 0) {
                    self.flags.c = ((val >> (shift - 1)) & 1) != 0;
                }

                const result = val >> shift;
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .SAR => {
                const regs = decodeRegs(self.fetch8());
                const shift: u4 = @truncate(self.r[regs.rs] & 0x0F);
                const val: i16 = @bitCast(self.r[regs.rd]);

                if (shift > 0) {
                    self.flags.c = ((@as(u16, @bitCast(val)) >> (shift - 1)) & 1) != 0;
                }

                const result: u16 = @bitCast(val >> shift);
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            .SARI => {
                const regs = decodeRegs(self.fetch8());
                const shift: u4 = regs.rs;
                const val: i16 = @bitCast(self.r[regs.rd]);

                if (shift > 0) {
                    self.flags.c = ((@as(u16, @bitCast(val)) >> (shift - 1)) & 1) != 0;
                }

                const result: u16 = @bitCast(val >> shift);
                self.r[regs.rd] = result;
                self.setLogicalFlags(result);
                return 2;
            },

            // ============ Comparison ============
            .CMP => {
                const regs = decodeRegs(self.fetch8());
                const a = self.r[regs.rd];
                const b = self.r[regs.rs];
                const result = a -% b;
                self.setArithmeticFlags(result, a, b, true);
                return 2;
            },

            .CMPI => {
                const regs = decodeRegs(self.fetch8());
                const imm: u16 = self.fetch8();
                const a = self.r[regs.rd];
                const result = a -% imm;
                self.setArithmeticFlags(result, a, imm, true);
                return 3;
            },

            .TEST => {
                const regs = decodeRegs(self.fetch8());
                const result = self.r[regs.rd] & self.r[regs.rs];
                self.setLogicalFlags(result);
                return 2;
            },

            .TESTI => {
                const regs = decodeRegs(self.fetch8());
                const imm: u16 = self.fetch8();
                const result = self.r[regs.rd] & imm;
                self.setLogicalFlags(result);
                return 3;
            },

            // ============ Control Flow ============
            .JMP => {
                self.pc = self.fetch16();
                return 3;
            },

            .JMPR => {
                const regs = decodeRegs(self.fetch8());
                self.pc = self.r[regs.rs];
                return 2;
            },

            .JZ => self.conditionalJump(self.flags.z),
            .JNZ => self.conditionalJump(!self.flags.z),
            .JC => self.conditionalJump(self.flags.c),
            .JNC => self.conditionalJump(!self.flags.c),
            .JN => self.conditionalJump(self.flags.n),
            .JNN => self.conditionalJump(!self.flags.n),
            .JO => self.conditionalJump(self.flags.v),
            .JNO => self.conditionalJump(!self.flags.v),

            // JA: above (unsigned) - C=0 and Z=0
            .JA => self.conditionalJump(!self.flags.c and !self.flags.z),

            // JBE: below or equal (unsigned) - C=1 or Z=1
            .JBE => self.conditionalJump(self.flags.c or self.flags.z),

            // JG: greater (signed) - Z=0 and N=V
            .JG => self.conditionalJump(!self.flags.z and (self.flags.n == self.flags.v)),

            // JGE: greater or equal (signed) - N=V
            .JGE => self.conditionalJump(self.flags.n == self.flags.v),

            // JL: less (signed) - N!=V
            .JL => self.conditionalJump(self.flags.n != self.flags.v),

            // JLE: less or equal (signed) - Z=1 or N!=V
            .JLE => self.conditionalJump(self.flags.z or (self.flags.n != self.flags.v)),

            .CALL => {
                const addr = self.fetch16();
                self.push(self.pc);
                self.pc = addr;
                return 6;
            },

            .CALLR => {
                const regs = decodeRegs(self.fetch8());
                self.push(self.pc);
                self.pc = self.r[regs.rs];
                return 5;
            },

            // ============ Memory Block Operations ============
            .MEMCPY => {
                const count = self.r[2];
                var src = self.r[0];
                var dst = self.r[1];

                var i: u16 = 0;
                while (i < count) : (i += 1) {
                    self.mem.write8(dst, self.mem.read8(src));
                    src +%= 1;
                    dst +%= 1;
                }

                self.r[0] = src;
                self.r[1] = dst;
                self.r[2] = 0;

                return 5 + @as(u32, count);
            },

            .MEMSET => {
                const count = self.r[2];
                var dst = self.r[0];
                const val: u8 = @truncate(self.r[1]);

                var i: u16 = 0;
                while (i < count) : (i += 1) {
                    self.mem.write8(dst, val);
                    dst +%= 1;
                }

                self.r[0] = dst;
                self.r[2] = 0;

                return 5 + @as(u32, count);
            },

            // Unknown opcode - treat as NOP
            _ => 1,
        };
    }

    /// Handle conditional jump, return cycle cost
    fn conditionalJump(self: *CPU, condition: bool) u32 {
        const addr = self.fetch16();
        if (condition) {
            self.pc = addr;
            return 4; // Branch taken
        }
        return 2; // Branch not taken
    }
};

// ============ Tests ============

test "basic instructions" {
    var mem = Memory.init();
    var cpu = CPU.init(&mem);

    // Test MOVI R0, 0x1234
    mem.data[0] = @intFromEnum(Opcode.MOVI);
    mem.data[1] = 0b000_000_00; // Rd=0
    mem.data[2] = 0x34; // Low byte
    mem.data[3] = 0x12; // High byte

    _ = cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.r[0]);
}

test "arithmetic flags" {
    var mem = Memory.init();
    var cpu = CPU.init(&mem);

    // Test zero flag
    cpu.r[0] = 5;
    cpu.r[1] = 5;

    mem.data[0] = @intFromEnum(Opcode.SUB);
    mem.data[1] = 0b000_001_00; // Rd=0, Rs=1

    _ = cpu.step();
    try std.testing.expectEqual(@as(u16, 0), cpu.r[0]);
    try std.testing.expect(cpu.flags.z);
}

test "conditional jump" {
    var mem = Memory.init();
    var cpu = CPU.init(&mem);

    cpu.flags.z = true;

    // JZ 0x0100
    mem.data[0] = @intFromEnum(Opcode.JZ);
    mem.data[1] = 0x00; // Low byte of address
    mem.data[2] = 0x01; // High byte of address

    _ = cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0100), cpu.pc);
}

test "stack operations" {
    var mem = Memory.init();
    var cpu = CPU.init(&mem);

    cpu.r[0] = 0xABCD;

    // PUSH R0
    mem.data[0] = @intFromEnum(Opcode.PUSH);
    mem.data[1] = 0b000_000_00; // Rs=0

    const initial_sp = cpu.sp;
    _ = cpu.step();
    try std.testing.expectEqual(initial_sp - 2, cpu.sp);

    // POP R1
    mem.data[2] = @intFromEnum(Opcode.POP);
    mem.data[3] = 0b001_000_00; // Rd=1

    _ = cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.r[1]);
    try std.testing.expectEqual(initial_sp, cpu.sp);
}

test "memset" {
    var mem = Memory.init();
    var cpu = CPU.init(&mem);

    // Set up registers for MEMSET
    cpu.r[0] = 0x4000; // Destination
    cpu.r[1] = 0xFF; // Value
    cpu.r[2] = 10; // Count

    mem.data[0] = @intFromEnum(Opcode.MEMSET);

    const cycles = cpu.step();

    // Check cycle cost
    try std.testing.expectEqual(@as(u32, 15), cycles); // 5 + 10

    // Check memory was filled
    for (0..10) |i| {
        try std.testing.expectEqual(@as(u8, 0xFF), mem.data[0x4000 + i]);
    }

    // Check register state after
    try std.testing.expectEqual(@as(u16, 0x400A), cpu.r[0]); // dst advanced
    try std.testing.expectEqual(@as(u16, 0), cpu.r[2]); // count = 0
}

test "memcpy" {
    var mem = Memory.init();
    var cpu = CPU.init(&mem);

    // Set up source data
    mem.data[0x1000] = 0x11;
    mem.data[0x1001] = 0x22;
    mem.data[0x1002] = 0x33;
    mem.data[0x1003] = 0x44;

    // Set up registers for MEMCPY
    cpu.r[0] = 0x1000; // Source
    cpu.r[1] = 0x2000; // Destination
    cpu.r[2] = 4; // Count

    mem.data[0] = @intFromEnum(Opcode.MEMCPY);

    const cycles = cpu.step();

    // Check cycle cost
    try std.testing.expectEqual(@as(u32, 9), cycles); // 5 + 4

    // Check data was copied
    try std.testing.expectEqual(@as(u8, 0x11), mem.data[0x2000]);
    try std.testing.expectEqual(@as(u8, 0x22), mem.data[0x2001]);
    try std.testing.expectEqual(@as(u8, 0x33), mem.data[0x2002]);
    try std.testing.expectEqual(@as(u8, 0x44), mem.data[0x2003]);
}
