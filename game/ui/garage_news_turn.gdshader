shader_type canvas_item;
render_mode unshaded;

// Original single-sheet fold for the complete newspaper. The old page is opaque;
// revealed pixels show the live next article underneath, without overprinting.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float turn_direction = 1.0;
uniform vec2 page_size = vec2(1024.0, 384.0);
const vec3 PAPER = vec3(0.93333, 0.90588, 0.83137);

void fragment() {
	float t = clamp(progress, 0.0, 1.0);
	vec2 uv = vec2(turn_direction > 0.0 ? UV.x : 1.0 - UV.x, UV.y);
	vec2 point = uv * page_size;
	vec2 normal = normalize(vec2(1.0, 0.18 + 0.16 * sin(t * 3.14159265)));
	float extent = dot(page_size, normal);
	float fold = mix(extent + 2.0, -2.0, t);
	float distance_to_fold = dot(point, normal) - fold;
	float radius = max(12.0, page_size.x * 0.035) * sin(t * 3.14159265);
	float shadow = exp(-max(distance_to_fold, 0.0) / max(1.0, radius * 0.7));
	vec4 result = vec4(0.12, 0.10, 0.07, shadow * 0.20 * sin(t * 3.14159265));
	if (distance_to_fold <= 0.0) {
		result = texture(TEXTURE, UV);
	}
	// Reflect the lifted corner across its crease to form the paper's back.
	vec2 source = point - 2.0 * distance_to_fold * normal;
	float edge = min(min(source.x, page_size.x - source.x), min(source.y, page_size.y - source.y));
	float antialias = max(0.7, fwidth(edge));
	float back_mask = smoothstep(-antialias, antialias, edge) * step(distance_to_fold, 0.0);
	vec2 back_uv = source / page_size;
	if (turn_direction < 0.0) back_uv.x = 1.0 - back_uv.x;
	vec3 reverse_ink = texture(TEXTURE, clamp(back_uv, vec2(0.0), vec2(1.0))).rgb;
	float bend = exp(-abs(distance_to_fold) / max(1.0, radius));
	float highlight = exp(-pow((distance_to_fold + radius * 0.9) / max(1.0, radius * 0.55), 2.0));
	vec3 back = mix(PAPER, reverse_ink, 0.055) * (0.96 - bend * 0.19) + highlight * 0.07;
	result = mix(result, vec4(back, 1.0), back_mask);
	COLOR = result;
}
