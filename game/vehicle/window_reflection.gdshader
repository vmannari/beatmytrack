shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Cheap world-fixed sky reflection: camera/vehicle motion changes the reflected
// direction. No scene capture, screen texture, time animation or transparency.
uniform vec4 glass_tint : source_color = vec4(0.075, 0.125, 0.145, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.40, 0.55, 0.63, 1.0);
uniform vec4 cloud_tint : source_color = vec4(0.79, 0.81, 0.76, 1.0);
uniform bool studio_mode = false;
varying vec3 reflection_point;

void vertex() {
	reflection_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	vec3 direction = normalize((INV_VIEW_MATRIX * vec4(reflect(-view, n), 0.0)).xyz);
	float sky = smoothstep(-0.22, 0.45, direction.y);
	// Side panes often reflect below the horizon from the overhead camera.
	// Include broad generic landscape tones there, rather than nearly black.
	float landscape_band = smoothstep(-0.15, 0.2, sin(dot(direction, vec3(4.0, 1.0, 3.0))));
	vec3 landscape = mix(vec3(0.10, 0.16, 0.17), vec3(0.31, 0.40, 0.42), landscape_band);
	vec3 environment = mix(landscape, sky_tint.rgb, sky);
	// Two broad blurred cloud shapes, anchored to world directions.
	float cloud_a = smoothstep(0.65, 0.94, dot(direction, normalize(vec3(-0.6, 0.65, 0.45))));
	float cloud_b = smoothstep(0.78, 0.97, dot(direction, normalize(vec3(0.72, 0.5, -0.48))));
	float clouds = max(cloud_a, cloud_b * 0.75) * sky;
	float cloud_band = smoothstep(0.18, 0.48, sin(dot(direction, vec3(3.2, 1.6, 2.4))));
	clouds = max(clouds, cloud_band * sky * 0.85);
	environment = mix(environment, cloud_tint.rgb, clouds * 0.8);
	float facing = clamp(dot(n, view), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	float strength = 0.28 + 0.38 * fresnel;
	ALBEDO = mix(glass_tint.rgb, environment, strength);
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float side_pane = 1.0 - smoothstep(0.35, 0.7, abs(world_normal.y));
	EMISSION = environment * strength * mix(0.09, 0.4, side_pane);
	ROUGHNESS = 0.65;
	if (studio_mode) {
		vec3 studio_ray = normalize(direction + reflection_point * 0.45);
		float softbox = pow(max(0.0,dot(studio_ray,normalize(vec3(-0.6,0.9,-0.4)))),5.0);
		float fill = pow(max(0.0,dot(studio_ray,normalize(vec3(0.8,0.35,0.5)))),7.0);
		float ceiling = smoothstep(0.05,0.65,studio_ray.y);
		vec3 studio = mix(vec3(0.07,0.10,0.13),vec3(0.15,0.20,0.25),ceiling);
		studio += vec3(0.48,0.51,0.54)*softbox + vec3(0.20,0.25,0.32)*fill;
		ALBEDO = mix(vec3(0.055,0.085,0.105),studio,0.35+fresnel*0.55);
		EMISSION = studio*(0.06+0.18*fresnel);
		ROUGHNESS = 0.2;
	}
}
