shader_type spatial;
render_mode diffuse_burley;
varying vec3 local_vertex;
void vertex() { local_vertex = VERTEX; }
void fragment() {
	float radius = length(local_vertex.xz);
	float phase = radius * 3200.0;
	float groove = 0.5 + 0.5 * cos(phase);
	float filtered = mix(groove, 0.5, smoothstep(0.5, 2.0, fwidth(phase)));
	float recorded = smoothstep(0.049, 0.055, radius) * (1.0 - smoothstep(0.145, 0.151, radius));
	ALBEDO = vec3(0.013, 0.018, 0.020) + filtered * recorded * 0.014;
	METALLIC = 0.08;
	ROUGHNESS = mix(0.32, 0.44, filtered * recorded);
}
