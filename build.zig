const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Build the solution runner.
    const binary = b.addExecutable(.{
        .name = "aoc",
        .root_source_file = b.path("runner.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(binary);

    // Build step to run the solution runner.
    const run_cmd = b.addRunArtifact(binary);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Build step to run the solution runner.
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Build the test runner.
    // XXX: use a custom test runner for better output:
    //   https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b
    //   https://gist.github.com/nurpax/4afcb6e4ef3f03f0d282f7c462005f12
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("runner.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Build step to run the test runner.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
