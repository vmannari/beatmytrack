shader_type spatial;
render_mode cull_back;

// One opaque sealed-beam optic replaces the transparent stack and hidden bowl.
// Subpixel prism detail fades to its mean rather than crawling at race distance.
uniform vec4 glass_tint : source_color = vec4(0.66, 0.72, 0.70, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float filtered = 1.0 - smoothstep(0.025, 0.085, footprint);
	float lower = 1.0 - smoothstep(-0.12, 0.22, p.y);
	float flutes = sin(p.x * 78.0);
	float cross_flutes = sin(p.y * 31.0);
	vec3 prism = normalize(vec3(flutes * (0.035 + 0.070 * lower), cross_flutes * 0.025, 1.0));
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), prism * 0.5 + 0.5, filtered);
	float edge = smoothstep(0.84, 1.02, length(p));
	ALBEDO = glass_tint.rgb * (0.94 - 0.18 * edge + 0.035 * cross_flutes * filtered);
	METALLIC = 0.52;
	ROUGHNESS = 0.24 + 0.09 * edge;
	SPECULAR = 0.55;
}
