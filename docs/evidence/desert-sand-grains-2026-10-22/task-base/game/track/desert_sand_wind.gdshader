shader_type spatial;
render_mode diffuse_lambert, specular_disabled, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D flow_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float strength = 0.0;
uniform vec3 focus;
varying vec3 world_position;
varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	float u = clamp((VERTEX.x + 4.0) / 8.0, 0.0, 1.0);
	// A seated windward foot lifts into an uneven, shallow downwind veil.
	float phase = seed * 6.283185;
	float gust = 0.76 + 0.24 * sin(elapsed * 0.73 + phase);
	float lift = sin(u * PI) * (0.46 + INSTANCE_CUSTOM.y * 0.62) * gust;
	VERTEX.y += lift;
	VERTEX.z *= mix(0.52, 1.0, u);
	VERTEX.z += sin(u * PI) * (0.20 * sin(elapsed * 0.65 + phase + u * 3.0));
	NORMAL = normalize(vec3(-cos(u * PI) * (0.46 + INSTANCE_CUSTOM.y * 0.62) * gust * PI / 8.0, 1.0, 0.0));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (strength <= 0.0) discard;
	float distance_fade = 1.0 - smoothstep(16.0, 19.0, length(world_position.xz - focus.xz));
	if (distance_fade <= 0.0) discard;
	vec2 wind = normalize(vec2(0.91, -0.414608));
	vec2 side = vec2(-wind.y, wind.x);
	vec2 p = vec2(dot(world_position.xz, wind), dot(world_position.xz, side));
	vec2 moving = p - vec2(travel, 0.0);
	vec3 broad = texture(flow_texture, moving * vec2(0.055, 0.14)).rgb;
	vec3 detail = texture(flow_texture, moving * vec2(0.16, 0.80) + vec2(0.0, (broad.g - 0.5) * 0.45)).rgb;
	float edge = abs(UV.y * 2.0 - 1.0 + (broad.g - 0.5) * 0.50);
	float sides = 1.0 - smoothstep(0.20, 1.0, edge);
	float ends = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.48, 1.0, UV.x));
	float fingers = smoothstep(0.24, 0.68, detail.r);
	float grains = smoothstep(0.30 - fwidth(detail.b), 0.72 + fwidth(detail.b), detail.b);
	float local_gust = 0.64 + 0.36 * sin(elapsed * 0.53 + seed * 6.283185 + broad.r * 2.0);
	float shape = sides * ends * fingers * mix(0.35, 1.0, grains) * local_gust;
	if (shape <= 0.002) discard;
	// Fade against opaque sand, cars and props with both depth conventions.
	float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float gap = -view.z / view.w + VERTEX.z;
	float intersection = smoothstep(0.0, 0.12, gap);
	vec4 opaque_world = INV_VIEW_MATRIX * view;
	intersection *= 1.0 - smoothstep(world_position.y, world_position.y + 0.05, opaque_world.y / opaque_world.w);
	ALBEDO = mix(vec3(0.82, 0.67, 0.45), vec3(0.96, 0.84, 0.63), broad.r);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = min(0.82 * strength * shape * distance_fade * intersection, 0.48);
}
