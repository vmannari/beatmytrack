shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform vec4 glass_tint : source_color = vec4(0.79, 0.86, 0.84, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float filtered = 1.0 - smoothstep(0.018, 0.055, footprint);
	// Original optical flutes bend reflected light; no copied bitmap or reads.
	NORMAL = normalize(NORMAL + vec3(sin(p.x * 94.0) * 0.09, sin(p.y * 58.0) * 0.025, 0.0) * filtered);
	float flutes = (0.5 + 0.5 * cos(p.x * 94.0)) * filtered;
	ALBEDO = glass_tint.rgb * (0.91 + 0.09 * flutes);
	ROUGHNESS = 0.17;
	SPECULAR = 0.65;
	METALLIC = 0.0;
	ALPHA = 0.31 + 0.12 * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
}
