// Original industrial-outskirts artwork; scene lights supply all illumination.
uniform bool industrial_ground = false;
uniform sampler2D night_ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

vec3 industrial_ground_color(vec2 p) {
	vec2 uv = p / 12.0;
	vec2 phase = fract(uv);
	// Hide arbitrary image borders with a narrow, derivative-continuous blend.
	// The central 80% retains coherent slabs; world UVs span every mesh/tile.
	vec2 weight = smoothstep(vec2(0.0),vec2(0.10),phase)
		* (vec2(1.0)-smoothstep(vec2(0.90),vec2(1.0),phase));
	vec3 a = texture(night_ground_albedo,uv,0.5).rgb;
	vec3 b = texture(night_ground_albedo,uv+vec2(0.5,0.0),0.5).rgb;
	vec3 c = texture(night_ground_albedo,uv+vec2(0.0,0.5),0.5).rgb;
	vec3 d = texture(night_ground_albedo,uv+vec2(0.5),0.5).rgb;
	vec3 artwork = mix(mix(d,c,weight.x),mix(b,a,weight.x),weight.y);
	return artwork * 0.85;
}
