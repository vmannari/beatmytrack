shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float strength = 0.36;
void fragment() {
	vec2 p = (UV-0.5)*2.0;
	float fade = exp(-dot(p,p)*3.8)*(1.0-smoothstep(0.75,1.0,length(p)));
	ALBEDO = vec3(0.012,0.018,0.026);
	ALPHA = fade*strength;
}
