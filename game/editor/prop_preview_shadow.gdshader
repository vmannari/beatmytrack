shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.02, 0.03, 0.035);
	ALPHA = pow(max(0.0, 1.0 - radius), 2.0) * 0.34;
}
