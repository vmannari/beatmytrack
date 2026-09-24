// Shared road/apron pigment: retain 28% of artwork contrast for car readability.
vec3 quiet_winter_ice(vec3 artwork) {
	return mix(vec3(0.23,0.30,0.37),artwork*0.79,0.28);
}
