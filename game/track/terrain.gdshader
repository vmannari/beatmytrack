shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform sampler2D surface_low : filter_linear, repeat_disable;
uniform sampler2D surface_high : filter_linear, repeat_disable;
uniform vec2 map_texel;
uniform vec4 color_0 : source_color;
uniform vec4 color_1 : source_color;
uniform vec4 color_2 : source_color;
uniform vec4 color_3 : source_color;
uniform vec4 color_4 : source_color;
uniform vec4 color_5 : source_color;
uniform vec4 color_6 : source_color;
uniform vec4 color_7 : source_color;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 low = texture(surface_low, UV);
	vec4 high = texture(surface_high, UV);
	float weights[8] = float[8](low.r,low.g,low.b,low.a,high.r,high.g,high.b,high.a);
	vec3 colors[8] = vec3[8](color_0.rgb,color_1.rgb,color_2.rgb,color_3.rgb,color_4.rgb,color_5.rgb,color_6.rgb,color_7.rgb);
	float best = -1.0;
	int kind = 0;
	for (int i = 0; i < 8; i++) {
		if (weights[i] > best) { best = weights[i]; kind = i; }
	}
	vec3 base = colors[kind];
	// Interpolated coverage gives crisp diagonal contours instead of blurring
	// the old cell colours. Only narrow curb edges receive muted safety paint.
	if (kind == 5) {
		float road = max(max(texture(surface_low,UV+map_texel*vec2(2.5,0)).r,
			texture(surface_low,UV-map_texel*vec2(2.5,0)).r),
			max(texture(surface_low,UV+map_texel*vec2(0,2.5)).r,
			texture(surface_low,UV-map_texel*vec2(0,2.5)).r));
		float stripe = mod(floor((world_position.x + world_position.z) * 0.8), 2.0);
		if (road > 0.5 && stripe < 1.0) { base *= vec3(0.68,0.36,0.29); }
	}
	// Quiet broad variation anchored to world metres. No imported art or shine.
	float broad = sin(world_position.x * 0.83 + sin(world_position.z * 0.47))
		* sin(world_position.z * 0.71 + world_position.x * 0.19);
	ALBEDO = base * (0.98 + broad * 0.025);
	ROUGHNESS = 1.0;
}
