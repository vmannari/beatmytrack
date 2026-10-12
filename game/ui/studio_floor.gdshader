shader_type spatial;
// Quiet seamless photographic cove, original procedural surface, world metres.
varying vec3 studio_position;
void vertex() { studio_position = VERTEX; }
void fragment() {
	float grain = fract(sin(dot(floor(studio_position.xz*95.0),vec2(12.9898,78.233)))*43758.5453);
	float pool = exp(-dot(studio_position.xz,studio_position.xz)*0.017);
	vec3 dark = vec3(0.075,0.095,0.125);
	vec3 light = vec3(0.205,0.225,0.25);
	ALBEDO = mix(dark,light,pool) + (grain-0.5)*0.009;
	ROUGHNESS = 0.66;
	METALLIC = 0.05;
}
