shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float flow = 0.0;
uniform bool mist = false;
varying vec4 spray;
void vertex() {
	spray = INSTANCE_CUSTOM;
	if (!mist) { VERTEX.x *= mix(0.10,1.0,UV.y); }
}
void fragment() {
	float edge = 1.0-smoothstep(0.12,0.50,abs(UV.x-0.5));
	float threads = pow(0.5+0.5*sin(UV.x*31.416+spray.x*17.0),3.0);
	float travel = 0.62+0.38*sin(UV.y*84.0-flow*29.0+spray.x*11.0);
	float end_fade = 1.0-smoothstep(0.86,1.0,UV.y);
	ALBEDO = mix(vec3(0.58,0.76,0.81),vec3(0.93,0.98,0.98),threads);
	ALPHA = (mist ? (0.045+0.08*threads) : edge*(0.10+0.38*threads))*end_fade*travel;
}
