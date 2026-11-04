shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity = 0.34;
void fragment() {
	vec2 point = (UV-vec2(0.5))*2.0;
	float falloff = exp(-dot(point,point)*3.8);
	ALBEDO = vec3(0.008,0.015,0.022);
	ALPHA = falloff*opacity*(1.0-smoothstep(0.65,1.0,length(point)));
}
