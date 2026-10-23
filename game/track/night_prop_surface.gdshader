shader_type spatial;
render_mode cull_disabled;
varying vec3 source_position;
void vertex() { source_position=VERTEX; }
void fragment() {
	vec3 pigment=COLOR.rgb;
	// Source colours are authored in sRGB, matching the native prop materials.
	if (!OUTPUT_IS_SRGB) pigment=mix(pigment/12.92,pow((pigment+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),pigment));
	float detail=1.0-smoothstep(0.01,0.05,length(fwidth(source_position)));
	float wear=1.0+0.025*sin(source_position.x*121.0+source_position.y*87.0+source_position.z*101.0)*detail;
	ALBEDO=pigment*wear;
	ROUGHNESS=0.78;
	METALLIC=0.18;
	float hot=smoothstep(0.30,0.60,COLOR.a);
	EMISSION=pigment*hot*2.3;
}
