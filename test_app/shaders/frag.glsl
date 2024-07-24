#version 410 core

uniform vec2 u_ScreenSize;

in vec4 v_Color;
in vec2 v_TexCoord;
in float v_TexIndex;

out vec4 f_Color;

uniform sampler2D u_Textures[16];

void main() {
    f_Color = v_Color * texture(u_Textures[int(v_TexIndex)], v_TexCoord);
}
