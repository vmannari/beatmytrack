shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
// A quiet gold surface tint and stronger silhouette retain the part's finish.
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = vec3(1.0, 0.72, 0.14);
	ALPHA = 0.14 + 0.48 * rim;
}
