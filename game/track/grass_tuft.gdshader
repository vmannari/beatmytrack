shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
uniform vec4 ground_tint : source_color;
uniform sampler2D grass_macro_mask : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D painted_grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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
	vec3 paint = texture(painted_grass_texture,world_xz/20.0).rgb;
	vec3 vegetation = mix(paint*ground_tint.rgb/vec3(0.3765,0.4196,0.2118),ground_tint.rgb,0.10);
	vec3 patch = mix(vec3(0.89,0.94,0.88),vec3(1.06,1.035,0.98),macro);
	ALBEDO = vegetation*patch*0.92*COLOR.rgb;
	ROUGHNESS = 1.0;
}
