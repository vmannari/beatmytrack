shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
#include "res://track/shadow_depth.gdshaderinc"
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
uniform float elapsed = 0.0;
uniform float strength = 0.43;
uniform float sunlight_strength = 0.42;
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
	// Smaller cloud footprints leave more full sunlight between soft penumbrae.
	// Keep the accepted slow 0.30 m/s world-space drift.
	vec2 p = (world.xz + vec2(13.0, 27.0) - vec2(0.28, 0.105)*elapsed) / 26.0;
	float mask = smoothstep(0.50, 0.70, cloud_noise(p)*0.85 + cloud_noise(p*2.03+7.1)*0.15);
	// Project the existing (-58, -35 degree) sun into the current camera.
	// A bounded warm veil shares this pass, depth read and cloud mask.
	vec3 sun_view = mat3(VIEW_MATRIX) * vec3(-0.304, 0.848, 0.434);
	vec2 sun_screen = vec2(sun_view.x, -sun_view.y);
	sun_screen /= max(length(sun_screen), 0.001);
	vec2 offset = SCREEN_UV - (vec2(0.5) + sun_screen * 0.48);
	offset.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float haze = 1.0 - smoothstep(0.08, 1.55, length(offset));
	float warm_alpha = sunlight_strength * haze * (1.0 - mask);
	float shade_alpha = strength * mask;
	float combined_alpha = shade_alpha + warm_alpha * (1.0 - shade_alpha);
	ALBEDO = (vec3(0.018, 0.028, 0.032) * shade_alpha +
		vec3(1.0, 0.78, 0.43) * warm_alpha * (1.0 - shade_alpha)) / max(combined_alpha, 0.00001);
	ALPHA = combined_alpha;
}
