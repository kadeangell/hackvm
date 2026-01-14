//! HackVM Memory System
//!
//! 64KB address space with memory-mapped I/O for timers and keyboard.

pub const FRAMEBUFFER_START: u16 = 0x4000;
pub const FRAMEBUFFER_END: u16 = 0x7FFF;
pub const FRAMEBUFFER_SIZE: u16 = 16384;

pub const RAM_START: u16 = 0x8000;
pub const RAM_END: u16 = 0xFFEF;

// Memory-mapped I/O addresses
pub const SYS_TIMER_LOW: u16 = 0xFFF0;
pub const SYS_TIMER_HIGH: u16 = 0xFFF1;
pub const COUNTDOWN_LOW: u16 = 0xFFF2;
pub const COUNTDOWN_HIGH: u16 = 0xFFF3;
pub const KEY_CODE: u16 = 0xFFF4;
pub const KEY_STATE: u16 = 0xFFF5;

pub const Memory = struct {
    data: [65536]u8,

    // Timer state (updated by host based on wall clock)
    sys_timer: u16,
    countdown_timer: u16,

    // Keyboard state (set by host)
    key_code: u8,
    key_state: u8,

    pub fn init() Memory {
        return Memory{
            .data = [_]u8{0} ** 65536,
            .sys_timer = 0,
            .countdown_timer = 0,
            .key_code = 0,
            .key_state = 0,
        };
    }

    pub fn reset(self: *Memory) void {
        @memset(&self.data, 0);
        self.sys_timer = 0;
        self.countdown_timer = 0;
        self.key_code = 0;
        self.key_state = 0;
    }

    /// Read a single byte from memory
    pub fn read8(self: *const Memory, addr: u16) u8 {
        return switch (addr) {
            SYS_TIMER_LOW => @truncate(self.sys_timer),
            SYS_TIMER_HIGH => @truncate(self.sys_timer >> 8),
            COUNTDOWN_LOW => @truncate(self.countdown_timer),
            COUNTDOWN_HIGH => @truncate(self.countdown_timer >> 8),
            KEY_CODE => self.key_code,
            KEY_STATE => self.key_state,
            else => self.data[addr],
        };
    }

    /// Read a 16-bit word from memory (little-endian)
    pub fn read16(self: *const Memory, addr: u16) u16 {
        const low: u16 = self.read8(addr);
        const high: u16 = self.read8(addr +% 1);
        return low | (high << 8);
    }

    /// Write a single byte to memory
    pub fn write8(self: *Memory, addr: u16, val: u8) void {
        switch (addr) {
            // Read-only registers - ignore writes
            SYS_TIMER_LOW, SYS_TIMER_HIGH, KEY_CODE, KEY_STATE => {},

            // Countdown timer is writable
            COUNTDOWN_LOW => self.countdown_timer = (self.countdown_timer & 0xFF00) | @as(u16, val),
            COUNTDOWN_HIGH => self.countdown_timer = (self.countdown_timer & 0x00FF) | (@as(u16, val) << 8),

            // Reserved area - ignore writes
            0xFFF6...0xFFFF => {},

            // Normal memory
            else => self.data[addr] = val,
        }
    }

    /// Write a 16-bit word to memory (little-endian)
    pub fn write16(self: *Memory, addr: u16, val: u16) void {
        self.write8(addr, @truncate(val));
        self.write8(addr +% 1, @truncate(val >> 8));
    }

    /// Update timers (called by host with elapsed milliseconds)
    pub fn updateTimers(self: *Memory, delta_ms: u16) void {
        self.sys_timer +%= delta_ms;

        if (self.countdown_timer > delta_ms) {
            self.countdown_timer -= delta_ms;
        } else {
            self.countdown_timer = 0;
        }
    }

    /// Set keyboard state (called by host on key events)
    pub fn setKeyState(self: *Memory, code: u8, pressed: bool) void {
        if (pressed) {
            self.key_code = code;
            self.key_state = 1;
        } else {
            self.key_state = 0;
        }
    }

    /// Get pointer to framebuffer for direct access
    pub fn getFramebufferPtr(self: *Memory) [*]u8 {
        return @ptrCast(&self.data[FRAMEBUFFER_START]);
    }

    /// Get pointer to full memory for program loading
    pub fn getMemoryPtr(self: *Memory) [*]u8 {
        return @ptrCast(&self.data[0]);
    }

    /// Load a program into memory starting at address 0
    pub fn loadProgram(self: *Memory, program: []const u8) void {
        const len = @min(program.len, 0x4000); // Max program size is 16KB
        @memcpy(self.data[0..len], program[0..len]);
    }
};

test "memory read/write" {
    var mem = Memory.init();

    // Test basic read/write
    mem.write8(0x1000, 0xAB);
    try @import("std").testing.expectEqual(@as(u8, 0xAB), mem.read8(0x1000));

    // Test 16-bit read/write (little-endian)
    mem.write16(0x2000, 0x1234);
    try @import("std").testing.expectEqual(@as(u16, 0x1234), mem.read16(0x2000));
    try @import("std").testing.expectEqual(@as(u8, 0x34), mem.read8(0x2000)); // Low byte
    try @import("std").testing.expectEqual(@as(u8, 0x12), mem.read8(0x2001)); // High byte
}

test "timer I/O" {
    var mem = Memory.init();

    // System timer is read-only
    mem.sys_timer = 0x5678;
    try @import("std").testing.expectEqual(@as(u8, 0x78), mem.read8(SYS_TIMER_LOW));
    try @import("std").testing.expectEqual(@as(u8, 0x56), mem.read8(SYS_TIMER_HIGH));

    // Writing to system timer should be ignored
    mem.write8(SYS_TIMER_LOW, 0xFF);
    try @import("std").testing.expectEqual(@as(u16, 0x5678), mem.sys_timer);

    // Countdown timer is read/write
    mem.write16(COUNTDOWN_LOW, 0x1000);
    try @import("std").testing.expectEqual(@as(u16, 0x1000), mem.countdown_timer);
}

test "timer update" {
    var mem = Memory.init();

    mem.sys_timer = 0;
    mem.countdown_timer = 100;

    mem.updateTimers(50);
    try @import("std").testing.expectEqual(@as(u16, 50), mem.sys_timer);
    try @import("std").testing.expectEqual(@as(u16, 50), mem.countdown_timer);

    mem.updateTimers(60);
    try @import("std").testing.expectEqual(@as(u16, 110), mem.sys_timer);
    try @import("std").testing.expectEqual(@as(u16, 0), mem.countdown_timer); // Clamped to 0
}
