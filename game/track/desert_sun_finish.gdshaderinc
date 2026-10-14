// Sparse dielectric minerals; the normal lighting pass supplies real sun,
// shadow and view response. No emission, animation clock or extra texture.
uniform float desert_glint_strength : hint_range(0.0,1.0) = 1.0;
// Direction toward the approved desert sun (-46, -48 degrees).
uniform vec3 desert_sun_direction = vec3(-0.5162,0.71934,0.46484);
vec2 mineral_sun_finish(vec3 mineral, float footprint, float weight) {
	float grains = smoothstep(0.52,0.59,mineral.r)*smoothstep(0.34,0.45,mineral.b);
	float resolved = 1.0-smoothstep(0.10,0.28,footprint);
	float glint = clamp(grains*resolved*weight*desert_glint_strength,0.0,1.0);
	float facets = smoothstep(0.04,0.14,glint);
	return vec2(mix(1.0,0.34,facets),glint*0.70);
}

// Fine, differently oriented grain faces let flat terrain catch the same
// real sun as sloped banks. Only resolved reflecting grains perturb shading;
// albedo, macro dune shape, geometry and inactive finish remain unchanged.
vec3 mineral_terrain_normal(vec3 mineral, float footprint, float weight, vec3 original, mat4 view) {
	float grains = smoothstep(0.52,0.59,mineral.r)*smoothstep(0.34,0.45,mineral.b);
	float resolved = 1.0-smoothstep(0.10,0.28,footprint);
	float glint = clamp(grains*resolved*weight*desert_glint_strength,0.0,1.0);
	float facets = smoothstep(0.35,0.65,glint)*0.65;
	if (facets <= 0.001) return original;
	vec2 tilt = vec2(sin(mineral.g*6.28318530718),sin(mineral.r*23.0+mineral.b*7.0-2.0))*0.95;
	vec3 grain_tilt = (view*vec4(tilt.x,0.0,tilt.y,0.0)).xyz;
	vec3 facet_normal = normalize(original+grain_tilt*facets);
	vec3 sun = (view*vec4(desert_sun_direction,0.0)).xyz;
	// Restrict the added finish to sun-catching faces instead of introducing
	// dark granular holes into the approved dune artwork.
	if (dot(facet_normal,sun) <= dot(original,sun)+0.02) return original;
	return facet_normal;
}
