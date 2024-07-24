const std = @import("std");
const Allocator = std.mem.Allocator;
const zlm = @import("zlm");
const gl = @import("gl");

const Renderer = @This();

const log = std.log.scoped(.renderer);

const vertex_shader_path = "shaders/vert.glsl";
const fragment_shader_path = "shaders/frag.glsl";
const max_quads = 2000;
const max_vertices = max_quads * 4;
const max_indices = max_quads * 6;

const quad_tex_coords = [_]zlm.Vec2{
    .{ .x = 0.0, .y = 0.0 },
    .{ .x = 1.0, .y = 0.0 },
    .{ .x = 1.0, .y = 1.0 },
    .{ .x = 0.0, .y = 1.0 },
};

const Vertex = extern struct {
    position: zlm.Vec2,
    tex_coord: zlm.Vec2,
    pixel_size: zlm.Vec2,
    fill_color: zlm.Vec4,
    border_color: zlm.Vec4,
    border_radius: f32,
    border_thickness: f32,
};

// TODO: maybe use quad_count instead of vertex_count and index_count, if we will render only quads

allocator: Allocator,
screen_size: zlm.Vec2,
vertices: []Vertex,
vertex_count: usize,
indices: []u32,
index_count: usize,
program: c_uint,
screen_size_uniform: c_int,
vao: c_uint,
vbo: c_uint,
ibo: c_uint,

pub fn init(allocator: Allocator, screen_size: zlm.Vec2) !Renderer {
    const vertices = try allocator.create([max_vertices]Vertex);
    const indices = try allocator.create([max_indices]u32);

    var i: usize = 0;
    var offset: u32 = 0;
    while (i < max_indices) : (i += 6) {
        indices[i + 0] = offset + 0;
        indices[i + 1] = offset + 1;
        indices[i + 2] = offset + 2;

        indices[i + 3] = offset + 2;
        indices[i + 4] = offset + 3;
        indices[i + 5] = offset + 0;

        offset += 4;
    }

    const program = create_program: {
        const vertex_shader_source = @embedFile(vertex_shader_path);
        const fragment_shader_source = @embedFile(fragment_shader_path);

        var success: c_int = undefined;
        var info_log_buf: [512:0]u8 = undefined;
        var info_log_length: c_int = 0;

        const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
        if (vertex_shader == 0) return error.ShaderCreateError;
        defer gl.DeleteShader(vertex_shader);

        gl.ShaderSource(
            vertex_shader,
            1,
            (&vertex_shader_source.ptr)[0..1],
            (&@as(c_int, @intCast(vertex_shader_source.len)))[0..1],
        );
        gl.CompileShader(vertex_shader);
        gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);
        if (success == gl.FALSE) {
            gl.GetShaderInfoLog(vertex_shader, info_log_buf.len, &info_log_length, &info_log_buf);
            log.err("Shader compile error: {s}", .{info_log_buf[0..@intCast(info_log_length)]});
            return error.ShaderCompileError;
        }

        const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
        if (fragment_shader == 0) return error.ShaderCreateError;
        defer gl.DeleteShader(fragment_shader);

        gl.ShaderSource(
            fragment_shader,
            1,
            (&fragment_shader_source.ptr)[0..1],
            (&@as(c_int, @intCast(fragment_shader_source.len)))[0..1],
        );
        gl.CompileShader(fragment_shader);
        gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success);
        if (success == gl.FALSE) {
            gl.GetShaderInfoLog(fragment_shader, info_log_buf.len, &info_log_length, &info_log_buf);
            log.err("Shader compile error: {s}", .{info_log_buf[0..@intCast(info_log_length)]});
            return error.ShaderCreateError;
        }

        const program = gl.CreateProgram();
        if (program == 0) return error.ProgramCreateError;
        errdefer gl.DeleteProgram(program);

        gl.AttachShader(program, vertex_shader);
        gl.AttachShader(program, fragment_shader);
        gl.LinkProgram(program);
        gl.GetProgramiv(program, gl.LINK_STATUS, &success);
        if (success == gl.FALSE) {
            gl.GetProgramInfoLog(program, info_log_buf.len, &info_log_length, &info_log_buf);
            log.err("Program link error: {s}", .{info_log_buf[0..@intCast(info_log_length)]});
            return error.ProgramLinkError;
        }

        break :create_program program;
    };

    const screen_size_uniform = gl.GetUniformLocation(program, "u_ScreenSize");

    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);

    var vbo: c_uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]);

    var ibo: c_uint = undefined;
    gl.GenBuffers(1, (&ibo)[0..1]);

    {
        gl.BindVertexArray(vao);
        defer gl.BindVertexArray(0);

        {
            gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
            defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

            gl.BufferData(
                gl.ARRAY_BUFFER,
                @sizeOf(Vertex) * max_vertices,
                null,
                gl.DYNAMIC_DRAW,
            );

            const position_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_Position"));
            gl.EnableVertexAttribArray(position_attrib);
            gl.VertexAttribPointer(
                position_attrib,
                2,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "position"),
            );

            const tex_coord_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_TexCoord"));
            gl.EnableVertexAttribArray(tex_coord_attrib);
            gl.VertexAttribPointer(
                tex_coord_attrib,
                2,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "tex_coord"),
            );

            const pixel_size_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_PixelSize"));
            gl.EnableVertexAttribArray(pixel_size_attrib);
            gl.VertexAttribPointer(
                pixel_size_attrib,
                2,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "pixel_size"),
            );

            const fill_color_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_FillColor"));
            gl.EnableVertexAttribArray(fill_color_attrib);
            gl.VertexAttribPointer(
                fill_color_attrib,
                4,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "fill_color"),
            );

            const border_color_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_BorderColor"));
            gl.EnableVertexAttribArray(border_color_attrib);
            gl.VertexAttribPointer(
                border_color_attrib,
                4,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "border_color"),
            );

            const border_radius_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_BorderRadius"));
            gl.EnableVertexAttribArray(border_radius_attrib);
            gl.VertexAttribPointer(
                border_radius_attrib,
                1,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "border_radius"),
            );

            const border_thickness_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_BorderThickness"));
            gl.EnableVertexAttribArray(border_thickness_attrib);
            gl.VertexAttribPointer(
                border_thickness_attrib,
                1,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "border_thickness"),
            );
        }

        {
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
            gl.BufferData(
                gl.ELEMENT_ARRAY_BUFFER,
                @sizeOf(u32) * max_indices,
                indices,
                gl.STATIC_DRAW,
            );
        }
    }

    return .{
        .allocator = allocator,
        .screen_size = screen_size,
        .vertices = vertices,
        .vertex_count = 0,
        .indices = indices,
        .index_count = 0,
        .program = program,
        .screen_size_uniform = screen_size_uniform,
        .vao = vao,
        .vbo = vbo,
        .ibo = ibo,
    };
}

pub fn deinit(renderer: *Renderer) void {
    gl.DeleteBuffers(1, (&renderer.vbo)[0..1]);
    gl.DeleteBuffers(1, (&renderer.ibo)[0..1]);
    gl.DeleteVertexArrays(1, (&renderer.vao)[0..1]);
    renderer.allocator.free(renderer.vertices);
    renderer.allocator.free(renderer.indices);
    gl.DeleteProgram(renderer.program);
}

pub fn render_quad(
    renderer: *Renderer,
    position: zlm.Vec2,
    size: zlm.Vec2,
    fill_color: zlm.Vec4,
    border_color: zlm.Vec4,
    border_radius: f32,
    border_thickness: f32,
) void {
    if (renderer.vertex_count + 4 > max_vertices) {
        renderer.flush();
    }

    for (0..4) |i| {
        renderer.vertices[renderer.vertex_count + i] = .{
            .position = position.add(size.mul(quad_tex_coords[i])),
            .tex_coord = quad_tex_coords[i],
            .pixel_size = size,
            .fill_color = fill_color,
            .border_color = border_color,
            .border_radius = border_radius,
            .border_thickness = border_thickness,
        };
    }

    renderer.vertex_count += 4;
    renderer.index_count += 6;
}

pub fn flush(renderer: *Renderer) void {
    if (renderer.index_count == 0) {
        return;
    }

    {
        gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

        gl.BufferSubData(
            gl.ARRAY_BUFFER,
            0,
            @sizeOf(Vertex) * @as(isize, @intCast(renderer.vertex_count)),
            renderer.vertices.ptr,
        );
    }

    gl.UseProgram(renderer.program);
    defer gl.UseProgram(0);

    gl.Uniform2f(renderer.screen_size_uniform, renderer.screen_size.x, renderer.screen_size.y);

    gl.BindVertexArray(renderer.vao);
    defer gl.BindVertexArray(0);

    gl.DrawElements(gl.TRIANGLES, @intCast(renderer.index_count), gl.UNSIGNED_INT, 0);

    renderer.vertex_count = 0;
    renderer.index_count = 0;
}
