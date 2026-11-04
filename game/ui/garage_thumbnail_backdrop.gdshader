shader_type spatial;
render_mode unshaded;
varying vec3 studio_position;
void vertex() { studio_position = VERTEX; }
void fragment() {
	vec2 p = SCREEN_UV-vec2(0.5,0.40);
	float halo = exp(-dot(p*vec2(4.1,1.9),p*vec2(4.1,1.9)));
	vec3 color = mix(vec3(0.025,0.045,0.070),vec3(0.10,0.21,0.28),halo);
	// Broad soft illumination only: no light strips, lines or horizon bands.
	float warm = exp(-dot((p-vec2(-0.14,0.05))*vec2(12.0,2.0),(p-vec2(-0.14,0.05))*vec2(12.0,2.0)));
	color += vec3(0.055,0.025,0.004)*warm;
	// The seamless floor remains darker below the lit wall; the deck sits in
	// a soft ground pool instead of against the previous grey horizon band.
	float ground = 1.0-smoothstep(0.0,0.60,studio_position.y);
	float pool = exp(-dot(studio_position.xz,studio_position.xz)*0.025);
	color = mix(color,mix(vec3(0.025,0.045,0.065),vec3(0.07,0.12,0.16),pool),ground*0.20);
	ALBEDO = color;
}
