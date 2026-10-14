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
uniform float slow_amount = 0.0;
uniform float slow_snow = 0.0;
uniform float mud = 0.0;
uniform float smudge = 0.0;
uniform sampler2D wash_volume : filter_linear, repeat_disable;
uniform sampler2D slow_wash_volume : filter_linear, repeat_disable;
uniform vec3 wash_min;
uniform vec3 wash_size = vec3(1.0);
uniform float roof_height = 1.5;
uniform float axle_half = 1.28;
uniform float wheel_half_span = 0.83;
uniform float wheel_radius = 0.37;
uniform float rear_only = 0.0;
uniform float wheel_surface = 0.0;
uniform mat4 mesh_to_wheel;
uniform mat4 mesh_to_body;
varying vec3 body_point;
varying vec3 body_normal;
varying vec3 wheel_point;

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

float road_specks(vec2 p) {
	// Individual irregular splash droplets, rather than broad cloudy stains.
	vec2 cell = floor(p);
	vec2 centre = vec2(weather_hash(vec3(cell, 2.1)), weather_hash(vec3(cell, 7.3)));
	centre = vec2(0.5) + (centre - vec2(0.5)) * 0.66;
	float size = 0.055 + weather_hash(vec3(cell, 11.7)) * 0.27;
	float edge = length(fract(p) - centre) / size;
	float cluster = 0.5 + weather_hash(vec3(floor(cell * 0.25), 19.4)) * 0.5;
	float droplet = (1.0 - smoothstep(0.58, 1.0, edge)) * cluster;
	// Subpixel droplets become their average density instead of flickering
	// as the normal driving camera moves across the very fine splash field.
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	return mix(droplet, 0.10 * cluster, smoothstep(0.45, 1.25, footprint));
}

void vertex() {
	body_point = (mesh_to_body * vec4(VERTEX, 1.0)).xyz;
	body_normal = normalize(mat3(mesh_to_body) * NORMAL);
	wheel_point = (mesh_to_wheel * vec4(VERTEX, 1.0)).xyz;
}

float wash_mask(vec3 point, sampler2D volume) {
	vec3 p = clamp((point - wash_min) / wash_size, vec3(0.0), vec3(1.0)) * 15.0;
	float slice = floor(p.z);
	vec2 uv = vec2((slice * 16.0 + p.x + 0.5) / 256.0, (p.y + 0.5) / 16.0);
	vec2 next_uv = vec2((min(slice + 1.0, 15.0) * 16.0 + p.x + 0.5) / 256.0, uv.y);
	return 1.0 - mix(texture(volume, uv).r, texture(volume, next_uv).r, fract(p.z));
}

void fragment() {
	vec3 n = normalize(body_normal);
	float remaining = wash_mask(body_point, wash_volume);
	float slow_remaining = wash_mask(body_point, slow_wash_volume);
	float side = abs(n.x);
	float upward = max(n.y, 0.0);
	// +Z is the authored rear, independent of camera or which side is seen.
	// Tire spray rises first, then flattens near the rear axle and begins
	// settling toward the tail. End panels use a lateral projection.
	float end_projection = smoothstep(0.40, 0.85, abs(n.z));
	float along = mix(body_point.z, body_point.x, end_projection);
	float rear_run = max(0.0, body_point.z + axle_half);
	float curved_rise = 0.40 * rear_run - 0.10 * rear_run * rear_run / max(axle_half, 0.25);
	float across = body_point.y - curved_rise * (1.0 - end_projection);
	vec3 flow_point = vec3(mix(body_point.x, body_point.z, end_projection), across, along);
	float mottling = weather_noise(flow_point * vec3(18.0, 26.0, 6.0));
	vec2 splash_point = vec2(along, across);
	float fine_specks = road_specks(splash_point * vec2(58.0, 150.0));
	float coarse_specks = road_specks(splash_point * vec2(11.0, 58.0) + vec2(8.2, 3.7));
	float speckles = max(fine_specks, coarse_specks * 0.90);
	float front_spray = wheel_spray(body_point, -axle_half);
	float rear_spray = wheel_spray(body_point, axle_half);
	float spray = max(front_spray, rear_spray);
	float near_wheels = smoothstep(wheel_half_span * 0.24, wheel_half_span * 0.80, abs(body_point.x));
	float side_spray = spray * near_wheels * (0.55 + side * 0.45);
	// The wake recirculates rear-wheel spray over the tailgate and bumper,
	// including their centre where the lateral tire fans do not reach.
	float rear_face = smoothstep(0.20, 0.75, n.z) * smoothstep(axle_half * 0.85, axle_half * 1.18, body_point.z);
	float road_film = 1.0 - smoothstep(wheel_radius * 1.1, min(roof_height * 0.58, wheel_radius * 2.4), body_point.y);
	float upper_fade = 1.0 - smoothstep(roof_height * 0.53, roof_height * 0.72, body_point.y);
	float rear_wake = rear_face * (0.26 + road_film * 0.69);
	// Reference-led dense sill/lower-door band. Fine splash scatter becomes
	// sparse upward, with the existing diagonal fans raising it behind tires.
	float side_band = near_wheels * (0.65 + side * 0.35) * road_film * 0.94;
	float coverage = clamp(max(side_band, side_spray * 0.72) * upper_fade, 0.0, 1.0);
	coverage = mix(max(coverage, rear_wake), rear_wake, rear_only);
	// Wheel batches may share tire rubber and rim spokes. Coat only the inner
	// radial area; authored wheel coordinates rotate the dirt with the rim.
	float rim_coverage = 1.0 - smoothstep(wheel_radius * 0.67, wheel_radius * 0.81, length(wheel_point.yz));
	coverage = mix(coverage, rim_coverage, wheel_surface);
	road_film = mix(road_film, 0.85, wheel_surface);
	float surface_wetness = wetness * mix(1.0, rear_face, rear_only);
	float streaks = weather_noise(flow_point * vec3(18.0, 40.0, 3.5));
	float texture_weight = mix(mottling, streaks, max(surface_wetness * 0.45, smudge * 0.85));
	float film = (0.24 + road_film * 0.68) * (0.68 + texture_weight * 0.40) * (1.0 + mud * 0.65);
	float splashes = speckles * (0.42 + road_film * 0.34);
	float deposit = clamp(amount * coverage * (film + splashes + smudge * streaks * 0.35) * remaining, 0.0, 0.94);
	float slow_scope = mix(1.0, rear_face, rear_only) * (1.0 - wheel_surface);
	float slow_deposit = slow_amount * (1.0 - coverage) * slow_scope * (0.42 + mottling * 0.20) * slow_remaining;
	deposit = 1.0 - (1.0 - deposit) * (1.0 - slow_deposit);
	// Dense grains in the lower film are darker than the loose upper dust;
	// Winter retains its snowy palette while using the same deposition shape.
	float grain_darkening = 0.32 * road_film;
	float packed_lower = road_film * (0.20 + mud * 0.25);
	vec3 residue = deposit_color.rgb * (0.87 + mottling * 0.18 - grain_darkening * speckles) * (1.0 - packed_lower);
	ALBEDO = mix(paint_color.rgb * (1.0 - surface_wetness * 0.10), residue, deposit);
	float snow_coat = clamp(snow * max(coverage, upward * 0.38 * (1.0 - rear_only) * (1.0 - wheel_surface)) * (film + splashes) * remaining, 0.0, 0.94);
	snow_coat = 1.0 - (1.0 - snow_coat) * (1.0 - slow_snow * (1.0 - coverage) * slow_scope * 0.38 * slow_remaining);
	ALBEDO = mix(ALBEDO, vec3(0.8627, 0.9098, 0.9294) * (0.87 + mottling * 0.18), snow_coat);
	float icy = snow_coat * smoothstep(0.7, 0.9, speckles);
	deposit = max(deposit, snow_coat);
	ROUGHNESS = mix(paint_roughness, mix(0.90, 0.42, icy), deposit);
	ROUGHNESS = mix(ROUGHNESS, 0.19 + streaks * 0.09, surface_wetness * 0.85);
	METALLIC = paint_metallic * (1.0 - deposit);
	SPECULAR = mix(paint_specular, 0.45, surface_wetness);
	CLEARCOAT = mix(paint_clearcoat * (1.0 - deposit), 0.48, surface_wetness);
	CLEARCOAT_ROUGHNESS = mix(paint_clearcoat_roughness, 0.17, surface_wetness);
}
