shader_type spatial;
render_mode diffuse_toon, specular_disabled;
#include "res://track/surface_detail.gdshaderinc"
uniform vec4 ground_color : source_color;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	ALBEDO = painted_grass(ground_color.rgb, world_position.xz);
	ROUGHNESS = 1.0;
}
