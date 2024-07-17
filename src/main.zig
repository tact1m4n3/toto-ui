const std = @import("std");
const gl = @import("gl");

const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");

var gl_procs: gl.ProcTable = undefined;

const hexagon_mesh = struct {
    // zig fmt: off
    const vertices = [_]Vertex{
        .{ .position = .{  0    , -1   }, .color = .{ 0, 1, 1 } },
        .{ .position = .{ -0.866, -0.5 }, .color = .{ 0, 0, 1 } },
        .{ .position = .{  0.866, -0.5 }, .color = .{ 0, 1, 0 } },
        .{ .position = .{ -0.866,  0.5 }, .color = .{ 1, 0, 1 } },
        .{ .position = .{  0.866,  0.5 }, .color = .{ 1, 1, 0 } },
        .{ .position = .{  0    ,  1   }, .color = .{ 1, 0, 0 } },
    };
    // zig fmt: on

    const indices = [_]u8{
        0, 3, 1,
        0, 4, 3,
        0, 2, 4,
        3, 4, 5,
    };

    const Vertex = extern struct {
        position: Position,
        color: Color,

        const Position = [2]f32;
        const Color = [3]f32;
    };
};

pub fn main() !void {
    const window = try Window.init();
    defer window.deinit();

    if (!gl_procs.init(Window.getProcAddress)) {
        return error.OpenGlLoadError;
    }

    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    var renderer = try Renderer.init();
    defer renderer.deinit();

    const vertex_shader_source: [:0]const u8 =
        \\#version 410 core
        \\
        \\// Width/height of the framebuffer (= the window).
        \\uniform vec2 u_FramebufferSize;
        \\
        \\// Angle of the object we're drawing, in radians.
        \\uniform float u_Angle;
        \\
        \\// Vertex position and color as defined in the mesh.
        \\in vec4 a_Position;
        \\in vec4 a_Color;
        \\
        \\// Color result that will be passed to the fragment shader.
        \\out vec4 v_Color;
        \\
        \\void main() {
        \\    // Account for the window's aspect ratio. We want a 1:1 width/height ratio.
        \\    float scaleX = min(u_FramebufferSize.y / u_FramebufferSize.x, 1);
        \\    float scaleY = min(u_FramebufferSize.x / u_FramebufferSize.y, 1);
        \\
        \\    float s = sin(u_Angle);
        \\    float c = cos(u_Angle);
        \\
        \\    gl_Position = vec4(
        \\        (a_Position.x * c + a_Position.y * -s) * scaleX,
        \\        (a_Position.x * s + a_Position.y * c) * scaleY,
        \\        a_Position.zw
        \\    ) * vec4(0.875, 0.875, 1, 1); // Shrink the object slightly to fit the window.
        \\
        \\    // Pass the vertex's color to the fragment shader.
        \\    v_Color = a_Color;
        \\}
        \\
    ;
    const fragment_shader_source: [:0]const u8 =
        \\#version 410 core
        \\
        \\// Color input from the vertex shader.
        \\in vec4 v_Color;
        \\
        \\// Fragment shaders must return an output.
        \\out vec4 f_Color;
        \\
        \\void main() {
        \\    f_Color = v_Color;
        \\}
        \\
    ;

    const program = create_program: {
        var success: c_int = undefined;
        var info_log_buf: [512:0]u8 = undefined;

        const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
        if (vertex_shader == 0) return error.CreateVertexShaderFailed;
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
            gl.GetShaderInfoLog(vertex_shader, info_log_buf.len, null, &info_log_buf);
            return error.CompileVertexShaderFailed;
        }

        const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
        if (fragment_shader == 0) return error.CreateFragmentShaderFailed;
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
            gl.GetShaderInfoLog(fragment_shader, info_log_buf.len, null, &info_log_buf);
            return error.CompileFragmentShaderFailed;
        }

        const program = gl.CreateProgram();
        if (program == 0) return error.CreateProgramFailed;
        errdefer gl.DeleteProgram(program);

        gl.AttachShader(program, vertex_shader);
        gl.AttachShader(program, fragment_shader);
        gl.LinkProgram(program);
        gl.GetProgramiv(program, gl.LINK_STATUS, &success);
        if (success == gl.FALSE) {
            gl.GetProgramInfoLog(program, info_log_buf.len, null, &info_log_buf);
            return error.LinkProgramFailed;
        }

        break :create_program program;
    };
    defer gl.DeleteProgram(program);

    const framebuffer_size_uniform = gl.GetUniformLocation(program, "u_FramebufferSize");
    const angle_uniform = gl.GetUniformLocation(program, "u_Angle");

    // Vertex Array Object (VAO), remembers instructions for how vertex data is laid out in memory.
    // Using VAOs is strictly required in modern OpenGL.
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    defer gl.DeleteVertexArrays(1, (&vao)[0..1]);

    // Vertex Buffer Object (VBO), holds vertex data.
    var vbo: c_uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]);
    defer gl.DeleteBuffers(1, (&vbo)[0..1]);

    // Index Buffer Object (IBO), maps indices to vertices (to enable reusing vertices).
    var ibo: c_uint = undefined;
    gl.GenBuffers(1, (&ibo)[0..1]);
    defer gl.DeleteBuffers(1, (&ibo)[0..1]);

    {
        // Make our VAO the current global VAO, but unbind it when we're done so we don't end up
        // inadvertently modifying it later.
        gl.BindVertexArray(vao);
        defer gl.BindVertexArray(0);

        {
            // Make our VBO the current global VBO and unbind it when we're done.
            gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
            defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

            // Upload vertex data to the VBO.
            gl.BufferData(
                gl.ARRAY_BUFFER,
                @sizeOf(@TypeOf(hexagon_mesh.vertices)),
                &hexagon_mesh.vertices,
                gl.STATIC_DRAW,
            );

            // Instruct the VAO how vertex position data is laid out in memory.
            const position_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_Position"));
            gl.EnableVertexAttribArray(position_attrib);
            gl.VertexAttribPointer(
                position_attrib,
                @typeInfo(hexagon_mesh.Vertex.Position).Array.len,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(hexagon_mesh.Vertex),
                @offsetOf(hexagon_mesh.Vertex, "position"),
            );

            // Ditto for vertex colors.
            const color_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_Color"));
            gl.EnableVertexAttribArray(color_attrib);
            gl.VertexAttribPointer(
                color_attrib,
                @typeInfo(hexagon_mesh.Vertex.Color).Array.len,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(hexagon_mesh.Vertex),
                @offsetOf(hexagon_mesh.Vertex, "color"),
            );
        }

        // Instruct the VAO to use our IBO, then upload index data to the IBO.
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
        gl.BufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            @sizeOf(@TypeOf(hexagon_mesh.indices)),
            &hexagon_mesh.indices,
            gl.STATIC_DRAW,
        );
    }

    var timer = try std.time.Timer.start();

    while (true) {
        window.pollEvents();

        if (window.shouldClose()) break;

        {
            gl.ClearColor(1, 1, 1, 1);
            gl.Clear(gl.COLOR_BUFFER_BIT);

            gl.UseProgram(program);
            defer gl.UseProgram(0);

            // Make sure any changes to the window's size are reflected.
            const framebuffer_size = window.getFramebufferSize();
            gl.Viewport(0, 0, @intCast(framebuffer_size.width), @intCast(framebuffer_size.height));
            gl.Uniform2f(framebuffer_size_uniform, @floatFromInt(framebuffer_size.width), @floatFromInt(framebuffer_size.height));

            // Rotate the hexagon clockwise at a rate of one complete turn per minute.
            const seconds = @as(f32, @floatFromInt(timer.read())) / std.time.ns_per_s;
            gl.Uniform1f(angle_uniform, seconds / 60 * -std.math.tau);

            gl.BindVertexArray(vao);
            defer gl.BindVertexArray(0);

            // Draw the hexagon!
            gl.DrawElements(gl.TRIANGLES, hexagon_mesh.indices.len, gl.UNSIGNED_BYTE, 0);
        }

        window.swapBuffers();
    }
}
