#version 410 core

// uniform vec2 u_FramebufferSize;

in vec2 a_Position;
in vec4 a_Color;

out vec4 v_Color;

void main() {
    gl_Position = vec4(a_Position, 0.0, 1.0);
    v_Color = a_Color;
}
