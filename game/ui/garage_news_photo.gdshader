shader_type canvas_item;
render_mode unshaded;

// The existing native car photograph printed in one ink on the paper stock.
// Stationary, screen-pixel dots stay fine at both menu sizes and phone scaling.
const vec3 PAPER = vec3(0.93333, 0.90588, 0.83137);
const vec3 INK = vec3(0.16078, 0.18039, 0.16078);

void fragment() {
	vec4 photo = texture(TEXTURE, (UV - vec2(0.5)) / 1.25 + vec2(0.5));
	float luminance = dot(photo.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Keep the photograph legible as a rich monochrome image. Avoid a
	// screen-space dot grid, which makes the dark studio backdrop look checked.
	float density = clamp((1.0 - pow(luminance, 0.82)) * 0.82, 0.02, 0.82);
	float coverage = density;
	// Fragment COLOR already includes the texture alpha and inherited opacity.
	COLOR = vec4(mix(PAPER, INK, coverage), COLOR.a);
}
