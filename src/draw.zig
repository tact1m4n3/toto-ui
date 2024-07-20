const std = @import("std");
const Allocator = std.mem.Allocator;
const zlm = @import("zlm");

pub const Command = union(enum) {
    quad: Quad,
    rect: Rect,
};

pub const Quad = struct {
    position: zlm.Vec2,
    size: zlm.Vec2,
    color: zlm.Vec4,
    tex_id: ?u32,
};

pub const Rect = struct {
    position: zlm.Vec2,
    size: zlm.Vec2,
    fill_color: zlm.Vec4,
    stroke_color: zlm.Vec4,
    stroke_width: f32,
    radius: f32,
};

pub const Vertex = extern struct {
    position: zlm.Vec2,
    color: zlm.Vec4,
    tex_coord: u32,
    tex_idx: u32,
};

pub const VertexBuffer = std.ArrayList(Vertex);
pub const IndexBuffer = std.ArrayList(u32);

pub const RenderPass = struct {
    vertices: *VertexBuffer,
    indices: *IndexBuffer,
    tex_ids: [16]u32, // TODO: shouldn't be hardcoded
    tex_count: usize,

    pub fn init(allocator: Allocator, white_tex_id: u32, font_tex_id: u32) RenderPass {
        const vertex_buffer = VertexBuffer.init(allocator);
        const index_buffer = IndexBuffer.init(allocator);
        return .{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .texture_ids = [_]u32{ white_tex_id, font_tex_id },
            .texture_count = 2,
        };
    }

    pub fn submit(render_pass: *RenderPass, command: Command) !bool {
        const quad_tex_coords = [_]zlm.Vec2{
            .{ .x = 0.0, .y = 0.0 },
            .{ .x = 1.0, .y = 0.0 },
            .{ .x = 1.0, .y = 1.0 },
            .{ .x = 0.0, .y = 1.0 },
        };

        const offset = render_pass.vertices.items.len;

        switch (command) {
            .quad => |quad| {
                const tex_idx = if (quad.tex_id) |tex_id| {
                    if (render_pass.tex_count >= 16) {
                        return false;
                    }
                    const tex_idx = render_pass.tex_count;
                    render_pass.tex_ids[tex_idx] = tex_id;
                    render_pass.tex_count += 1;
                    tex_idx;
                } else {
                    0;
                };

                inline for (quad_tex_coords) |tex_coord| {
                    render_pass.vertices.append(.{
                        .position = quad.position.add(quad.size.mul(tex_coord)),
                        .color = quad.color,
                        .tex_coord = tex_coord,
                        .tex_idx = tex_idx,
                    });
                }

                render_pass.indices.append(offset + 0);
                render_pass.indices.append(offset + 1);
                render_pass.indices.append(offset + 2);
                render_pass.indices.append(offset + 2);
                render_pass.indices.append(offset + 3);
                render_pass.indices.append(offset + 0);
            },
            // .rect => |rect| {},
        }

        return true;
    }
};
