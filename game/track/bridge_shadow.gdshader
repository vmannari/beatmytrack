shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, depth_draw_never, depth_test_disabled;
#include "res://track/shadow_depth.gdshaderinc"
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
uniform float span_length = 32.0;
uniform float span_width = 10.0;
uniform float bridge_height = 3.5;
uniform float ramp_length = 8.0;
uniform float strength = 0.20;
varying mat4 world_to_volume;
void vertex() {
	world_to_volume = inverse(MODEL_MATRIX);
}
void fragment() {
	vec3 world = shadow_world_position(depth_map, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 p = (world_to_volume * vec4(world, 1.0)).xyz;
	float u = p.x + span_length * 0.5;
	float edge = span_width * 0.5 + 0.75 - abs(p.z);
	if (u < 0.0 || u > span_length || edge < -0.85 || world.y < -0.12) { discard; }
	float deck = bridge_height * min(smoothstep(0.0, ramp_length, u), 1.0 - smoothstep(span_length-ramp_length, span_length, u));
	// Upper surfaces and cars on the deck must never enter the under-shadow.
	float below = deck - 0.42 - world.y;
	if (below <= 0.0) { discard; }
	float feather = smoothstep(-0.85, 0.65, edge) * smoothstep(0.0, 0.35, below);
	feather *= smoothstep(0.3, 2.0, min(u, span_length-u));
	ALBEDO = vec3(0.025, 0.032, 0.045);
	ALPHA = strength * feather;
}
