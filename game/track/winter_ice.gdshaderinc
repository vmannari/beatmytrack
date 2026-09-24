// Pale cool ice; preserve subdued luminance detail with a restrained blue tint.
vec3 quiet_winter_ice(vec3 artwork) {
	float grain = dot(artwork,vec3(0.2126,0.7152,0.0722));
	return vec3(0.435,0.475,0.515)+(grain-0.30)*0.22;
}
