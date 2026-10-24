shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley;
void fragment() {
	float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 4.0);
	ALBEDO = vec3(0.15, 0.20, 0.22);
	ROUGHNESS = 0.18;
	SPECULAR = 0.58;
	ALPHA = 0.12 + grazing * 0.23;
}
