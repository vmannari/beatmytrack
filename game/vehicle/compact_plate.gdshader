shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform sampler2D plate_ink : filter_linear_mipmap, repeat_disable;
uniform vec4 paper_color : source_color;
uniform vec4 ink_color : source_color;
void fragment() {
	float ink = texture(plate_ink, UV).r;
	ALBEDO = paper_color.rgb * (1.0 - ink);
	EMISSION = ink_color.rgb * ink;
	ROUGHNESS = 0.85;
}
