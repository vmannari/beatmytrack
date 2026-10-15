#include "res://track/surface_detail.gdshaderinc"

uniform sampler2D surface_low : filter_linear, repeat_disable;
uniform sampler2D surface_high : filter_linear, repeat_disable;
uniform bool terrain_high_present = true;
uniform bool terrain_packed = false;
uniform bool terrain_uniform_enabled = false;
uniform int terrain_region_channel = -1;
uniform bool terrain_region_low = false;
uniform ivec4 terrain_slots = ivec4(0,1,2,3);
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
	int uniform_code = 0;
	if (terrain_uniform_enabled) {
		ivec2 grid = textureSize(surface_low,0);
		ivec2 cell = clamp(ivec2(floor(UV*vec2(grid))),ivec2(0),grid-ivec2(1));
		vec4 regions = terrain_region_low ? texelFetch(surface_low,cell,0) : texelFetch(surface_high,cell,0);
		uniform_code = regions[terrain_region_channel] > 0.5 ? 1 : 0;
	}
	vec4 low = vec4(0.0);
	vec4 high = vec4(0.0);
	if (uniform_code > 0) {
		// Retain texture-derived mask values and the original shading dataflow.
		// The conservative region guarantees all nine original taps agree.
		low = texture(surface_low,UV);
		high = terrain_high_present ? texture(surface_high,UV) : vec4(0.0);
	} else {
		low = feather(surface_low,UV);
		high = terrain_high_present ? feather(surface_high,UV) : vec4(0.0);
	}
	if (terrain_uniform_enabled) {
		if (terrain_region_low) low[terrain_region_channel] = 0.0;
		else high[terrain_region_channel] = 0.0;
	}
	// packed_terrain_begin
	if (terrain_packed) {
		vec4 packed = low;
		low = vec4(0.0);
		high = vec4(0.0);
		if (terrain_slots.x >= 0 && terrain_slots.x < 4) low[terrain_slots.x] = packed.r;
		else if (terrain_slots.x >= 4) high[terrain_slots.x-4] = packed.r;
		if (terrain_slots.y >= 0 && terrain_slots.y < 4) low[terrain_slots.y] = packed.g;
		else if (terrain_slots.y >= 4) high[terrain_slots.y-4] = packed.g;
		if (terrain_slots.z >= 0 && terrain_slots.z < 4) low[terrain_slots.z] = packed.b;
		else if (terrain_slots.z >= 4) high[terrain_slots.z-4] = packed.b;
		if (terrain_slots.w >= 0 && terrain_slots.w < 4) low[terrain_slots.w] = packed.a;
		else if (terrain_slots.w >= 4) high[terrain_slots.w-4] = packed.a;
	}
	// packed_terrain_end
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
	// Snow and dune pigment ignore the base colour: both terrain channels use
	// the same world artwork. Evaluate it once and retain each exact weight.
	vec3 loose = vec3(0.0);
	if ((winter_snow || desert_dunes) && (low.g > 0.0 || low.b > 0.0)) {
		loose = painted_grass(color_1.rgb,world_position.xz);
	}
	for (int i = 0; i < 8; i++) {
		// Absent surfaces contribute exactly zero; avoid evaluating their detail.
		if (weights[i] <= 0.0) continue;
		vec3 layer = colors[i];
		if ((winter_snow || desert_dunes) && (i == 1 || i == 2)) layer = loose;
		else if (i == 1) layer = painted_grass(layer,world_position.xz);
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
	NORMAL = sand_relief(world_position.xz,NORMAL,VIEW_MATRIX,low.b);
	NORMAL = winter_snow_relief(world_position.xz,NORMAL,VIEW_MATRIX,low.g+low.b);
	NORMAL = dune_relief(world_position.xz,NORMAL,VIEW_MATRIX,low.g+low.b);
	ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 if (desert_dunes && low.g+low.b > 0.0) {
  vec3 mineral = texture(surface_factors,world_position.xz/24.0,0.65).rgb;
  float footprint = length(fwidth(world_position.xz));
  vec2 finish = mineral_sun_finish(mineral,footprint,low.g+low.b);
  ROUGHNESS = finish.x;
  SPECULAR = finish.y;
  NORMAL = mineral_terrain_normal(mineral,footprint,low.g+low.b,NORMAL,VIEW_MATRIX);
 }
 if (icy_road && low.r > 0.0) {
  vec4 finish = texture(ice_finish,world_position.xz/6.0);
  ROUGHNESS = mix(1.0,max(0.18,finish.a*0.65),low.r);
  SPECULAR = mix(0.55,0.25,finish.b*0.6)*low.r;
  NORMAL = winter_ice_normal(finish.rg,NORMAL,VIEW_MATRIX,world_position.xz,low.r);
 }
 if (wet_road && low.r > 0.0) {
  ROUGHNESS = mix(1.0,wet_road_roughness(world_position.xz),low.r);
  SPECULAR = wet_road_specular(world_position.xz)*low.r;
 }
 if (wet_road) NORMAL = wet_road_relief(world_position.xz,NORMAL,VIEW_MATRIX,low.r);
	if (winter_snow) {
		float powder = winter_ground_powder(world_position.xz,low.r+(low.g+low.b)*0.22);
		ALBEDO = mix(ALBEDO,vec3(0.92,0.945,0.97),powder);
		ROUGHNESS = mix(ROUGHNESS,1.0,powder);
		SPECULAR *= 1.0-powder;
		NORMAL = normalize(mix(NORMAL,(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz,powder));
	}
}
