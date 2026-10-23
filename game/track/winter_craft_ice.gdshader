shader_type spatial;
render_mode diffuse_burley, blend_mix, depth_prepass_alpha, cull_back;
varying vec3 craft_position;
void vertex() { craft_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 pigment=COLOR.rgb;
	if (!OUTPUT_IS_SRGB) pigment=mix(pigment/12.92,pow((pigment+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),pigment));
	float ice=step(0.2,COLOR.a)*(1.0-step(0.8,COLOR.a));
	float rim=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
	ALBEDO=pigment; ROUGHNESS=mix(0.85,0.23,ice); SPECULAR=mix(0.2,0.55,ice);
	ALPHA=mix(1.0,0.37+rim*0.46,ice);
	if (COLOR.a>0.9) EMISSION=pigment*2.2;
}
