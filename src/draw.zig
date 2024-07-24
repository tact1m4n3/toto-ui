const std = @import("std");
const Allocator = std.mem.Allocator;
const zlm = @import("zlm");

const Ui = @import("Ui.zig");

pub const UvRect = struct {
    position: zlm.Vec2,
    size: zlm.Vec2,

    const full: UvRect = .{
        .position = zlm.Vec2.zero,
        .size = zlm.Vec2.one,
    };
};

pub const Command = union(enum) {
    quad: Quad,
};

pub const Quad = struct {
    position: zlm.Vec2,
    size: zlm.Vec2,
    color: zlm.Vec4 = zlm.Vec4.one,
    texture: ?usize = null,
    uv_rect: UvRect = UvRect.full,
};

pub const Vertex = extern struct {
    position: zlm.Vec2,
    color: zlm.Vec4,
    tex_coord: zlm.Vec2,
    tex_index: f32,
};

const max_textures = 64;

const VertexBuffer = std.ArrayList(Vertex);
const IndexBuffer = std.ArrayList(u32);
const TextureArray = std.BoundedArray(usize, max_textures);

pub const RenderPass = struct {
    const default_tex_index = 0;

    vertices: VertexBuffer,
    indices: IndexBuffer,
    textures: TextureArray,

    pub fn init(allocator: Allocator, default_texture: usize) RenderPass {
        const vertices = VertexBuffer.init(allocator);
        const indices = IndexBuffer.init(allocator);

        var textures = TextureArray.init(0) catch unreachable; // TODO: configurable at runtime
        textures.append(default_texture) catch unreachable;

        return .{
            .vertices = vertices,
            .indices = indices,
            .textures = textures,
        };
    }

    pub fn deinit(render_pass: *RenderPass) void {
        render_pass.vertices.deinit();
        render_pass.indices.deinit();
    }

    pub fn submit(render_pass: *RenderPass, command: Command) !void {
        const quad_tex_coords = [_]zlm.Vec2{
            .{ .x = 0.0, .y = 0.0 },
            .{ .x = 1.0, .y = 0.0 },
            .{ .x = 1.0, .y = 1.0 },
            .{ .x = 0.0, .y = 1.0 },
        };

        const quad_indices = [_]u32{ 0, 1, 2, 2, 3, 0 };

        const offset: u32 = @intCast(render_pass.vertices.items.len);

        switch (command) {
            .quad => |quad| {
                const tex_index = if (quad.texture) |texture|
                    for (render_pass.textures.buffer, 0..render_pass.textures.len) |current, i| {
                        if (current == texture) {
                            break i;
                        }
                    } else ret: {
                        const i = render_pass.textures.len;
                        try render_pass.textures.append(texture);
                        break :ret i;
                    }
                else
                    default_tex_index;

                inline for (quad_tex_coords) |tex_coord| {
                    try render_pass.vertices.append(.{
                        .position = quad.position.add(quad.size.mul(tex_coord)),
                        .color = quad.color,
                        .tex_coord = quad.uv_rect.position.add(quad.uv_rect.size.mul(tex_coord)),
                        .tex_index = @floatFromInt(tex_index),
                    });
                }

                inline for (quad_indices) |index| {
                    try render_pass.indices.append(offset + index);
                }
            },
        }
    }
};
