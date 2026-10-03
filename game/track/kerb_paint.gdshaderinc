// Original matte painted-concrete wear, shared by raised and flat kerbs.
// Uses the existing baked factors; no decals, relief or collision changes.
vec3 racing_kerb_paint(vec3 paint, vec2 p, float along, float face_up) {
	vec3 detail = texture(surface_factors,p/12.0).rgb;
	float broad = texture(surface_factors,p/72.0+vec2(0.19,0.43)).g;
	vec3 concrete = vec3(0.24,0.25,0.235);
	vec3 aged = mix(paint,concrete,0.06+broad*0.05);
	// Small broken paint patches expose concrete without breaking stripes.
	float aa = max(fwidth(detail.g)*0.65,0.02);
	float chips = smoothstep(0.75-aa,0.86+aa,detail.g)*smoothstep(0.28,0.64,broad);
	aged = mix(aged,concrete,chips*0.65);
	// Quiet intermittent rubber/dirt scuffs, strongest on the upper face.
	float rubber = smoothstep(0.53,0.77,broad)*(1.0-smoothstep(0.40,0.64,detail.g));
	aged *= 1.0-rubber*0.18*clamp(face_up+0.2,0.2,1.0);
	// Hairline joins between 75 cm concrete slabs, filtered at driving scale.
	float phase = mod(along,0.75);
	float joint_distance = min(phase,0.75-phase);
	float seam_aa = max(fwidth(along),0.002);
	float seam = (1.0-smoothstep(0.012-seam_aa,0.012+seam_aa,joint_distance))*min(1.0,0.012/seam_aa);
	return aged*(1.0-seam*0.22);
}
