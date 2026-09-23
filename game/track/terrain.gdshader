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

vec4 feather(sampler2D source, vec2 uv) {
	vec2 offset = map_texel * 0.65;
	vec4 value = texture(source,uv) * 4.0;
	value += texture(source,uv+vec2(offset.x,0.0))*2.0;
	value += texture(source,uv-vec2(offset.x,0.0))*2.0;
	value += texture(source,uv+vec2(0.0,offset.y))*2.0;
	value += texture(source,uv-vec2(0.0,offset.y))*2.0;
	value += texture(source,uv+offset);
	value += texture(source,uv-offset);
	value += texture(source,uv+vec2(offset.x,-offset.y));
	value += texture(source,uv+vec2(-offset.x,offset.y));
	return value / 16.0;
}
void fragment() {
	vec4 low = feather(surface_low, UV);
	vec4 high = feather(surface_high, UV);
	// Keep a short, irregular grass fringe matching the road shoulder instead
	// of a broad airbrushed halo. Preserve relative weights of other materials.
	float grass_weight = low.g;
	if (grass_weight > 0.001 && grass_weight < 0.999) {
		float broken_grass = grass_fringe(mix(0.55,0.98,grass_weight),world_position.xz);
		float rest = (1.0-broken_grass)/(1.0-grass_weight);
		low *= rest;
		high *= rest;
		low.g = broken_grass;
	}
	float weights[8] = float[8](low.r,low.g,low.b,low.a,high.r,high.g,high.b,high.a);
	vec3 colors[8] = vec3[8](color_0.rgb,color_1.rgb,color_2.rgb,color_3.rgb,color_4.rgb,color_5.rgb,color_6.rgb,color_7.rgb);
	// Blend all material contributions instead of choosing a hard winner.
	vec3 blended = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		// Absent surfaces contribute exactly zero; avoid evaluating their detail.
		if (weights[i] <= 0.0) continue;
		vec3 layer = colors[i];
		if (i == 1) layer = painted_grass(layer,world_position.xz);
		else if (i == 2) layer = sand_detail(layer,world_position.xz);
		else if (i == 0 || i == 7) layer = surface_detail(layer,world_position.xz,i == 0);
		else if (i == 3 || i == 6) {
			float band = step(0.82,sin(world_position.z*0.52+sin(world_position.x*0.18)*0.4));
			layer *= 0.98 + band*0.045;
			layer = mix(layer*0.88,color_6.rgb*1.15,pigment(world_position.xz*0.35)*0.22);
		}
		blended += layer * weights[i];
	}
	ALBEDO = blended;
	NORMAL = grass_relief(world_position.xz,NORMAL,VIEW_MATRIX,low.g);
	ROUGHNESS = 1.0;
}
