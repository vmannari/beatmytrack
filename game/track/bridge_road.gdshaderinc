#include "res://track/surface_detail.gdshaderinc"
uniform vec4 road_color : source_color = vec4(0.204,0.212,0.220,1.0);
uniform bool winter_bridge_width_data = false;
uniform bool desert_bridge_width_data = false;
uniform bool raised_road_edge = false;
uniform vec4 sand_color : source_color = vec4(0.60,0.50,0.37,1.0);
varying vec3 world_position;
varying float winter_half_width;
varying vec2 desert_apron_data;
varying float asphalt_edge_shade;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    winter_half_width = winter_bridge_width_data ? UV2.x : 5.0;
    desert_apron_data = UV2;
    asphalt_edge_shade = COLOR.a;
    if (NORMAL.y < 0.0) { NORMAL = -NORMAL; }
}
void fragment() {
    if (packed_sand) { ALBEDO = compacted_road(road_color.rgb,UV); }
    else if (icy_road) { ALBEDO = winter_wear_width(UV,world_position.xz,winter_half_width); }
    else { ALBEDO = surface_detail(road_color.rgb,world_position.xz,true); }
    if (raised_road_edge) ALBEDO *= asphalt_edge_shade;
    if (packed_sand && desert_bridge_width_data) {
        // Same 1.95 m foot as the exposed ground fringe. UV.y already has
        // the corrected signed cross-road coordinate, independent of phase.
        float across = clamp((abs(UV.y)-desert_apron_data.x+1.45)/1.95,0.0,1.0);
        float deposited = desert_bank_coverage(across,world_position.xz)*(1.0-desert_apron_data.y);
        if (deposited > 0.001) ALBEDO = mix(ALBEDO,desert_shoulder(sand_color.rgb,world_position.xz),deposited);
    }
    ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 if (icy_road) {
  vec2 road_uv = winter_road_uv(UV);
  vec4 finish = texture(ice_finish,road_uv);
  float frost = winter_edge_frost(UV,world_position.xz,winter_half_width);
  vec2 ice_response = winter_reflective_finish(finish,frost);
  ROUGHNESS = ice_response.x;
  SPECULAR = ice_response.y;
  NORMAL = winter_road_ice_normal(finish.rg,NORMAL,VIEW_MATRIX,world_position.xz,road_uv);
  RADIANCE = winter_seam_radiance(NORMAL,VIEW,INV_VIEW_MATRIX,winter_seam_weight(finish,frost));
 }
 if (wet_road) {
  ROUGHNESS = wet_road_roughness(world_position.xz);
  SPECULAR = wet_road_specular(world_position.xz);
 }
 if (wet_road) NORMAL = wet_road_relief(world_position.xz,NORMAL,VIEW_MATRIX,1.0);
	if (icy_road) {
		float powder = winter_ground_powder(world_position.xz,1.0);
		ALBEDO = mix(ALBEDO,vec3(0.92,0.945,0.97),powder);
		ROUGHNESS = mix(ROUGHNESS,1.0,powder);
		SPECULAR *= 1.0-powder;
		NORMAL = normalize(mix(NORMAL,(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz,powder));
		RADIANCE *= 1.0-powder;
	}
}
