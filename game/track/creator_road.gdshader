shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
#include "res://track/surface_detail.gdshaderinc"

uniform sampler2D overlay_mask : filter_nearest, repeat_disable;
uniform vec2 map_extent;
uniform vec4 road_color : source_color;
uniform bool gravel = false;
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
	if (gravel) {
		float grain = pigment(world_position.xz*14.0);
		ALBEDO = road_color.rgb*(0.94+pigment(world_position.xz*1.5)*0.10);
		ALBEDO *= 1.0-smoothstep(0.70,0.87,grain)*0.16;
	}
	ROUGHNESS = 1.0;
}
