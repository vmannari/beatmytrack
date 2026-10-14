shader_type spatial;
render_mode diffuse_toon, specular_schlick_ggx;
#include "res://track/surface_detail.gdshaderinc"
uniform vec4 ground_color : source_color;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	ALBEDO = painted_grass(ground_color.rgb, world_position.xz);
	NORMAL = grass_relief(world_position.xz,NORMAL,VIEW_MATRIX,1.0);
	NORMAL = dune_relief(world_position.xz,NORMAL,VIEW_MATRIX,1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (desert_dunes) {
		vec2 finish = desert_sand_finish(world_position.xz,1.0);
		ROUGHNESS = finish.x;
		SPECULAR = finish.y;
	}
}
