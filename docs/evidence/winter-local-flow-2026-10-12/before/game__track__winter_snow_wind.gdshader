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
		VERTEX.x += 6.0;
		along_source = VERTEX.x;
		float drop = smoothstep(0.0, 3.5, along_source);
		float crest = MODEL_MATRIX[3].y;
		float settled = 0.065;
		float bend = clamp(along_source / 6.0, 0.0, 1.0) * PI;
		float loft = variation * 0.30 * (0.70 + 0.30 * sin(elapsed * 1.1 + variation * 7.0));
		VERTEX.y = mix(0.0, settled - crest, drop) + sin(bend) * loft;
		VERTEX.z += (variation - 0.3333) * 1.0;
		float u = clamp(along_source / 3.5, 0.0, 1.0);
		float loft_slope = along_source < 6.0 ? cos(bend) * loft * (PI / 6.0) : 0.0;
		float slope = (settled - crest) * (6.0 / 3.5) * u * (1.0 - u) + loft_slope;
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
	// Reference-led anisotropy: long branching fingers, not round FBM clouds.
	vec3 curl = texture(flow_texture, field * vec2(0.045, 0.09)).rgb;
	vec2 flow_uv = field * vec2(0.052, 0.38) + vec2(0.0, (curl.g - 0.5) * 0.25);
	vec3 density = texture(flow_texture, flow_uv).rgb;
	vec2 p = UV * 2.0 - 1.0;
	float cross_fade = 1.0 - smoothstep(0.12, 1.0, abs(p.y + (curl.g - 0.5) * 0.45));
	float ends = bank ? 1.0 - smoothstep(4.0, 12.0, along_source) : 1.0 - smoothstep(0.1, 1.0, abs(p.x));
	float fingers = smoothstep(0.48, 0.82, density.r);
	float lifted = smoothstep(0.23, 0.75, density.r);
	float source = bank ? (1.0 - smoothstep(1.0, 6.0, along_source)) * (1.0 - variation) : 0.0;
	float birth = bank ? smoothstep(0.0, 0.9, along_source) : 1.0;
	float shape = cross_fade * ends * birth * mix(fingers, lifted, source);
	shape *= mix(0.50, 1.0, density.b);
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
	// Conservative solid-height guard also handles partially resolved depth
	// at car/bridge edges while letting lifted powder remain over lower snow.
	vec4 opaque_world = INV_VIEW_MATRIX * view;
	intersection *= 1.0 - smoothstep(world_position.y, world_position.y + 0.045, opaque_world.y / opaque_world.w);
	// Share the snowbanks' colour and actual directional/ambient/shadow light.
	float snow_grain = texture(snow_albedo, world_position.xz / 11.0,2.0).r;
	ALBEDO = (vec3(0.65,0.71,0.79)+(snow_grain-0.5)*0.07)*mix(0.85,1.0,density.r);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float opacity = bank ? 0.29 + source * 0.14 : 0.25;
	ALPHA = opacity * strength * shape * distance_fade * intersection;
}
