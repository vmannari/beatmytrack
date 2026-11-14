shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// The original ribbon width is integrated over a pixel rather than sampled
// as alternating covered/uncovered pixels. The support is presentation-only.
uniform vec4 contour_color : source_color = vec4(0.08, 0.11, 0.13, 1.0);
varying float across_pixels;
varying float half_width_pixels;

void vertex() {
	vec4 edge = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 center_position = VERTEX - TANGENT.xyz * UV.y;
	vec4 center = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(center_position, 1.0);
	vec2 delta_pixels = (edge.xy / edge.w - center.xy / center.w) * VIEWPORT_SIZE * 0.5;
	float original_half = length(delta_pixels);
	float support_half = max(original_half + 0.65, 1.0);
	vec2 direction = delta_pixels / max(original_half, 0.00001);
	edge.xy += direction * (support_half - original_half) * 2.0 / VIEWPORT_SIZE * edge.w;
	POSITION = edge;
	across_pixels = UV.x * support_half;
	half_width_pixels = original_half;
}

void fragment() {
	float coverage = clamp(half_width_pixels + 0.5 - abs(across_pixels), 0.0, min(1.0, half_width_pixels * 2.0));
	ALBEDO = contour_color.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
	ALPHA = contour_color.a * coverage;
}
