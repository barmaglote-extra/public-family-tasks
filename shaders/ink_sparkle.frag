// shaders/ink_sparkle.frag
#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float time;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / resolution;
    vec3 color = 0.5 + 0.5 * cos(time + uv.xyx + vec3(0, 2, 4));
    fragColor = vec4(color, 1.0);
}