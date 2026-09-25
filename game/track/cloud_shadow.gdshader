shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
#include "res://track/shadow_depth.gdshaderinc"
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
uniform float elapsed = 0.0;
uniform float strength = 0.085;
float cloud_hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x+p.y)*p.x);
}
float cloud_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(cloud_hash(cell), cloud_hash(cell+vec2(1.0,0.0)), f.x),
		mix(cloud_hash(cell+vec2(0.0,1.0)), cloud_hash(cell+vec2(1.0,1.0)), f.x), f.y);
}
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	vec3 world = shadow_world_position(depth_map, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	// Broad 32 m patches drift at 0.45 m/s, anchored to the world, not camera yaw.
	vec2 p = (world.xz + vec2(13.0, 27.0) - vec2(0.42, 0.16)*elapsed) / 32.0;
	float mask = smoothstep(0.28, 0.78, cloud_noise(p)*0.8 + cloud_noise(p*2.03+7.1)*0.2);
	ALBEDO = vec3(0.025, 0.035, 0.05);
	ALPHA = strength * mask;
}
