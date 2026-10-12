#include "res://track/surface_detail.gdshaderinc"
#include "res://track/kerb_paint.gdshaderinc"

uniform sampler2D overlay_mask : filter_nearest, repeat_disable;
uniform sampler2D verge_blend_mask : filter_linear, repeat_disable;
uniform sampler2D road_mask : filter_linear, repeat_disable;
uniform vec2 road_mask_texel;
uniform vec4 sand_color : source_color;
uniform vec2 map_extent;
uniform vec4 road_color : source_color;
uniform vec4 asphalt_base_color : source_color;
uniform bool gravel = false;
uniform bool grass = false;
uniform bool kerb = false;
uniform bool asphalt_surface = false;
uniform bool edge_fringe = false;
uniform bool road_marking = false;
uniform vec4 kerb_pale : source_color = vec4(0.87,0.867,0.827,1.0);
uniform vec4 grass_color : source_color;
varying vec3 world_position;
varying float bank_slope;

void vertex() {
	bank_slope = 1.0-NORMAL.y;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Filter only the decorative sand join; road/marking masks stay exact.
float sand_coverage(vec2 uv) {
	vec2 d = 0.65 / vec2(textureSize(verge_blend_mask,0));
	float value = texture(verge_blend_mask,uv).b * 4.0;
	value += 2.0*(texture(verge_blend_mask,uv+vec2(d.x,0.0)).b+texture(verge_blend_mask,uv-vec2(d.x,0.0)).b);
	value += 2.0*(texture(verge_blend_mask,uv+vec2(0.0,d.y)).b+texture(verge_blend_mask,uv-vec2(0.0,d.y)).b);
	value += texture(verge_blend_mask,uv+d).b+texture(verge_blend_mask,uv-d).b;
	value += texture(verge_blend_mask,uv+vec2(d.x,-d.y)).b+texture(verge_blend_mask,uv+vec2(-d.x,d.y)).b;
	float sand = value / 16.0;
	if (sand > 0.001 && sand < 0.999) {
		sand = 1.0-grass_fringe(mix(0.55,0.98,1.0-sand),world_position.xz);
	}
	return sand;
}

void fragment() {
	vec2 map_uv = (world_position.xz + map_extent) / (map_extent * 2.0);
	// Every painted cell wins over the procedural road, including asphalt
	// paint used to open a junction. Obstacles keep their native footprints.
	if (any(lessThan(map_uv, vec2(0.0))) || any(greaterThan(map_uv, vec2(1.0)))
			|| texture(overlay_mask, map_uv).r < 0.5) { discard; }
	// Keep-road protects the road mesh, not its grass skirt or gravel fringe.
	vec3 mask = texture(overlay_mask,map_uv).rgb;
	if ((grass || gravel) && mask.g < 0.5 && mask.b < 0.5) { discard; }
	float sand = 0.0;
	if (grass || gravel) { sand = sand_coverage(map_uv); }
	float relief_weight = grass ? (1.0-sand) : 0.0;
	ALBEDO = surface_detail(road_color.rgb, world_position.xz, asphalt_surface);
	if (asphalt_surface && icy_road && !edge_fringe) { ALBEDO = winter_wear(ALBEDO,UV,world_position.xz); }
	if (asphalt_surface && packed_sand && !edge_fringe) { ALBEDO = packed_wear(ALBEDO,UV); }
	if (asphalt_surface && !wet_road && !icy_road && !packed_sand) {
		ALBEDO = directional_asphalt(ALBEDO,world_position.xz,UV2);
	}
	float wet_coverage = wet_road && asphalt_surface ? 1.0 : 0.0;
	if (edge_fringe && !icy_road) {
		// UV.y spans the cosmetic blend strip (1.47 m for desert), so
		// curves never inherit the coarse canonical surface-grid staircase.
		float breakup = pigment(world_position.xz * (packed_sand ? 0.18 : 5.5) + vec2(4.1, 13.7));
		float cutoff = 0.84 + (breakup - 0.5) * 0.22;
		// Reuse the grass/sand shoulder's settled + broken fringe blend.
		// Remap it across a wider band, retaining texture through the transition.
		float sand_edge = mix(0.48,1.04,UV.y)+(breakup-0.5)*0.12*4.0*UV.y*(1.0-UV.y);
		float asphalt_coverage = packed_sand ? 1.0-shoulder_fringe(sand_edge,world_position.xz) : 1.0 - smoothstep(cutoff - 0.30, cutoff + 0.20, UV.y);
		vec3 shoulder = packed_sand ? desert_shoulder(sand_color.rgb,world_position.xz) : sand_detail(sand_color.rgb, world_position.xz);
		ALBEDO = mix(shoulder, ALBEDO, asphalt_coverage);
		wet_coverage *= asphalt_coverage;
	}
	if (road_marking) {
		// Preserve a continuous readable line while breaking up its pigment
		// with mild fading and sparse asphalt-coloured chips.
		float fade = pigment(world_position.xz * 1.9 + vec2(27.0, 8.0)) * 0.12;
		float chip_noise = pigment(world_position.xz * 13.0 + vec2(5.0, 41.0));
		float chip_aa = max(fwidth(chip_noise) * 0.75, 0.025);
		float chips = smoothstep(0.66 - chip_aa, 0.78 + chip_aa, chip_noise) * 0.42;
		vec3 worn_asphalt = surface_detail(asphalt_base_color.rgb, world_position.xz, true);
		ALBEDO = mix(ALBEDO, worn_asphalt, fade + chips);
	}
	if (grass) { ALBEDO = mix(painted_grass(road_color.rgb,world_position.xz),sand_detail(sand_color.rgb,world_position.xz),sand); }
	if (kerb) {
		// Fit complete equal blocks to each exposed run. An odd count starts
		// and ends white; no arbitrary half-red slivers at curve boundaries.
		float count = max(1.0,2.0*floor(UV.y/3.0)+1.0);
		float block_length = max(UV.y/count,0.001);
		float tip = smoothstep(0.0, min(block_length,1.8), min(UV.x,UV.y-UV.x));
		if (UV2.x > mix(0.12,1.0,tip)) { discard; }
		float phase = mod(UV.x+block_length,block_length*2.0);
		float aa = max(fwidth(UV.x),0.001);
		float pale = smoothstep(block_length-aa,block_length+aa,phase);
		if (UV.x < aa || UV.x > UV.y-aa) { pale = 1.0; }
		ALBEDO = racing_kerb_paint(mix(road_color.rgb,kerb_pale.rgb,pale),world_position.xz,UV.x,1.0);
	}
	if (gravel) {
		ALBEDO = packed_sand ? desert_shoulder(road_color.rgb,world_position.xz) : sand_detail(road_color.rgb,world_position.xz);
		if (packed_sand) {
			float contact = 1.0-smoothstep(0.10,0.32,UV.y);
			ALBEDO *= 1.0-contact*0.025;
			if (UV.x < -0.5) { ALBEDO *= 1.08-smoothstep(0.02,0.5,bank_slope)*0.20; }
		}
		float fringe = (packed_sand ? smoothstep(0.40,1.0,UV.y + (texture(surface_factors,world_position.xz/20.0).g-0.5)*0.06) : (hybrid_grass ? shoulder_fringe(UV.y,world_position.xz) : grass_fringe(UV.y,world_position.xz)))*(1.0-sand);
		if (packed_sand && UV.x < -0.5) { fringe = 0.0; }
		ALBEDO = mix(ALBEDO,painted_grass(grass_color.rgb,world_position.xz),fringe);
		relief_weight = fringe;
	}
	ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 if (icy_road && asphalt_surface && !edge_fringe) {
  vec2 road_uv = winter_road_uv(UV);
  vec4 finish = texture(ice_finish,road_uv);
  ROUGHNESS = finish.a;
  SPECULAR = mix(0.50,0.20,finish.b);
  NORMAL = winter_road_ice_normal(finish.rg,NORMAL,VIEW_MATRIX,world_position.xz,road_uv);
 }
 if (wet_road && wet_coverage > 0.0) {
  ROUGHNESS = mix(1.0,wet_road_roughness(world_position.xz),wet_coverage);
  SPECULAR = wet_road_specular(world_position.xz)*wet_coverage;
 }
 if (wet_road && (road_marking || kerb)) {
  ALBEDO *= 0.90;
  ROUGHNESS = kerb ? 0.30 : 0.24;
  SPECULAR = 0.5;
 }
	NORMAL = grass_relief(world_position.xz,NORMAL,VIEW_MATRIX,relief_weight);
	NORMAL = winter_snow_relief(world_position.xz,NORMAL,VIEW_MATRIX,(grass || gravel) ? 1.0 : 0.0);
	// Cosmetic skirts/loose sand carry dunes; the firm timed road stays smooth.
	NORMAL = dune_relief(world_position.xz,NORMAL,VIEW_MATRIX,grass ? 1.0 : (gravel && UV.x >= 0.0 ? smoothstep(0.6,1.0,UV.y)*(1.0-sand) : 0.0));
 if (wet_road) NORMAL = wet_road_relief(world_position.xz,NORMAL,VIEW_MATRIX,wet_coverage);
}
