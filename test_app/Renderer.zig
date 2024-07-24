const std = @import("std");
const Allocator = std.mem.Allocator;
const zlm = @import("zlm");
const gl = @import("gl");

const toto_ui = @import("toto-ui");
const Vertex = toto_ui.draw.Vertex;
const RenderPass = toto_ui.draw.RenderPass;

const Renderer = @This();

const log = std.log.scoped(.renderer);

const vertex_shader_path = "shaders/vert.glsl";
const fragment_shader_path = "shaders/frag.glsl";

const quad_tex_coords = [_]zlm.Vec2{
    .{ .x = 0.0, .y = 0.0 },
    .{ .x = 1.0, .y = 0.0 },
    .{ .x = 1.0, .y = 1.0 },
    .{ .x = 0.0, .y = 1.0 },
};

// TODO: maybe use quad_count instead of vertex_count and index_count, if we will render only quads

screen_size: zlm.Vec2,
program: c_uint,
proj_matrix: zlm.Mat4,
proj_matrix_uniform: c_int,
vertex_array: c_uint,
vertex_buffer: c_uint,
vertex_buffer_size: usize = 0,
index_buffer: c_uint,
index_buffer_size: usize = 0,

pub fn init(screen_size: zlm.Vec2) !Renderer {
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

    const proj_matrix = zlm.Mat4.createOrthogonal(0, screen_size.x, screen_size.y, 0, -1, 1);
    const proj_matrix_uniform = gl.GetUniformLocation(program, "u_ProjMatrix");

    {
        gl.UseProgram(program);
        defer gl.UseProgram(0);

        gl.UniformMatrix4fv(proj_matrix_uniform, 1, gl.FALSE, @alignCast(@ptrCast(&proj_matrix.fields)));
    }

    var vertex_array: c_uint = undefined;
    gl.GenVertexArrays(1, (&vertex_array)[0..1]);

    var vertex_buffer: c_uint = undefined;
    gl.GenBuffers(1, (&vertex_buffer)[0..1]);

    var index_buffer: c_uint = undefined;
    gl.GenBuffers(1, (&index_buffer)[0..1]);

    {
        gl.BindVertexArray(vertex_array);
        defer gl.BindVertexArray(0);

        {
            gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
            defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

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

            const color_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_Color"));
            gl.EnableVertexAttribArray(color_attrib);
            gl.VertexAttribPointer(
                color_attrib,
                4,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "color"),
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

            const tex_index_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_TexIndex"));
            gl.EnableVertexAttribArray(tex_index_attrib);
            gl.VertexAttribPointer(
                tex_index_attrib,
                1,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(Vertex),
                @offsetOf(Vertex, "tex_index"),
            );
        }

        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, index_buffer);
    }

    return .{
        .screen_size = screen_size,
        .program = program,
        .proj_matrix = proj_matrix,
        .proj_matrix_uniform = proj_matrix_uniform,
        .vertex_array = vertex_array,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
    };
}

pub fn deinit(renderer: *Renderer) void {
    gl.DeleteBuffers(1, (&renderer.vertex_buffer)[0..1]);
    gl.DeleteBuffers(1, (&renderer.index_buffer)[0..1]);
    gl.DeleteVertexArrays(1, (&renderer.vertex_array)[0..1]);
    gl.DeleteProgram(renderer.program);
}

pub fn submit(renderer: *Renderer, pass: RenderPass) void {
    {
        const required_size = @sizeOf(Vertex) * pass.vertices.items.len;

        gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vertex_buffer);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

        if (required_size > renderer.vertex_buffer_size) {
            gl.BufferData(
                gl.ARRAY_BUFFER,
                @intCast(required_size),
                pass.vertices.items.ptr,
                gl.DYNAMIC_DRAW,
            );
            renderer.vertex_buffer_size = required_size;
        } else {
            gl.BufferSubData(
                gl.ARRAY_BUFFER,
                0,
                @intCast(required_size),
                pass.vertices.items.ptr,
            );
        }
    }

    {
        const required_size = @sizeOf(u32) * pass.indices.items.len;

        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, renderer.index_buffer);
        defer gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        if (required_size > renderer.index_buffer_size) {
            gl.BufferData(
                gl.ELEMENT_ARRAY_BUFFER,
                @intCast(required_size),
                pass.indices.items.ptr,
                gl.DYNAMIC_DRAW,
            );
            renderer.index_buffer_size = required_size;
        } else {
            gl.BufferSubData(
                gl.ELEMENT_ARRAY_BUFFER,
                0,
                @intCast(required_size),
                pass.indices.items.ptr,
            );
        }
    }

    gl.UseProgram(renderer.program);
    defer gl.UseProgram(0);

    gl.BindVertexArray(renderer.vertex_array);
    defer gl.BindVertexArray(0);

    for (pass.textures.constSlice(), 0..pass.textures.len) |texture, i| {
        gl.ActiveTexture(gl.TEXTURE0 + @as(c_uint, @intCast(i)));
        gl.BindTexture(gl.TEXTURE_2D, @intCast(texture));
    }

    gl.DrawElements(gl.TRIANGLES, @intCast(pass.indices.items.len), gl.UNSIGNED_INT, 0);
}
