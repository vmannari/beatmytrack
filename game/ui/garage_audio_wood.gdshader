shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 timber_tint : source_color = vec4(0.31, 0.205, 0.12, 1.0);
varying vec3 grain_position;
varying vec3 grain_normal;
float timber_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 blend = fract(position);
	blend = blend * blend * (3.0 - 2.0 * blend);
	vec4 dots = vec4(dot(cell, vec2(127.1,311.7)), dot(cell+vec2(1.0,0.0), vec2(127.1,311.7)), dot(cell+vec2(0.0,1.0), vec2(127.1,311.7)), dot(cell+vec2(1.0), vec2(127.1,311.7)));
	vec4 values = fract(sin(dots) * 43758.5453);
	return mix(mix(values.x,values.y,blend.x),mix(values.z,values.w,blend.x),blend.y);
}
void vertex() {
	grain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	grain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	// The station is turned against the side wall. Lengthwise veneer follows
	// the cabinet instead of the old workshop-wide striped plank projection.
	float across = mix(grain_position.y, grain_position.x, abs(grain_normal.y));
	float along = grain_position.z;
	float bend = timber_noise(vec2(along * 2.1,across * 3.0)) * 0.012;
	vec2 fibre_uv = vec2(along * 3.0,(across + bend) * 320.0);
	float filtered = 1.0 - smoothstep(0.5, 1.5, fwidth(fibre_uv.y));
	float grain = (timber_noise(fibre_uv)-0.5) * filtered;
	float broad = timber_noise(vec2(along * 0.7,across * 52.0))-0.5;
	float pores = smoothstep(0.72,0.92,timber_noise(fibre_uv * vec2(4.0,1.3))) * filtered;
	ALBEDO = timber_tint.rgb * (0.98 + grain * 0.10 + broad * 0.10 - pores * 0.06);
	ROUGHNESS = 0.49 + pores * 0.06 - grain * 0.025;
	SPECULAR = 0.32;
}
