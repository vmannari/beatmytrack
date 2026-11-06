
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	ALPHA = COLOR.a;
}
