const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "toto-ui",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "src/c/stb_truetype_impl.c" } } });
    exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "src/c/stb_image_impl.c" } } });
    exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "src/c/stb_image_write_impl.c" } } });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "src/c" } });

    b.installArtifact(exe);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (b.lazyDependency("glfw", .{
        .target = target,
        .optimize = optimize,
    })) |dep| {
        exe.linkLibrary(dep.artifact("glfw"));
        @import("glfw").addPaths(&exe.root_module);
        exe_unit_tests.linkLibrary(dep.artifact("glfw"));
        @import("glfw").addPaths(&exe_unit_tests.root_module);
    }

    const zlm_dep = b.dependency("zlm", .{});
    exe.root_module.addImport("zlm", zlm_dep.module("zlm"));

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.1",
        .profile = .core,
    });
    exe.root_module.addImport("gl", gl_bindings);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
