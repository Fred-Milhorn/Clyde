const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library
    const lib = b.addStaticLibrary(.{
        .name = "clide",
        .root_source_file = b.path("src/clide.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // Demo executable
    const demo = b.addExecutable(.{
        .name = "clide-demo",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo.linkLibrary(lib);
    b.installArtifact(demo);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/clide.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    // Demo tests
    const demo_tests = b.addTest(.{
        .root_source_file = b.path("tests/clide_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo_tests.linkLibrary(lib);
    const run_demo_tests = b.addRunArtifact(demo_tests);
    test_step.dependOn(&run_demo_tests.step);
}
