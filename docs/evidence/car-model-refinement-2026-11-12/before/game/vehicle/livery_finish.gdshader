shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://vehicle/livery_finish.gdshaderinc"
uniform vec4 paint_color : source_color;
uniform float paint_roughness;
uniform float paint_metallic;
uniform float paint_specular;
uniform float paint_clearcoat;
uniform float paint_clearcoat_roughness;
uniform mat4 mesh_to_body;
varying vec3 body_point;
varying vec3 body_normal;
void vertex() {
	body_point = (mesh_to_body * vec4(VERTEX,1.0)).xyz;
	body_normal = normalize(mat3(mesh_to_body)*NORMAL);
}
void fragment() {
	ALBEDO = apply_graphics(paint_color.rgb,body_point,normalize(body_normal));
	ROUGHNESS = paint_roughness;
	METALLIC = paint_metallic;
	SPECULAR = paint_specular;
	CLEARCOAT = paint_clearcoat;
	CLEARCOAT_ROUGHNESS = paint_clearcoat_roughness;
}
