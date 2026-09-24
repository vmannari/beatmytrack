shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform vec4 pigment_color : source_color;
uniform sampler2D wear_texture : filter_linear_mipmap, repeat_enable;
varying vec2 ground_position;

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Amplify the baked factor range: subtle road noise alone leaves solid squares.
	float broad_wear = texture(wear_texture, ground_position * 0.19).r;
	float grain = texture(wear_texture, ground_position * 0.83).g;
	float abrasion = smoothstep(0.40, 0.60, broad_wear);
	float flecks = smoothstep(0.38, 0.61, grain);
	vec2 edge_distance = min(UV, vec2(1.0) - UV);
	float edge = min(edge_distance.x, edge_distance.y);
	float erosion = (1.0 - flecks) * 0.12;
	float edge_aa = max(fwidth(edge), 0.008);
	float worn_edge = smoothstep(erosion, erosion + edge_aa, edge);
	ALBEDO = pigment_color.rgb;
	ALPHA = mix(0.12, 0.68, abrasion) * mix(0.28, 1.0, flecks) * worn_edge;
	ROUGHNESS = 1.0;
}

