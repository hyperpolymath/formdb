// SPDX-License-Identifier: AGPL-3.0-or-later
// Form.Bridge - Build Configuration

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main library
    const lib = b.addStaticLibrary(.{
        .name = "formdb_bridge",
        .root_source_file = b.path("src/bridge.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Also build shared library for FFI
    const shared_lib = b.addSharedLibrary(.{
        .name = "formdb_bridge",
        .root_source_file = b.path("src/bridge.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Export C ABI
    lib.root_module.addCMacro("FDB_EXPORT", "");
    shared_lib.root_module.addCMacro("FDB_EXPORT", "");

    // Install artifacts
    b.installArtifact(lib);
    b.installArtifact(shared_lib);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/bridge.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
