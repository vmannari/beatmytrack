shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
#include "res://track/surface_detail.gdshaderinc"

uniform sampler2D overlay_mask : filter_nearest, repeat_disable;
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

void fragment() {
	vec2 map_uv = (world_position.xz + map_extent) / (map_extent * 2.0);
	// Every painted cell wins over the procedural road, including asphalt
	// paint used to open a junction. Obstacles keep their native footprints.
	if (any(lessThan(map_uv, vec2(0.0))) || any(greaterThan(map_uv, vec2(1.0)))
			|| texture(overlay_mask, map_uv).r < 0.5) { discard; }
	ALBEDO = surface_detail(road_color.rgb, world_position.xz, true);
	if (grass) { ALBEDO = painted_grass(road_color.rgb, world_position.xz); }
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
		float grain = pigment(world_position.xz*14.0);
		ALBEDO = road_color.rgb*(0.94+pigment(world_position.xz*1.5)*0.10);
		float grain_visibility = 1.0-smoothstep(0.35,1.0,length(fwidth(world_position.xz*14.0)));
		ALBEDO *= 1.0-mix(0.04,smoothstep(0.70,0.87,grain),grain_visibility)*0.16;
		float fringe = smoothstep(0.55,0.98,UV.y+(pigment(world_position.xz*5.0)-0.5)*0.32);
		ALBEDO = mix(ALBEDO,painted_grass(grass_color.rgb,world_position.xz),fringe);
	}
	ROUGHNESS = 1.0;
}
