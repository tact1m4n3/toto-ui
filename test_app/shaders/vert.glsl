#version 410 core

uniform mat4 u_ProjMatrix;

in vec2 a_Position;
in vec4 a_Color;
in vec2 a_TexCoord;
in float a_TexIndex;

out vec4 v_Color;
out vec2 v_TexCoord;
out float v_TexIndex;

void main() {
    gl_Position = u_ProjMatrix * vec4(a_Position, 0, 1);
    v_Color = a_Color;
    v_TexCoord = a_TexCoord;
    v_TexIndex = a_TexIndex;
}
