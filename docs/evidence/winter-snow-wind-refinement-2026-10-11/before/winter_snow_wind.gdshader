shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform bool bank = false;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float strength = 0.0;
uniform vec3 focus;
uniform sampler2D powder_texture : filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
varying float life_alpha;
varying vec3 world_position;

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	float phase = fract(travel / (bank ? 7.5 : 9.0) + seed);
	life_alpha = smoothstep(0.0, 0.16, phase) * (1.0 - smoothstep(0.60, 1.0, phase));
	VERTEX.x += (phase - (bank ? 0.0 : 0.5)) * (bank ? 7.5 : 9.0);
	if (bank) {
		VERTEX.y = VERTEX.y * (0.45 + phase * 0.9) + 0.28 + phase * 0.40;
	} else {
		VERTEX.z += sin(elapsed * 1.3 + seed * 24.0) * 0.20;
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 edge = UV * (1.0 - UV);
	float shape = smoothstep(0.0, 0.12, edge.x) * smoothstep(0.0, 0.17, edge.y);
	float texture_alpha = texture(powder_texture, UV).a;
	float ribbons = bank ? 1.0 : 0.55 + 0.45 * sin(UV.y * 32.0 + UV.x * 6.0 + elapsed * 0.7);
	float distance_fade = 1.0 - smoothstep(23.0, 30.0, length(world_position.xz - focus.xz));
	// Soft opaque intersections (terrain/car), with renderer-correct depth reconstruction.
	float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float gap = -view.z / view.w + VERTEX.z;
	float intersection = smoothstep(0.0, bank ? 0.22 : 0.06, gap);
	ALBEDO = vec3(0.86, 0.93, 1.0);
	ALPHA = min(bank ? 0.19 : 0.32, (bank ? 0.19 : 0.32) * strength * life_alpha * shape * texture_alpha * ribbons * distance_fade * intersection);
}
