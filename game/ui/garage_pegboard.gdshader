shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec4 hole_colour : source_color = vec4(0.090196, 0.12549, 0.145098, 1.0);

void fragment() {
	// The same 26 by 7 hole centres on the authored 4m by 1.18m board.
	vec2 position = vec2((0.5-UV.x)*4.0, (0.5-UV.y)*1.18)+vec2(0.0,2.14);
	vec2 spacing = vec2(0.151,0.174);
	vec2 offset = position-vec2(-1.9,1.61);
	vec2 cell = floor(offset/spacing+0.5);
	if (cell.x < 0.0 || cell.x > 25.0 || cell.y < 0.0 || cell.y > 6.0) discard;
	float distance_to_centre = length(offset-cell*spacing);
	float width = max(fwidth(distance_to_centre),0.0001);
	float coverage = 1.0-smoothstep(0.011-width,0.011+width,distance_to_centre);
	if (coverage <= 0.001) discard;
	ALBEDO = hole_colour.rgb;
	ROUGHNESS = 0.86;
	SPECULAR = 0.25;
	ALPHA = coverage;
}
