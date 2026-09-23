shader_type canvas_item;

uniform vec4 side_damage = vec4(0.0); // left, right, top, bottom
uniform float minimum_alpha = 0.18;
uniform float maximum_alpha = 0.82;

void fragment() {
	vec4 glass = texture(TEXTURE, UV);
	float left_weight = 1.0 - smoothstep(0.18, 0.48, UV.x);
	float right_weight = smoothstep(0.52, 0.82, UV.x);
	float top_weight = 1.0 - smoothstep(0.18, 0.46, UV.y);
	float bottom_weight = smoothstep(0.54, 0.82, UV.y);
	float reveal = max(max(left_weight * side_damage.x, right_weight * side_damage.y),
		max(top_weight * side_damage.z, bottom_weight * side_damage.w));
	float alpha_scale = mix(minimum_alpha, maximum_alpha, reveal);
	COLOR = vec4(glass.rgb, glass.a * alpha_scale * smoothstep(0.0, 0.08, reveal));
}
