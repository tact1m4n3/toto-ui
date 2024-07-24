const std = @import("std");
const time = std.time;
const zlm = @import("zlm");
const gl = @import("gl");
const toto_ui = @import("toto-ui");

const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");

var gl_procs: gl.ProcTable = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var font_atlas = try toto_ui.FontAtlas.init(allocator, 1024, 1024, @embedFile("fonts/Anonymous Pro.ttf"), 2, 64);
    defer font_atlas.deinit();

    const window = try Window.init(.{ .width = 800, .height = 600, .title = "Hello world" });
    defer window.deinit();

    if (!gl_procs.init(Window.getProcAddress)) {
        return error.OpenGlLoadError;
    }

    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    const atlas_data = try allocator.alloc(u8, font_atlas.width * font_atlas.height * 4);
    defer allocator.free(atlas_data);
    for (0..font_atlas.height) |i| {
        for (0..font_atlas.width) |j| {
            atlas_data[4 * (i * font_atlas.width + j) + 0] = 255;
            atlas_data[4 * (i * font_atlas.width + j) + 1] = 255;
            atlas_data[4 * (i * font_atlas.width + j) + 2] = 255;
            atlas_data[4 * (i * font_atlas.width + j) + 3] = font_atlas.data[i * font_atlas.width + j];
        }
    }

    var atlas_tex: c_uint = undefined;
    gl.GenTextures(1, (&atlas_tex)[0..1]);
    defer gl.DeleteTextures(1, (&atlas_tex)[0..1]);

    gl.BindTexture(gl.TEXTURE_2D, atlas_tex);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(font_atlas.width), @intCast(font_atlas.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, atlas_data.ptr);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    var renderer = try Renderer.init(.{ .x = 800, .y = 600 });
    defer renderer.deinit();

    const text = "Hello world!\nI like tiramissu!";

    while (true) {
        window.pollEvents();

        if (window.shouldClose()) break;

        {
            gl.ClearColor(0, 0, 0, 0);
            gl.Clear(gl.COLOR_BUFFER_BIT);

            var render_pass = toto_ui.draw.RenderPass.init(allocator, @intCast(atlas_tex));
            defer render_pass.deinit();

            const scale: f32 = 1;
            var position = zlm.vec2(100, 100);
            for (text) |ch| {
                if (ch == '\n') {
                    position.y += font_atlas.advance_y * scale;
                    position.x = 100;
                    continue;
                }

                const glyph_info = font_atlas.glyphs.get(ch).?;
                try render_pass.submit(.{
                    .quad = .{
                        .position = position.add(glyph_info.offset.mul(.{ .x = scale, .y = scale })),
                        .size = glyph_info.size.mul(.{ .x = scale, .y = scale }),
                        .color = zlm.vec4(0.2, 0.3, 0.5, 1),
                        .uv_rect = glyph_info.uv_rect,
                    },
                });
                position.x += glyph_info.advance * scale;
            }

            renderer.submit(render_pass);
        }

        window.swapBuffers();
    }
}
