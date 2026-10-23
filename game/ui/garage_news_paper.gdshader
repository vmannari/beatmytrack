shader_type canvas_item;
render_mode unshaded;

// Stationary stock: uneven pulp, tiny ink flecks and age at the sheet edges.
// No time input, texture reads, repeated ruling or per-frame preparation.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pulp(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 pixel = FRAGCOORD.xy;
	float grain = hash(floor(pixel));
	float cloud = pulp(pixel * 0.012) * 0.6 + pulp(pixel * 0.043) * 0.4;
	float fibres = pulp(pixel * vec2(0.35, 0.19));
	vec2 edge = min(UV, vec2(1.0) - UV);
	float age = exp(-min(edge.x, edge.y) * 35.0);
	float specks = smoothstep(0.965, 1.0, grain) * (0.3 + cloud);
	vec3 stock = vec3(0.941, 0.909, 0.820);
	stock += (cloud - 0.5) * vec3(0.065, 0.058, 0.043);
	stock += (grain - 0.5) * 0.028 + (fibres - 0.5) * 0.025;
	stock -= age * vec3(0.055, 0.063, 0.070) + specks * 0.065;
	// A faint irregular fold catches light without reading as a printed stripe.
	float crease = UV.x - 0.638 - sin(UV.y * 8.0) * 0.001;
	stock += exp(-abs(crease) * 1400.0) * 0.035;
	stock -= exp(-abs(crease + 0.002) * 900.0) * 0.018;
	COLOR = vec4(stock, 1.0);
}
