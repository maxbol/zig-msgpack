const std = @import("std");
const Build = std.Build;
const Module = Build.Module;
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const msgpack = b.addModule("msgpack", .{
        .root_source_file = .{
            .path = "src/msgpack.zig",
        },
    });

    const test_step = b.step("test", "Run unit tests");

    const msgpack_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/msgpack_unit_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    msgpack_unit_tests.root_module.addImport("msgpack", msgpack);
    const run_msgpack_tests = b.addRunArtifact(msgpack_unit_tests);
    test_step.dependOn(&run_msgpack_tests.step);
}
