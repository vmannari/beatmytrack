shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Original opaque finish: no overlay geometry, transparency or screen reads.
uniform vec4 paint_color : source_color = vec4(1.0);
uniform vec4 deposit_color : source_color = vec4(0.65, 0.5, 0.3, 1.0);
uniform float paint_roughness = 0.38;
uniform float paint_metallic = 0.12;
uniform float paint_specular = 0.35;
uniform float paint_clearcoat = 0.22;
uniform float paint_clearcoat_roughness = 0.3;
uniform float amount = 0.0;
uniform float wetness = 0.0;
uniform float snow = 0.0;
uniform float mud = 0.0;
uniform float roof_height = 1.5;
uniform float axle_half = 1.28;
uniform float wheel_half_span = 0.83;
uniform float wheel_radius = 0.37;
uniform mat4 mesh_to_body;
varying vec3 body_point;
varying vec3 body_normal;

float weather_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float weather_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(weather_hash(cell), weather_hash(cell + vec3(1,0,0)), f.x),
		mix(weather_hash(cell + vec3(0,1,0)), weather_hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(weather_hash(cell + vec3(0,0,1)), weather_hash(cell + vec3(1,0,1)), f.x),
		mix(weather_hash(cell + vec3(0,1,1)), weather_hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

float wheel_spray(vec3 p, float axle) {
	// A tire throws debris rearward/upward. The plume widens with distance;
	// both axles leave their own tapered fan rather than a random body stain.
	float behind = p.z - axle;
	float distance = max(behind, 0.0);
	float rise = wheel_radius * 0.75 + distance * 0.32;
	float width = wheel_radius * 0.48 + distance * 0.20;
	float fan = 1.0 - smoothstep(width * 0.25, width, abs(p.y - rise));
	float reach = smoothstep(-0.12, wheel_radius * 0.6, behind) * (1.0 - smoothstep(axle_half * 2.2, axle_half * 3.0, distance));
	return fan * reach;
}

void vertex() {
	body_point = (mesh_to_body * vec4(VERTEX, 1.0)).xyz;
	body_normal = normalize(mat3(mesh_to_body) * NORMAL);
}

void fragment() {
	vec3 n = normalize(body_normal);
	float lower = 1.0 - smoothstep(roof_height * 0.32, roof_height * 0.88, body_point.y);
	float side = abs(n.x);
	float upward = max(n.y, 0.0);
	float mottling = weather_noise(body_point * vec3(5.5, 8.0, 5.5));
	float speckles = weather_noise(body_point * 55.0);
	float front_spray = wheel_spray(body_point, -axle_half);
	float rear_spray = wheel_spray(body_point, axle_half);
	float spray = max(front_spray, rear_spray);
	float near_wheels = smoothstep(wheel_half_span * 0.24, wheel_half_span * 0.80, abs(body_point.x));
	float side_spray = spray * near_wheels * (0.55 + side * 0.45);
	// Most dirt follows the rearward wheel fans. A restrained lower road film
	// joins the sills; only Winter deposits appreciably on upward panels.
	float coverage = clamp(0.035 + lower * near_wheels * 0.12 + side_spray * 0.88 + snow * upward * 0.38, 0.0, 1.0);
	float streaks = weather_noise(body_point * vec3(15.0, 1.2, 15.0));
	float texture_weight = mix(mottling, streaks, wetness * 0.45);
	float deposit = amount * coverage * (0.48 + texture_weight * 0.62);
	float splashes = smoothstep(0.44 - amount * 0.12, 0.67 - amount * 0.12, mottling * 0.85 + speckles * 0.15);
	deposit = mix(deposit, amount * coverage * (0.22 + splashes * 0.78), mud * 0.65);
	deposit = clamp(deposit + amount * coverage * smoothstep(0.65, 0.82, speckles) * 0.12, 0.0, 0.91);
	vec3 residue = deposit_color.rgb * (0.87 + mottling * 0.2);
	ALBEDO = mix(paint_color.rgb * (1.0 - wetness * 0.10), residue, deposit);
	float icy = snow * smoothstep(0.7, 0.9, speckles);
	ROUGHNESS = mix(paint_roughness, mix(0.90, 0.42, icy), deposit);
	ROUGHNESS = mix(ROUGHNESS, 0.19 + streaks * 0.09, wetness * 0.85);
	METALLIC = paint_metallic * (1.0 - deposit);
	SPECULAR = mix(paint_specular, 0.45, wetness);
	CLEARCOAT = mix(paint_clearcoat * (1.0 - deposit), 0.48, wetness);
	CLEARCOAT_ROUGHNESS = mix(paint_clearcoat_roughness, 0.17, wetness);
}
