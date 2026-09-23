shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
uniform vec4 ground_tint : source_color;
uniform sampler2D grass_macro_mask : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
	// At most 6 mm at the tip; roots never move. Opaque geometry throughout.
	VERTEX.x += sin(TIME*1.2+world_xz.x*0.7+world_xz.y*0.4)*0.006*clamp(VERTEX.y/0.1,0.0,1.0);
}
void fragment() {
	// Thin opaque folded blades are visible on both sides. Keep their soft
	// upward normals on backfaces rather than shading them like black undersides.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	float macro = texture(grass_macro_mask,world_xz/32.0).r;
	vec3 tint = mix(ground_tint.rgb*vec3(0.69,0.77,0.70),ground_tint.rgb,smoothstep(0.12,0.57,macro));
	tint = mix(tint,ground_tint.rgb*vec3(1.20,1.13,1.10),smoothstep(0.56,0.92,macro)*0.72);
	ALBEDO = tint*COLOR.rgb*1.06;
	ROUGHNESS = 1.0;
}
