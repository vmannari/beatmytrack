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
varying float along_source;

void vertex() {
	variation = INSTANCE_CUSTOM.y;
	if (bank) {
		// The source stays on the visible crest while density flows downhill.
		VERTEX.x += 3.75;
		along_source = VERTEX.x;
		float drop = smoothstep(0.0, 2.0, along_source);
		float crest = MODEL_MATRIX[3].y;
		VERTEX.y = mix(0.0, 0.065 - crest, drop);
		VERTEX.y += sin(clamp(along_source / 7.5, 0.0, 1.0) * PI) * variation * 0.09;
		VERTEX.z += (variation - 0.3333) * 0.70;
		float u = clamp(along_source / 2.0, 0.0, 1.0);
		float slope = (0.065 - crest) * 3.0 * u * (1.0 - u);
		NORMAL = normalize(vec3(-slope, 1.0, 0.0));
	} else {
		along_source = 0.0;
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// One advected world field crosses card/source boundaries continuously.
	vec2 wind = vec2(0.91, -0.414608);
	vec2 side = vec2(-wind.y, wind.x);
	vec2 field = vec2(dot(world_position.xz, wind) - travel, dot(world_position.xz, side));
	vec3 curl = texture(flow_texture, field * vec2(0.027, 0.060)).rgb;
	vec2 flow_uv = field * vec2(0.052, 0.155) + vec2(0.0, (curl.g - 0.5) * 0.30);
	vec3 density = texture(flow_texture, flow_uv).rgb;
	vec2 p = UV * 2.0 - 1.0;
	float cross_fade = 1.0 - smoothstep(0.12, 1.0, abs(p.y));
	float ends = bank ? 1.0 - smoothstep(3.0, 7.5, along_source) : 1.0 - smoothstep(0.1, 1.0, abs(p.x));
	float breakup = smoothstep(0.20, 0.82, density.r);
	float shape = cross_fade * ends * breakup;
	bool grains = bank && variation > 0.5;
	if (grains) shape *= smoothstep(0.58, 0.85, density.b);
	else shape *= mix(0.86, 1.0, density.b);
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
	float intersection = smoothstep(0.0, bank ? 0.10 : 0.03, gap);
	// Share the snowbanks' colour and actual directional/ambient/shadow light.
	vec3 snow = texture(snow_albedo, world_position.xz / 11.0).rgb;
	ALBEDO = snow * mix(0.70, 0.83, density.r);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float opacity = bank ? (grains ? 0.34 : mix(0.30, 0.16, variation)) : 0.28;
	ALPHA = opacity * strength * shape * distance_fade * intersection;
}
