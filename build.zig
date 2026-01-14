const std = @import("std");

pub fn build(b: *std.Build) void {
    // WASM target for browser
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // =====================================================
    // Emulator WASM
    // =====================================================
    const emu_wasm = b.addExecutable(.{
        .name = "hackvm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        }),
    });

    emu_wasm.entry = .disabled;
    emu_wasm.rdynamic = true;
    emu_wasm.root_module.export_symbol_names = &.{
        "init",
        "reset",
        "run",
        "isHalted",
        "displayRequested",
        "getFramebufferPtr",
        "getMemoryPtr",
        "setKeyState",
        "updateTimers",
        "getCyclesExecuted",
        "getPC",
        "getSP",
        "getRegister",
        "getFlags",
    };

    const install_emu_wasm = b.addInstallArtifact(emu_wasm, .{
        .dest_dir = .{ .override = .{ .custom = "../web/public" } },
    });

    // =====================================================
    // Assembler WASM
    // =====================================================
    const asm_wasm = b.addExecutable(.{
        .name = "hackvm-asm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/asm_main.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        }),
    });

    asm_wasm.entry = .disabled;
    asm_wasm.rdynamic = true;
    asm_wasm.root_module.export_symbol_names = &.{
        "asm_init",
        "asm_getSourcePtr",
        "asm_setSourceLen",
        "asm_assemble",
        "asm_getOutputPtr",
        "asm_getOutputLen",
        "asm_getErrorPtr",
        "asm_getErrorLen",
    };

    const install_asm_wasm = b.addInstallArtifact(asm_wasm, .{
        .dest_dir = .{ .override = .{ .custom = "../web/public" } },
    });

    // Combined WASM build step
    const wasm_step = b.step("wasm", "Build both WASM binaries");
    wasm_step.dependOn(&install_emu_wasm.step);
    wasm_step.dependOn(&install_asm_wasm.step);

    // =====================================================
    // Native binary (unified emulator + assembler CLI)
    // =====================================================
    const native_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const native = b.addExecutable(.{
        .name = "hackvm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/native_main.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(native);

    const run_cmd = b.addRunArtifact(native);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run native CLI");
    run_step.dependOn(&run_cmd.step);

    // =====================================================
    // Tests
    // =====================================================
    const test_step = b.step("test", "Run all unit tests");

    // CPU tests
    const cpu_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cpu.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(cpu_tests).step);

    // Memory tests
    const mem_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/memory.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(mem_tests).step);

    // Lexer tests
    const lexer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lexer.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(lexer_tests).step);

    // Assembler tests (inline tests in assembler.zig)
    const asm_inline_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/assembler.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(asm_inline_tests).step);

    // Assembler comprehensive tests
    const asm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/assembler_test.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(asm_tests).step);
}
