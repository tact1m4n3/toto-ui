const c = @import("c.zig").glfw;
const gl = @import("gl");

const Window = @This();

pub const FramebufferSize = struct {
    width: u32,
    height: u32,
};

pub const getProcAddress = c.glfwGetProcAddress;

inner: *c.struct_GLFWwindow,

pub fn init() !Window {
    if (c.glfwInit() == c.GLFW_FALSE) {
        return error.GlfwInitError;
    }
    errdefer _ = c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, gl.info.version_major);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, gl.info.version_minor);
    c.glfwWindowHint(c.GLFW_OPENGL_CORE_PROFILE, @intFromBool(gl.info.profile == .core));
    const inner = c.glfwCreateWindow(640, 480, "My Title", null, null) orelse {
        return error.WindowCreateError;
    };

    c.glfwMakeContextCurrent(inner);

    return .{
        .inner = inner,
    };
}

pub fn deinit(window: Window) void {
    c.glfwMakeContextCurrent(null);
    _ = c.glfwDestroyWindow(window.inner);
    _ = c.glfwTerminate();
}

pub fn pollEvents(_: Window) void {
    c.glfwPollEvents();
}

pub fn shouldClose(window: Window) bool {
    return c.glfwWindowShouldClose(window.inner) != 0;
}

pub fn swapBuffers(window: Window) void {
    c.glfwSwapBuffers(window.inner);
}

pub fn getFramebufferSize(window: Window) FramebufferSize {
    var width: c_int = undefined;
    var height: c_int = undefined;
    c.glfwGetFramebufferSize(window.inner, &width, &height);
    return .{ .width = @intCast(width), .height = @intCast(height) };
}
