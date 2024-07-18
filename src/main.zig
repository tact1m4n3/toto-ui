const std = @import("std");
const zlm = @import("zlm");
const gl = @import("gl");

const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");

var gl_procs: gl.ProcTable = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const window = try Window.init();
    defer window.deinit();

    if (!gl_procs.init(Window.getProcAddress)) {
        return error.OpenGlLoadError;
    }

    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    const framebuffer_size = window.getFramebufferSize();
    var renderer = try Renderer.init(allocator, .{ .x = @floatFromInt(framebuffer_size.width), .y = @floatFromInt(framebuffer_size.height) });
    defer renderer.deinit();

    while (true) {
        window.pollEvents();

        if (window.shouldClose()) break;

        {
            gl.ClearColor(0, 0, 0, 0);
            gl.Clear(gl.COLOR_BUFFER_BIT);

            renderer.render_quad(.{ .x = 100.0, .y = 100.0 }, .{ .x = 40.0, .y = 40.0 }, zlm.Vec4.one);
            renderer.render_quad(.{ .x = 200.0, .y = 200.0 }, .{ .x = 40.0, .y = 40.0 }, zlm.Vec4.one);
            renderer.render_quad(.{ .x = 300.0, .y = 300.0 }, .{ .x = 40.0, .y = 40.0 }, zlm.Vec4.one);

            renderer.flush();
        }

        window.swapBuffers();
    }
}
