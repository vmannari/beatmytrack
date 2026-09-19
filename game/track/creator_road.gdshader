shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
#include "res://track/surface_detail.gdshaderinc"

uniform sampler2D overlay_mask : filter_nearest, repeat_disable;
uniform sampler2D verge_blend_mask : filter_linear, repeat_disable;
uniform vec4 sand_color : source_color;
uniform vec2 map_extent;
uniform vec4 road_color : source_color;
uniform bool gravel = false;
uniform bool grass = false;
uniform bool kerb = false;
uniform vec4 kerb_pale : source_color = vec4(0.87,0.867,0.827,1.0);
uniform vec4 grass_color : source_color;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Filter only the decorative sand join; road/marking masks stay exact.
float sand_coverage(vec2 uv) {
	vec2 d = 0.65 / vec2(textureSize(verge_blend_mask,0));
	float value = texture(verge_blend_mask,uv).b * 4.0;
	value += 2.0*(texture(verge_blend_mask,uv+vec2(d.x,0.0)).b+texture(verge_blend_mask,uv-vec2(d.x,0.0)).b);
	value += 2.0*(texture(verge_blend_mask,uv+vec2(0.0,d.y)).b+texture(verge_blend_mask,uv-vec2(0.0,d.y)).b);
	value += texture(verge_blend_mask,uv+d).b+texture(verge_blend_mask,uv-d).b;
	value += texture(verge_blend_mask,uv+vec2(d.x,-d.y)).b+texture(verge_blend_mask,uv+vec2(-d.x,d.y)).b;
	float sand = value / 16.0;
	if (sand > 0.001 && sand < 0.999) {
		sand = 1.0-grass_fringe(mix(0.55,0.98,1.0-sand),world_position.xz);
	}
	return sand;
}

void fragment() {
	vec2 map_uv = (world_position.xz + map_extent) / (map_extent * 2.0);
	// Every painted cell wins over the procedural road, including asphalt
	// paint used to open a junction. Obstacles keep their native footprints.
	if (any(lessThan(map_uv, vec2(0.0))) || any(greaterThan(map_uv, vec2(1.0)))
			|| texture(overlay_mask, map_uv).r < 0.5) { discard; }
	// Keep-road protects the road mesh, not its grass skirt or gravel fringe.
	vec3 mask = texture(overlay_mask,map_uv).rgb;
	if ((grass || gravel) && mask.g < 0.5 && mask.b < 0.5) { discard; }
	float sand = 0.0;
	if (grass || gravel) { sand = sand_coverage(map_uv); }
	ALBEDO = surface_detail(road_color.rgb, world_position.xz, true);
	if (grass) { ALBEDO = mix(painted_grass(road_color.rgb,world_position.xz),sand_detail(sand_color.rgb,world_position.xz),sand); }
	if (kerb) {
		// Fit complete equal blocks to each exposed run. An odd count starts
		// and ends white; no arbitrary half-red slivers at curve boundaries.
		float count = max(1.0,2.0*floor(UV.y/3.0)+1.0);
		float block_length = max(UV.y/count,0.001);
		float tip = smoothstep(0.0, min(block_length,1.8), min(UV.x,UV.y-UV.x));
		if (UV2.x > mix(0.12,1.0,tip)) { discard; }
		float phase = mod(UV.x+block_length,block_length*2.0);
		float aa = max(fwidth(UV.x),0.001);
		float pale = smoothstep(block_length-aa,block_length+aa,phase);
		if (UV.x < aa || UV.x > UV.y-aa) { pale = 1.0; }
		ALBEDO = mix(road_color.rgb,kerb_pale.rgb,pale);
	}
	if (gravel) {
		ALBEDO = sand_detail(road_color.rgb,world_position.xz);
		float fringe = grass_fringe(UV.y,world_position.xz)*(1.0-sand);
		ALBEDO = mix(ALBEDO,painted_grass(grass_color.rgb,world_position.xz),fringe);
	}
	ROUGHNESS = 1.0;
}
