// Keep crystalline frost and scraped compacted snow readable in the artwork.
vec3 quiet_winter_ice(vec3 artwork) {
	return mix(vec3(0.20,0.30,0.40),artwork*vec3(0.60,0.70,0.78),0.72);
}
