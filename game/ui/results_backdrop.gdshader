shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, 2.0).rgb;
	COLOR = vec4(mix(scene * 0.34, vec3(0.015,0.035,0.052), 0.28), 1.0);
}
