shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform bool bank = false;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float strength = 0.0;
uniform vec3 focus;
uniform sampler2D flow_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
varying float life_alpha;
varying vec3 world_position;
varying vec2 flow_offset;
varying float variation;
varying float density_height;

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	variation = INSTANCE_CUSTOM.y;
	flow_offset = vec2(seed * 3.71, variation * 2.13);
	float distance = bank ? 6.5 + variation * 2.0 : 9.0;
	float phase = fract(travel / distance + seed);
	life_alpha = smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.55, 1.0, phase));
	if (bank) {
		// Drawing proxy faces the camera; its centre travels in physical world wind.
		vec3 center = MODEL_MATRIX[3].xyz + vec3(0.91, 0.0, -0.414608) * phase * distance;
		center.y += 0.10 + phase * 0.30;
		density_height = center.y;
		VERTEX.xy *= 0.50 + phase * 1.05;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
		world_position = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	} else {
		VERTEX.x *= 0.72 + variation * 0.56;
		VERTEX.x += (phase - 0.5) * distance;
		VERTEX.z *= 0.68 + variation * 0.55;
		VERTEX.z += sin(elapsed * 0.8 + seed * 24.0) * 0.30;
		world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		density_height = world_position.y;
	}
}

void fragment() {
	// Baked multiscale density provides powder breakup, never repeated sine stripes.
	vec3 curl = texture(flow_texture, UV * 0.72 + flow_offset + vec2(-travel * 0.032, elapsed * 0.013)).rgb;
	vec2 flow_uv = UV * (bank ? vec2(0.8, 0.8) : vec2(0.68, 1.45)) + flow_offset;
	flow_uv += vec2(-travel * 0.065, (curl.g - 0.5) * 0.28);
	vec3 density = texture(flow_texture, flow_uv).rgb;
	vec2 p = UV * 2.0 - 1.0;
	p.y += (curl.g - 0.5) * (bank ? 0.12 : 0.38);
	float cross_fade = 1.0 - smoothstep(0.0, 1.0, abs(p.y));
	float ends = 1.0 - smoothstep(0.0, 1.0, abs(p.x));
	float envelope = bank ? 1.0 - smoothstep(0.0, 1.0, length(p)) : cross_fade * ends;
	float breakup = smoothstep(0.14, 0.85, density.r);
	float shape = envelope * breakup * mix(0.85, 1.0, density.b);
	// One of each source's three wisps is sparse granular powder, beneath
	// the two soft rolls. It adds snow detail without a third emitter batch.
	bool grains = bank && variation > 0.5;
	if (grains) shape *= smoothstep(0.59, 0.86, density.b);
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
	float intersection = smoothstep(0.0, bank ? 0.18 : 0.045, gap);
	if (bank) {
		vec4 opaque_world = INV_VIEW_MATRIX * view;
		intersection *= 1.0 - smoothstep(density_height, density_height + 0.10, opaque_world.y / opaque_world.w);
	}
	ALBEDO = mix(vec3(0.76, 0.85, 0.91), vec3(0.95, 0.98, 1.0), density.r);
	ALPHA = (bank ? (grains ? 0.72 : 0.34) : 0.52) * strength * life_alpha * shape * distance_fade * intersection;
}
