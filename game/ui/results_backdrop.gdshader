shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, 1.5).rgb;
	float shade = mix(0.76, 0.48, smoothstep(0.1, 0.85, UV.x));
	shade = max(shade, smoothstep(0.48, 1.0, UV.y) * 0.82);
	COLOR = vec4(mix(scene, vec3(0.008,0.023,0.035), shade), 1.0);
}
