// Keep crystalline frost and scraped compacted snow readable in the artwork.
vec3 quiet_winter_ice(vec3 artwork) {
	float grain = dot(artwork,vec3(0.2126,0.7152,0.0722));
	return vec3(0.33,0.405,0.49)+(grain-0.30)*0.30;
}
