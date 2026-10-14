shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 workshop_position;
void vertex() { workshop_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float grain = sin(workshop_position.z * 105.0 + sin(workshop_position.x * 2.3) * 2.0 + sin(workshop_position.z * 13.0) * 0.7);
	float plank = smoothstep(0.491,0.499,abs(fract(workshop_position.z / 0.19)-0.5));
	ALBEDO = vec3(0.27,0.21,0.135) * (0.96+grain*0.035) * (1.0-plank*0.14);
	ROUGHNESS = 0.63;
	SPECULAR = 0.32;
}
