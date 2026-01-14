//! HackVM Assembler - WASM Entry Point
//!
//! Exports functions for JavaScript to assemble source code.

const std = @import("std");
const Assembler = @import("assembler.zig").Assembler;

// Fixed-size buffers for WASM
var source_buffer: [65536]u8 = undefined;
var source_len: usize = 0;
var output_buffer: [65536]u8 = undefined;
var output_len: usize = 0;
var error_buffer: [4096]u8 = undefined;
var error_len: usize = 0;

var assembler: ?Assembler = null;

// Simple allocator for WASM (uses a static buffer)
var heap_buffer: [1024 * 1024]u8 = undefined; // 1MB heap
var fba = std.heap.FixedBufferAllocator.init(&heap_buffer);

/// Initialize the assembler
export fn asm_init() void {
    fba.reset();
    if (assembler) |*a| {
        a.deinit();
    }
    assembler = Assembler.init(fba.allocator());
    source_len = 0;
    output_len = 0;
    error_len = 0;
}

/// Get pointer to source buffer for writing
export fn asm_getSourcePtr() [*]u8 {
    return &source_buffer;
}

/// Set the length of source code written to buffer
export fn asm_setSourceLen(len: u32) void {
    source_len = @min(len, source_buffer.len);
}

/// Assemble the source code
/// Returns: 1 on success, 0 on error
export fn asm_assemble() u32 {
    var asm_instance = assembler orelse {
        setError("Assembler not initialized");
        return 0;
    };

    const source = source_buffer[0..source_len];

    const output = asm_instance.assemble(source) catch |err| {
        // Format error message
        const errors = asm_instance.getErrors();
        if (errors.len > 0) {
            const e = errors[0];
            const msg = std.fmt.bufPrint(&error_buffer, "Line {d}: {s}", .{ e.line, e.message }) catch {
                setError("Assembly failed");
                return 0;
            };
            error_len = msg.len;
        } else {
            const msg = std.fmt.bufPrint(&error_buffer, "Assembly error: {s}", .{@errorName(err)}) catch {
                setError("Assembly failed");
                return 0;
            };
            error_len = msg.len;
        }
        return 0;
    };

    // Copy output to buffer
    const len = @min(output.len, output_buffer.len);
    @memcpy(output_buffer[0..len], output[0..len]);
    output_len = len;
    error_len = 0;

    return 1;
}

/// Get pointer to output buffer
export fn asm_getOutputPtr() [*]const u8 {
    return &output_buffer;
}

/// Get length of assembled output
export fn asm_getOutputLen() u32 {
    return @intCast(output_len);
}

/// Get pointer to error buffer
export fn asm_getErrorPtr() [*]const u8 {
    return &error_buffer;
}

/// Get length of error message
export fn asm_getErrorLen() u32 {
    return @intCast(error_len);
}

fn setError(msg: []const u8) void {
    const len = @min(msg.len, error_buffer.len);
    @memcpy(error_buffer[0..len], msg[0..len]);
    error_len = len;
}
