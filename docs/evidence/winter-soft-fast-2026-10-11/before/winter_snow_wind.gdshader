shader_type spatial;
render_mode diffuse_lambert, specular_disabled, blend_mix, depth_draw_never, cull_disabled;
uniform bool bank = false;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float strength = 0.0;
uniform vec3 focus;
uniform sampler2D flow_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
varying vec3 world_position;
varying float variation;
varying float life_alpha;

void vertex() {
	variation = INSTANCE_CUSTOM.y;
	float seed = INSTANCE_CUSTOM.x;
	float spread = INSTANCE_CUSTOM.z;
	float distance = bank ? 5.5 + variation * 2.0 : 9.0;
	float phase = fract(travel / distance * (0.85 + variation * 0.30) + seed);
	life_alpha = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.68, 1.0, phase));
	VERTEX.xz *= 0.65 + variation * 0.85;
	VERTEX.x *= mix(1.0, bank ? 1.8 : 2.2, strength);
	if (bank) {
		// Each mote leaves a visible bank, lifts briefly, then skims the road.
		float along_source = phase * distance;
		VERTEX.x += along_source;
		float drop = smoothstep(0.0, 2.0, along_source);
		float crest = MODEL_MATRIX[3].y;
		VERTEX.y = mix(0.0, 0.065 - crest, drop);
		VERTEX.y += sin(phase * PI) * (0.06 + spread * 0.12);
		VERTEX.z += (spread - 0.5) * (0.35 + phase * 1.4);
	} else {
		VERTEX.x += (phase - 0.5) * distance;
		VERTEX.z += sin(elapsed * 1.4 + seed * 19.0) * (0.06 + spread * 0.12);
		VERTEX.y += sin(phase * PI) * 0.025;
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Sparse grain clusters share one advected wind field; no cloud coverage.
	vec2 wind = vec2(0.91, -0.414608);
	vec2 side = vec2(-wind.y, wind.x);
	vec2 field = vec2(dot(world_position.xz, wind) - travel, dot(world_position.xz, side));
	vec3 density = texture(flow_texture, field * vec2(0.045, 0.12)).rgb;
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float edge = max(fwidth(radius), 0.10);
	float shape = 1.0 - smoothstep(0.60 - edge, 1.0 + edge, radius);
	float cluster = mix(0.30, 1.0, smoothstep(0.28, 0.74, density.r));
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
	float intersection = smoothstep(0.0, bank ? 0.06 : 0.025, gap);
	// Share the snowbanks' colour and actual directional/ambient/shadow light.
	vec3 snow = texture(snow_albedo, world_position.xz / 11.0).rgb;
	ALBEDO = snow * mix(0.86, 0.97, variation);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float opacity = bank ? 0.76 : 0.58;
	ALPHA = opacity * strength * life_alpha * shape * cluster * distance_fade * intersection;
}
