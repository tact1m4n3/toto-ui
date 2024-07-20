#version 410 core

uniform vec2 u_ScreenSize;

in vec2 v_TexCoord;
in vec2 v_PixelSize;
in vec4 v_FillColor;
in vec4 v_BorderColor;
in float v_BorderRadius;
in float v_BorderThickness;

out vec4 f_Color;

// from https://iquilezles.org/articles/distfunctions
float roundedBoxSDF(vec2 position, vec2 size, float radius) {
    return length(max(abs(position)-size+radius,0.0))-radius;
}

void main() {
    vec2 position = v_TexCoord * v_PixelSize - v_PixelSize / 2;
    float distance = roundedBoxSDF(position, v_PixelSize / 2 - v_BorderThickness / 2 - 1.0, v_BorderRadius);
    float blend = smoothstep(-1.0, 1.0, abs(distance) - v_BorderThickness / 2); // antialiasing
    vec4 v4FromColor = v_BorderColor;
    vec4 v4ToColor = (distance < 0.0) ? v_FillColor : vec4(0.0);
    f_Color = mix(v4FromColor, v4ToColor, blend);
}
