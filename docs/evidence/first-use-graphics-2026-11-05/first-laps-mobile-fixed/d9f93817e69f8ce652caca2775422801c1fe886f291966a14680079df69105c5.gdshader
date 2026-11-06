shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, depth_draw_never, depth_test_disabled;
#include "res://track/shadow_depth.gdshaderinc"
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
uniform float strength = 0.27;
varying mat4 world_to_volume;
void vertex() {
	world_to_volume = inverse(MODEL_MATRIX);
}
void fragment() {
	vec3 world = shadow_world_position(depth_map, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 p = (world_to_volume * vec4(world, 1.0)).xyz;
	if (any(greaterThan(abs(p), vec3(0.5)))) { discard; }
	float radius = length(p.xz * 2.0);
	float feather = 1.0 - smoothstep(0.25, 1.0, radius);
	float core = 1.0 - smoothstep(0.0, 0.72, radius);
	float height_fade = 1.0 - smoothstep(0.0, 0.5, p.y);
	ALBEDO = vec3(0.025, 0.032, 0.038);
	ALPHA = strength * (feather * 0.65 + core * 0.35) * height_fade;
}
