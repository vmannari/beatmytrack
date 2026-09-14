shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
#include "res://track/surface_detail.gdshaderinc"
uniform bool water = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float grain = pigment(world_position.xz*2.0);
    ALBEDO = COLOR.rgb*(0.96+grain*0.08);
    if (water) {
        float ripple = smoothstep(0.73,0.84,pigment(world_position.xz*vec2(1.2,6.0)));
        ALBEDO += vec3(0.055)*ripple;
    }
    ROUGHNESS = 1.0;
}
