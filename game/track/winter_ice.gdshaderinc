// Pale neutral ice; preserve subdued luminance detail without the blue pigment.
vec3 quiet_winter_ice(vec3 artwork) {
	float grain = dot(artwork,vec3(0.2126,0.7152,0.0722));
	return vec3(0.47,0.48,0.49)+(grain-0.30)*0.22;
}
