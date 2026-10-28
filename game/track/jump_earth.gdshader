shader_type spatial;
render_mode diffuse_burley, specular_disabled, depth_prepass_alpha;
#include "res://track/surface_detail.gdshaderinc"
uniform vec4 earth_color : source_color = vec4(0.54,0.45,0.31,1.0);
uniform bool sand_profile = false;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    // Same sand pigment and baked compacted-road grain as the receiving road.
    ALBEDO = sand_profile ? compacted_road(earth_color.rgb,world_position.xz) : earth_color.rgb*(0.985+pigment(world_position.xz*1.8)*0.03);
    // Zero-height perimeter fades into the actual road instead of leaving a
    // rectangular sheet. The profile's position and normals remain geometric.
    ALPHA = COLOR.a;
    ROUGHNESS = 1.0;
}
