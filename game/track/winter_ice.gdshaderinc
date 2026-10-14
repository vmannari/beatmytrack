// Keep crystalline frost and scraped compacted snow readable in the artwork.
vec3 quiet_winter_ice(vec3 artwork) {
	float grain = dot(artwork,vec3(0.2126,0.7152,0.0722));
	return vec3(0.50,0.56,0.60)+(grain-0.30)*0.20;
}

uniform float winter_seam_reflection_strength : hint_range(0.0,1.0) = 1.0;

// Packed A follows elongated existing artwork ridges; broad ice stays matte.
float winter_seam_weight(vec4 finish, float frost) {
	return finish.a*(1.0-smoothstep(0.20,0.75,frost))*winter_seam_reflection_strength;
}

vec2 winter_reflective_finish(vec4 finish, float frost) {
	float seam = winter_seam_weight(finish,frost);
	return vec2(mix(0.88,0.12,seam),mix(0.08,1.0,seam));
}

// Thin reflective facets catch the same static sky directions with stronger
// contrast; this feeds reflected lighting, not albedo or self-illumination.
vec4 winter_seam_radiance(vec3 normal, vec3 view, mat4 inverse_view, float seam) {
	// Most packed ice has exactly zero seam coverage. Its reflected radiance
	// is unused, so skip the directional cloud field on those fragments.
	if (seam <= 0.0) return vec4(0.0);
	vec3 direction = normalize((inverse_view*vec4(reflect(-view,normal),0.0)).xyz);
	float field = sin(direction.x*18.0+direction.z*7.0)
		+sin(direction.z*23.0-direction.x*9.0+1.7)*0.45;
	float cloud = smoothstep(0.15,1.15,field);
	vec3 light = mix(vec3(0.40,0.65,0.95),vec3(2.0,2.2,2.4),cloud);
	return vec4(light,seam*0.72);
}
