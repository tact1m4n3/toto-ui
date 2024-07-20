const std = @import("std");
const zlm = @import("zlm");
const gl = @import("gl");

const draw = @import("draw.zig");
const Font = @import("Font.zig");
const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");

var gl_procs: gl.ProcTable = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var font = try Font.load(allocator, @embedFile("Anonymous Pro.ttf"), 128.0);
    defer font.deinit();
    //
    // const window = try Window.init(.{ .width = 800, .height = 800, .title = "Hello world" });
    // defer window.deinit();
    //
    // if (!gl_procs.init(Window.getProcAddress)) {
    //     return error.OpenGlLoadError;
    // }
    //
    // gl.makeProcTableCurrent(&gl_procs);
    // defer gl.makeProcTableCurrent(null);
    //
    // gl.Enable(gl.BLEND);
    // gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    //
    // const framebuffer_size = window.getFramebufferSize();
    // var renderer = try Renderer.init(allocator, .{ .x = @floatFromInt(framebuffer_size.width), .y = @floatFromInt(framebuffer_size.height) });
    // defer renderer.deinit();
    //
    // while (true) {
    //     window.pollEvents();
    //
    //     if (window.shouldClose()) break;
    //
    //     {
    //         gl.ClearColor(0, 0, 0, 0);
    //         gl.Clear(gl.COLOR_BUFFER_BIT);
    //
    //         renderer.render_quad(
    //             .{ .x = 400.0, .y = 600.0 },
    //             .{ .x = 800.0, .y = 400.0 },
    //             .{ .x = 0.2, .y = 0.3, .z = 0.9, .w = 0.5 },
    //             zlm.Vec4.one,
    //             50.0,
    //             5.0,
    //         );
    //
    //         renderer.flush();
    //     }
    //
    //     window.swapBuffers();
    // }
}
