//! HackVM Opcode Definitions
//!
//! This file contains all opcode values and their cycle costs.

pub const Opcode = enum(u8) {
    // System (0x00-0x0F)
    NOP = 0x00,
    HALT = 0x01,
    DISPLAY = 0x02,
    RET = 0x03,
    PUSHF = 0x04,
    POPF = 0x05,
    PUTC = 0x06,
    PUTS = 0x07,
    PUTI = 0x08,
    PUTX = 0x09,
    GETC = 0x0A,
    GETS = 0x0B,
    KBHIT = 0x0C,

    // Data Movement (0x10-0x1F)
    MOV = 0x10,
    MOVI = 0x11,
    LOAD = 0x12,
    LOADB = 0x13,
    STORE = 0x14,
    STOREB = 0x15,
    PUSH = 0x16,
    POP = 0x17,

    // Arithmetic (0x20-0x2F)
    ADD = 0x20,
    ADDI = 0x21,
    SUB = 0x22,
    SUBI = 0x23,
    MUL = 0x24,
    DIV = 0x25,
    INC = 0x26,
    DEC = 0x27,
    NEG = 0x28,

    // Logical (0x30-0x3F)
    AND = 0x30,
    ANDI = 0x31,
    OR = 0x32,
    ORI = 0x33,
    XOR = 0x34,
    XORI = 0x35,
    NOT = 0x36,
    SHL = 0x37,
    SHLI = 0x38,
    SHR = 0x39,
    SHRI = 0x3A,
    SAR = 0x3B,
    SARI = 0x3C,

    // Comparison (0x40-0x4F)
    CMP = 0x40,
    CMPI = 0x41,
    TEST = 0x42,
    TESTI = 0x43,

    // Control Flow (0x50-0x6F)
    JMP = 0x50,
    JMPR = 0x51,
    JZ = 0x52,
    JNZ = 0x53,
    JC = 0x54,
    JNC = 0x55,
    JN = 0x56,
    JNN = 0x57,
    JO = 0x58,
    JNO = 0x59,
    JA = 0x5A,
    JBE = 0x5B,
    JG = 0x5C,
    JGE = 0x5D,
    JL = 0x5E,
    JLE = 0x5F,
    CALL = 0x60,
    CALLR = 0x61,

    // Memory Block (0x70-0x7F)
    MEMCPY = 0x70,
    MEMSET = 0x71,

    _,
};

/// Cycle costs for each instruction
/// Index by opcode value
pub const cycle_costs = blk: {
    var costs = [_]u32{1} ** 256; // Default 1 cycle for unknown

    // System
    costs[@intFromEnum(Opcode.NOP)] = 1;
    costs[@intFromEnum(Opcode.HALT)] = 1;
    costs[@intFromEnum(Opcode.DISPLAY)] = 1000;
    costs[@intFromEnum(Opcode.RET)] = 5;
    costs[@intFromEnum(Opcode.PUSHF)] = 3;
    costs[@intFromEnum(Opcode.POPF)] = 3;
    costs[@intFromEnum(Opcode.PUTC)] = 2;
    costs[@intFromEnum(Opcode.PUTS)] = 3; // Base cost, actual = 3 + N
    costs[@intFromEnum(Opcode.PUTI)] = 8;
    costs[@intFromEnum(Opcode.PUTX)] = 6;
    costs[@intFromEnum(Opcode.GETC)] = 2;
    costs[@intFromEnum(Opcode.GETS)] = 4; // Base cost, actual = 4 + N
    costs[@intFromEnum(Opcode.KBHIT)] = 2;

    // Data Movement
    costs[@intFromEnum(Opcode.MOV)] = 2;
    costs[@intFromEnum(Opcode.MOVI)] = 3;
    costs[@intFromEnum(Opcode.LOAD)] = 4;
    costs[@intFromEnum(Opcode.LOADB)] = 3;
    costs[@intFromEnum(Opcode.STORE)] = 4;
    costs[@intFromEnum(Opcode.STOREB)] = 3;
    costs[@intFromEnum(Opcode.PUSH)] = 4;
    costs[@intFromEnum(Opcode.POP)] = 4;

    // Arithmetic
    costs[@intFromEnum(Opcode.ADD)] = 2;
    costs[@intFromEnum(Opcode.ADDI)] = 3;
    costs[@intFromEnum(Opcode.SUB)] = 2;
    costs[@intFromEnum(Opcode.SUBI)] = 3;
    costs[@intFromEnum(Opcode.MUL)] = 8;
    costs[@intFromEnum(Opcode.DIV)] = 12;
    costs[@intFromEnum(Opcode.INC)] = 2;
    costs[@intFromEnum(Opcode.DEC)] = 2;
    costs[@intFromEnum(Opcode.NEG)] = 2;

    // Logical
    costs[@intFromEnum(Opcode.AND)] = 2;
    costs[@intFromEnum(Opcode.ANDI)] = 3;
    costs[@intFromEnum(Opcode.OR)] = 2;
    costs[@intFromEnum(Opcode.ORI)] = 3;
    costs[@intFromEnum(Opcode.XOR)] = 2;
    costs[@intFromEnum(Opcode.XORI)] = 3;
    costs[@intFromEnum(Opcode.NOT)] = 2;
    costs[@intFromEnum(Opcode.SHL)] = 2;
    costs[@intFromEnum(Opcode.SHLI)] = 2;
    costs[@intFromEnum(Opcode.SHR)] = 2;
    costs[@intFromEnum(Opcode.SHRI)] = 2;
    costs[@intFromEnum(Opcode.SAR)] = 2;
    costs[@intFromEnum(Opcode.SARI)] = 2;

    // Comparison
    costs[@intFromEnum(Opcode.CMP)] = 2;
    costs[@intFromEnum(Opcode.CMPI)] = 3;
    costs[@intFromEnum(Opcode.TEST)] = 2;
    costs[@intFromEnum(Opcode.TESTI)] = 3;

    // Control Flow - jumps are 3 for unconditional, 2/4 for conditional
    costs[@intFromEnum(Opcode.JMP)] = 3;
    costs[@intFromEnum(Opcode.JMPR)] = 2;
    // Conditional jumps: cost is set dynamically (2 not taken, 4 taken)
    costs[@intFromEnum(Opcode.JZ)] = 4;
    costs[@intFromEnum(Opcode.JNZ)] = 4;
    costs[@intFromEnum(Opcode.JC)] = 4;
    costs[@intFromEnum(Opcode.JNC)] = 4;
    costs[@intFromEnum(Opcode.JN)] = 4;
    costs[@intFromEnum(Opcode.JNN)] = 4;
    costs[@intFromEnum(Opcode.JO)] = 4;
    costs[@intFromEnum(Opcode.JNO)] = 4;
    costs[@intFromEnum(Opcode.JA)] = 4;
    costs[@intFromEnum(Opcode.JBE)] = 4;
    costs[@intFromEnum(Opcode.JG)] = 4;
    costs[@intFromEnum(Opcode.JGE)] = 4;
    costs[@intFromEnum(Opcode.JL)] = 4;
    costs[@intFromEnum(Opcode.JLE)] = 4;
    costs[@intFromEnum(Opcode.CALL)] = 6;
    costs[@intFromEnum(Opcode.CALLR)] = 5;

    // Memory Block - base cost, actual cost is 5 + N
    costs[@intFromEnum(Opcode.MEMCPY)] = 5;
    costs[@intFromEnum(Opcode.MEMSET)] = 5;

    break :blk costs;
};

/// Instruction sizes in bytes
pub const instruction_sizes = blk: {
    var sizes = [_]u8{1} ** 256; // Default 1 byte

    // 1-byte instructions (no operands)
    sizes[@intFromEnum(Opcode.NOP)] = 1;
    sizes[@intFromEnum(Opcode.HALT)] = 1;
    sizes[@intFromEnum(Opcode.DISPLAY)] = 1;
    sizes[@intFromEnum(Opcode.RET)] = 1;
    sizes[@intFromEnum(Opcode.PUSHF)] = 1;
    sizes[@intFromEnum(Opcode.POPF)] = 1;
    sizes[@intFromEnum(Opcode.MEMCPY)] = 1;
    sizes[@intFromEnum(Opcode.MEMSET)] = 1;

    // Console I/O (2 bytes: opcode + register)
    sizes[@intFromEnum(Opcode.PUTC)] = 2;
    sizes[@intFromEnum(Opcode.PUTS)] = 2;
    sizes[@intFromEnum(Opcode.PUTI)] = 2;
    sizes[@intFromEnum(Opcode.PUTX)] = 2;
    sizes[@intFromEnum(Opcode.GETC)] = 2;
    sizes[@intFromEnum(Opcode.GETS)] = 2;
    sizes[@intFromEnum(Opcode.KBHIT)] = 2;

    // 2-byte instructions (register operands)
    sizes[@intFromEnum(Opcode.MOV)] = 2;
    sizes[@intFromEnum(Opcode.LOAD)] = 2;
    sizes[@intFromEnum(Opcode.LOADB)] = 2;
    sizes[@intFromEnum(Opcode.STORE)] = 2;
    sizes[@intFromEnum(Opcode.STOREB)] = 2;
    sizes[@intFromEnum(Opcode.PUSH)] = 2;
    sizes[@intFromEnum(Opcode.POP)] = 2;
    sizes[@intFromEnum(Opcode.ADD)] = 2;
    sizes[@intFromEnum(Opcode.SUB)] = 2;
    sizes[@intFromEnum(Opcode.MUL)] = 2;
    sizes[@intFromEnum(Opcode.DIV)] = 2;
    sizes[@intFromEnum(Opcode.INC)] = 2;
    sizes[@intFromEnum(Opcode.DEC)] = 2;
    sizes[@intFromEnum(Opcode.NEG)] = 2;
    sizes[@intFromEnum(Opcode.AND)] = 2;
    sizes[@intFromEnum(Opcode.OR)] = 2;
    sizes[@intFromEnum(Opcode.XOR)] = 2;
    sizes[@intFromEnum(Opcode.NOT)] = 2;
    sizes[@intFromEnum(Opcode.SHL)] = 2;
    sizes[@intFromEnum(Opcode.SHLI)] = 2;
    sizes[@intFromEnum(Opcode.SHR)] = 2;
    sizes[@intFromEnum(Opcode.SHRI)] = 2;
    sizes[@intFromEnum(Opcode.SAR)] = 2;
    sizes[@intFromEnum(Opcode.SARI)] = 2;
    sizes[@intFromEnum(Opcode.CMP)] = 2;
    sizes[@intFromEnum(Opcode.TEST)] = 2;
    sizes[@intFromEnum(Opcode.JMPR)] = 2;
    sizes[@intFromEnum(Opcode.CALLR)] = 2;

    // 3-byte instructions (register + imm8 or addr16)
    sizes[@intFromEnum(Opcode.ADDI)] = 3;
    sizes[@intFromEnum(Opcode.SUBI)] = 3;
    sizes[@intFromEnum(Opcode.ANDI)] = 3;
    sizes[@intFromEnum(Opcode.ORI)] = 3;
    sizes[@intFromEnum(Opcode.XORI)] = 3;
    sizes[@intFromEnum(Opcode.CMPI)] = 3;
    sizes[@intFromEnum(Opcode.TESTI)] = 3;
    sizes[@intFromEnum(Opcode.JMP)] = 3;
    sizes[@intFromEnum(Opcode.JZ)] = 3;
    sizes[@intFromEnum(Opcode.JNZ)] = 3;
    sizes[@intFromEnum(Opcode.JC)] = 3;
    sizes[@intFromEnum(Opcode.JNC)] = 3;
    sizes[@intFromEnum(Opcode.JN)] = 3;
    sizes[@intFromEnum(Opcode.JNN)] = 3;
    sizes[@intFromEnum(Opcode.JO)] = 3;
    sizes[@intFromEnum(Opcode.JNO)] = 3;
    sizes[@intFromEnum(Opcode.JA)] = 3;
    sizes[@intFromEnum(Opcode.JBE)] = 3;
    sizes[@intFromEnum(Opcode.JG)] = 3;
    sizes[@intFromEnum(Opcode.JGE)] = 3;
    sizes[@intFromEnum(Opcode.JL)] = 3;
    sizes[@intFromEnum(Opcode.JLE)] = 3;
    sizes[@intFromEnum(Opcode.CALL)] = 3;

    // 4-byte instructions (register + imm16)
    sizes[@intFromEnum(Opcode.MOVI)] = 4;

    break :blk sizes;
};
