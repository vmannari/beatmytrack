shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	ALBEDO = texture(snow_albedo,world_position.xz/3.6).rgb*vec3(0.72,0.72,0.73);
	ROUGHNESS = 1.0;
}
