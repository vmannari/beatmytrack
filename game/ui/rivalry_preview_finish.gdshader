shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://vehicle/livery_finish.gdshaderinc"

uniform vec4 paint_color : source_color = vec4(0.5,0.5,0.5,1.0);
uniform float paint_metallic = 0.0;
uniform float paint_roughness = 0.7;
uniform mat4 mesh_to_body = mat4(1.0);
uniform bool use_texture = false;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_vertex_color = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
varying vec3 body_point;
varying vec3 body_normal;
varying vec3 world_normal;

void vertex() {
	body_point = (mesh_to_body * vec4(VERTEX,1.0)).xyz;
	body_normal = normalize(mat3(mesh_to_body)*NORMAL);
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	vec3 pigment = paint_color.rgb;
	if (use_texture) pigment *= texture(albedo_texture,UV*uv_scale.xy+uv_offset.xy).rgb;
	if (use_vertex_color) pigment *= COLOR.rgb;
	pigment = apply_graphics(pigment,body_point,normalize(body_normal));
	vec3 n = normalize(world_normal) * (FRONT_FACING ? 1.0 : -1.0);
	float key = max(dot(n,normalize(vec3(-0.65,0.85,0.55))),0.0);
	float fill = max(dot(n,normalize(vec3(0.8,0.3,-0.5))),0.0);
	vec3 light = vec3(0.43,0.48,0.53)+vec3(0.62,0.59,0.53)*key+vec3(0.16,0.19,0.23)*fill;
	float softbox = pow(max(dot(normalize(NORMAL),normalize(VIEW+vec3(-0.3,0.6,0.8))),0.0),mix(48.0,8.0,paint_roughness));
	ALBEDO = pigment*light + softbox*mix(0.035,0.16,paint_metallic)*(1.0-paint_roughness);
}
