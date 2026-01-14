const std = @import("std");

pub fn build(b: *std.Build) void {
    // WASM target for browser
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const wasm = b.addExecutable(.{
        .name = "hackvm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        }),
    });

    wasm.entry = .disabled;
    wasm.rdynamic = true;
    wasm.root_module.export_symbol_names = &.{
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

    const install_wasm = b.addInstallArtifact(wasm, .{
        .dest_dir = .{ .override = .{ .custom = "../web" } },
    });

    const wasm_step = b.step("wasm", "Build WASM binary");
    wasm_step.dependOn(&install_wasm.step);

    // Native target for testing
    const native_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const native = b.addExecutable(.{
        .name = "hackvm-native",
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

    const run_step = b.step("run", "Run native emulator with a program");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cpu.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}