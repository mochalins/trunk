const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("trunk", .{
        .root_source_file = b.path("src/trunk.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "trunk",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("trunk", mod);
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "trunk",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("trunk", mod);
    var all_args = std.process.args();
    var zig_args: ?*std.Build.Dependency = null;
    while (all_args.next()) |arg| {
        if (std.mem.eql(u8, arg, "cli")) {
            zig_args = b.lazyDependency("zig-args", .{});
        }
    }
    if (zig_args) |dep| {
        exe.root_module.addImport("args", dep.module("args"));
    } else {
        return;
    }
    const exe_install = b.addInstallArtifact(exe, .{});

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const mod_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/trunk.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_mod_unit_tests = b.addRunArtifact(mod_unit_tests);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const cli_step = b.step("cli", "Build the `trunk` CLI application");
    cli_step.dependOn(&exe_install.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_unit_tests.step);
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
