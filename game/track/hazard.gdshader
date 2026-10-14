shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
#include "res://track/surface_detail.gdshaderinc"
uniform bool water = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float grain = pigment(world_position.xz*2.0);
    // Vertex pigments are authored in sRGB. Mobile lighting expects linear
    // albedo; Compatibility writes sRGB. Keep oil/rubber dark on both paths.
    vec3 pigment_color = COLOR.rgb;
    if (!OUTPUT_IS_SRGB) {
        pigment_color = mix(pigment_color/12.92,pow((pigment_color+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),pigment_color));
    }
    ALBEDO = pigment_color*(0.96+grain*0.08);
    if (water) {
        float ripple = smoothstep(0.73,0.84,pigment(world_position.xz*vec2(1.2,6.0)));
        ALBEDO += vec3(0.055)*ripple;
    }
    ROUGHNESS = 1.0;
}
