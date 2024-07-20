#version 410 core

uniform vec2 u_ScreenSize;

in vec2 a_Position;
in vec2 a_TexCoord;
in vec2 a_PixelSize;
in vec4 a_FillColor;
in vec4 a_BorderColor;
in float a_BorderRadius;
in float a_BorderThickness;

out vec2 v_TexCoord;
out vec2 v_PixelSize;
out vec4 v_FillColor;
out vec4 v_BorderColor;
out float v_BorderRadius;
out float v_BorderThickness;

void main() {
    gl_Position = vec4(a_Position / u_ScreenSize * 2 - 1, 0, 1);
    v_TexCoord = a_TexCoord;
    v_PixelSize = a_PixelSize;
    v_FillColor = a_FillColor;
    v_BorderColor = a_BorderColor;
    v_BorderRadius = a_BorderRadius;
    v_BorderThickness = a_BorderThickness;
}
