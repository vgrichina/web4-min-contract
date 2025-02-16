const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    });

    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    // Main WASM artifact
    const web4_lib = b.addExecutable(.{
        .name = "web4-min",
        .root_source_file = b.path("web4-min.zig"),
        .target = target,
        .optimize = optimize,
        .strip = true,
    });

    // Enable link-time optimization
    web4_lib.want_lto = true;

    // Don't need start function for WASM
    web4_lib.entry = .disabled;

    // Export the required functions
    web4_lib.root_module.export_symbol_names = &[_][]const u8{
        "web4_get",
        "web4_setStaticUrl",
        "web4_setOwner",
    };

    b.installArtifact(web4_lib);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("web4-min.test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Create a step for running the tests
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
