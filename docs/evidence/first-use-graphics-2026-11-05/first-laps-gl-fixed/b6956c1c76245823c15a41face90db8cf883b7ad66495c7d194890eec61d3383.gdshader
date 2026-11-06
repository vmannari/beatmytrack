shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

varying float blade_tone;
void vertex() {
	float seed = fract(sin(float(INSTANCE_ID) * 78.233 + 13.7) * 43758.5453);
	blade_tone = seed;
	// Particle angle is otherwise unused by a non-billboard mesh. Tumble the
	// folded blade about two axes; no camera-facing rectangles or uniform spin.
	float angle = INSTANCE_CUSTOM.x;
	float c = cos(angle);
	float s = sin(angle);
	mat3 roll = mat3(vec3(c,s,0),vec3(-s,c,0),vec3(0,0,1));
	float pitch = angle * 0.73 + seed * 6.283;
	mat3 flip = mat3(vec3(1,0,0),vec3(0,cos(pitch),sin(pitch)),vec3(0,-sin(pitch),cos(pitch)));
	VERTEX = roll * flip * VERTEX;
	NORMAL = roll * flip * NORMAL;
	// Shrink only at the end, avoiding translucent green confetti.
	VERTEX *= 1.0 - smoothstep(0.65,1.0,INSTANCE_CUSTOM.y);
}
void fragment() {
	vec3 pigment = mix(vec3(0.27,0.36,0.12),vec3(0.48,0.52,0.25),blade_tone);
	float torn_tip = smoothstep(0.65,1.0,UV.y);
	ALBEDO = mix(pigment,vec3(0.48,0.43,0.24),torn_tip*0.3);
	ROUGHNESS = 1.0;
}
