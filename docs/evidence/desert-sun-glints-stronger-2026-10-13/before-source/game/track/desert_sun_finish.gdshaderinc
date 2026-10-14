// Sparse dielectric minerals; the normal lighting pass supplies real sun,
// shadow and view response. No emission, animation clock or extra texture.
uniform float desert_glint_strength : hint_range(0.0,1.0) = 1.0;
vec2 mineral_sun_finish(vec3 mineral, float footprint, float weight) {
	float grains = smoothstep(0.56,0.61,mineral.r)*smoothstep(0.42,0.50,mineral.b);
	float resolved = 1.0-smoothstep(0.07,0.20,footprint);
	float glint = clamp(grains*resolved*weight*desert_glint_strength,0.0,1.0);
	float facets = smoothstep(0.05,0.20,glint);
	return vec2(mix(1.0,0.28,facets),glint*0.38);
}
