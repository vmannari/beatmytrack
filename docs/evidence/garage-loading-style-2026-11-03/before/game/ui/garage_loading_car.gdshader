shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float shape = texture(TEXTURE,UV).a;
	float grey = mix(0.64,0.46,UV.y);
	float breathe = 0.67+0.045*sin(TIME*1.6);
	COLOR = vec4(vec3(grey),shape*breathe);
}
