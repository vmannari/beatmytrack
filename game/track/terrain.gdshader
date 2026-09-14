shader_type spatial;
render_mode diffuse_toon, specular_disabled;
#include "res://track/surface_detail.gdshaderinc"

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
	// Reconstruct the native material boundaries from coverage. Palette and
	// shading are cosmetic; native cells remain the sole surface authority.
	float boundary = 1.0 - smoothstep(0.51, 0.69, best);
	base *= 1.0 - boundary * 0.12;
	// Curb paint follows the supplied curb surface near asphalt. Broader paved
	// areas remain concrete, and no road width / lane marking is invented.
	if (kind == 5) {
		float road = max(max(texture(surface_low,UV+map_texel*vec2(2.5,0)).r,
			texture(surface_low,UV-map_texel*vec2(2.5,0)).r),
			max(texture(surface_low,UV+map_texel*vec2(0,2.5)).r,
			texture(surface_low,UV-map_texel*vec2(0,2.5)).r));
		float stripe = mod(floor((world_position.x + world_position.z) * 0.8), 2.0);
		if (road > 0.5 && stripe < 1.0) { base *= vec3(0.69,0.40,0.32); }
	}
	if (kind == 3 || kind == 6) {
		// Quiet horizontal water bands and a thin shoreline highlight.
		float band = step(0.82, sin(world_position.z * 0.52 + sin(world_position.x * 0.18) * 0.4));
		base *= 0.98 + band * 0.045;
		float shoal = pigment(world_position.xz * 0.35);
		base = mix(base * 0.88, color_6.rgb * 1.15, shoal * 0.22 + boundary * 0.6);
		float ripple = smoothstep(0.92, 1.0, sin(world_position.z * 7.0 + pigment(world_position.xz * 0.7) * 5.0));
		base += vec3(0.025,0.035,0.035) * ripple * (1.0 - smoothstep(0.08,0.3,length(fwidth(world_position.xz))));
	}
	if (kind == 0 || kind == 1 || kind == 2 || kind == 7) {
		base = surface_detail(base, world_position.xz, kind == 0);
	}
	if (kind == 1) { base = painted_grass(colors[1],world_position.xz); }
	ALBEDO = base;
	ROUGHNESS = 1.0;
}
