const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlm_dep = b.dependency("zlm", .{});

    const lib = b.addModule("toto-ui", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "src/c/stb_truetype_impl.c" } } });
    lib.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "src/c/stb_image_impl.c" } } });
    lib.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "src/c/stb_image_write_impl.c" } } });
    lib.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "src/c" } });

    lib.addImport("zlm", zlm_dep.module("zlm"));

    const test_app = b.addExecutable(.{
        .name = "test-app",
        .root_source_file = b.path("test_app/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    test_app.root_module.addImport("toto-ui", lib);

    if (b.lazyDependency("glfw", .{
        .target = target,
        .optimize = optimize,
    })) |dep| {
        test_app.linkLibrary(dep.artifact("glfw"));
        @import("glfw").addPaths(&test_app.root_module);
    }

    test_app.root_module.addImport("zlm", zlm_dep.module("zlm"));

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.1",
        .profile = .core,
    });
    test_app.root_module.addImport("gl", gl_bindings);

    b.installArtifact(test_app);

    const test_cmd = b.addRunArtifact(test_app);
    test_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        test_cmd.addArgs(args);
    }

    const run_step = b.step("test", "Run the test app");
    run_step.dependOn(&test_cmd.step);
}
