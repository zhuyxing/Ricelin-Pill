#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accent;
    float tint;
    float darken;
};
layout(binding = 1) uniform sampler2D source;

const vec3 L = vec3(0.299, 0.587, 0.114);

void main() {
    vec3 rgb = texture(source, qt_TexCoord0).rgb;
    float lum = dot(rgb, L);
    vec3 gray = vec3(lum);
    vec3 chroma = accent.rgb - vec3(dot(accent.rgb, L));
    vec3 tinted = gray + chroma * tint * (0.45 + lum);

    vec2 d = qt_TexCoord0 - vec2(0.5);
    float vig = smoothstep(0.85, 0.35, length(d));
    vec3 outc = tinted * darken * mix(0.72, 1.0, vig);

    fragColor = vec4(outc, 1.0) * qt_Opacity;
}
