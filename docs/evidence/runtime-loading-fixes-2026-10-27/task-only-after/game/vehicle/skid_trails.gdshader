
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, world_vertex_coords;
#include "res://vehicle/dust_bridge_clip.gdshaderinc"
uniform bool desert_sand_trails = false;
uniform float trail_bridge_height_offset = 0.0;
uniform vec4 desert_sand_pigment : source_color = vec4(0.67451,0.54510,0.35294,1.0);
uniform vec4 grass_soil_pigment : source_color = vec4(0.32,0.205,0.11,1.0);
uniform vec4 road_mud_pigment : source_color = vec4(0.43,0.29,0.15,1.0);

varying float loose_surface;
varying float grass_rut;
varying float road_mud;
varying float sand_pressure;
varying float ice_scuff;
varying vec3 ice_contact_normal;
varying vec3 trail_lateral_normal;
varying float rut_ratio;
varying float pressure_alpha;
varying highp vec3 trail_world;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	// Loose surfaces retain 1; road mud uses the otherwise-unused 0..0.49 range.
	loose_surface = step(0.5,INSTANCE_CUSTOM.b);
	road_mud = (1.0-loose_surface)*INSTANCE_CUSTOM.b;
	grass_rut = 1.0-step(0.005,abs(INSTANCE_CUSTOM.r-0.1));
	sand_pressure = mix(INSTANCE_CUSTOM.g,INSTANCE_CUSTOM.a,UV.y);
	ice_scuff = 1.0-smoothstep(0.005,0.015,abs(INSTANCE_CUSTOM.r-0.8));
	// The two side columns carry the start/end cross-sections, not a rigid
	// pose. Shared endpoint vectors produce an actual joined four-vertex ribbon.
	vec3 start_side = vec3(MODEL_MATRIX[0].x,0.0,MODEL_MATRIX[0].z);
	vec3 end_side = vec3(MODEL_MATRIX[1].x,0.0,MODEL_MATRIX[1].z);
	vec3 side = mix(start_side,end_side,UV.y);
	vec3 contact = normalize(cross(MODEL_MATRIX[2].xyz,side));
	ice_contact_normal = normalize((VIEW_MATRIX * vec4(contact,0.0)).xyz);
	trail_lateral_normal = normalize((VIEW_MATRIX * vec4(normalize(side),0.0)).xyz);
	rut_ratio = MODEL_MATRIX[1].y / max(length(side),0.001);
	trail_world = MODEL_MATRIX[3].xyz + MODEL_MATRIX[2].xyz * (UV.y-0.5) + side * (UV.x-0.5);
	VERTEX = trail_world;
	NORMAL = contact;
	// Smooth deposited opacity through each contact; pow runs at four vertices,
	// rather than per fragment. COLOR.a retains the approved average pigment.
	float mean_pressure = (INSTANCE_CUSTOM.g+INSTANCE_CUSTOM.a)*0.5;
	float hard = float(abs(INSTANCE_CUSTOM.r)<0.015 || abs(INSTANCE_CUSTOM.r-0.5)<0.015 || abs(INSTANCE_CUSTOM.r-0.8)<0.015 || abs(INSTANCE_CUSTOM.r-0.9)<0.015);
	hard *= float(road_mud == 0.0);
	float endpoint_opacity = mix(mix(0.12,1.0,sand_pressure),0.02+0.98*pow(sand_pressure,1.7),hard);
	float mean_opacity = mix(mix(0.12,1.0,mean_pressure),0.02+0.98*pow(mean_pressure,1.7),hard);
	pressure_alpha = endpoint_opacity / max(mean_opacity,0.001);
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	// The pattern belongs to the deposited surface, not an individual segment.
	// Shared endpoints sample the same grain even as the car turns or speed changes.
	vec2 grain_position = trail_world.xz * 38.0;
	float lane = floor(UV.x * 7.0);
	float grain = hash21(floor(grain_position));
	float tread = smoothstep(0.38, 0.62, fract((trail_world.x + trail_world.z) * 8.0 + lane * 0.37));
	float center_press = 1.0 - smoothstep(0.05, 0.55, across);
	float shoulder = smoothstep(0.52, 0.82, across) * (1.0 - smoothstep(0.82, 1.0, across));
	float loose_tone = mix(0.78, 1.02, tread) - center_press * 0.09 + shoulder * 0.12;
	float asphalt_grain = grain;
	float asphalt_streaks = 0.82 + 0.18 * smoothstep(0.15, 0.85, sin(UV.x * 21.99) * 0.5 + 0.5);
	float asphalt_tone = asphalt_streaks * mix(0.88, 1.08, asphalt_grain);
	float tone = mix(asphalt_tone, loose_tone, loose_surface);
	// Analytic rounded groove replaces ten faceted triangles. The contact normal
	// still follows the bridge slope; both biomes' sand shares this groove shading.
	float rise = clamp((across-0.20)/0.45,0.0,1.0);
	float fall = clamp((across-0.65)/0.35,0.0,1.0);
	float rut_slope = sign(UV.x-0.5)*rut_ratio*9.84*(rise*(1.0-rise)/0.45-fall*(1.0-fall)/0.35);
	NORMAL = normalize(ice_contact_normal-trail_lateral_normal*rut_slope);
	if (desert_sand_trails && loose_surface > 0.5) {
		// Retain matte sand while sharing Grass-biome sand's tread and relief.
		SPECULAR = 0.0;
	}
	float chipped_edge = mix(1.0, smoothstep(0.18, 0.62, grain + (1.0 - across) * 0.72), loose_surface * smoothstep(0.76, 1.0, across));
	float feather = 1.0 - smoothstep(0.72, 1.0, across);
	ALBEDO = COLOR.rgb * tone;
	if (grass_rut > 0.5) { ALBEDO = grass_soil_pigment.rgb * tone; }
	if (road_mud > 0.0) { ALBEDO = road_mud_pigment.rgb * tone; }
	if (desert_sand_trails && loose_surface > 0.5) { ALBEDO = desert_sand_pigment.rgb * tone; }
	ROUGHNESS = 1.0;
	if (ice_scuff > 0.5) {
		NORMAL = ice_contact_normal;
		ROUGHNESS = 0.7;
	}
	vec3 camera_ray = PROJECTION_MATRIX[3].w>0.5 ? INV_VIEW_MATRIX[2].xyz : normalize(INV_VIEW_MATRIX[3].xyz-trail_world);
	// The shared mask describes the original bridge profile. Transform the
	// contact back into that frame, retaining the visible deck's cosmetic offset.
	vec3 bridge_world = trail_world - vec3(0.0,trail_bridge_height_offset,0.0);
	float bridge_visibility = dust_bridge_projected_visibility(bridge_world,camera_ray,bridge_world.y);
	ALPHA = COLOR.a * pressure_alpha * chipped_edge * feather * bridge_visibility;
}
