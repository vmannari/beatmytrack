#include "res://track/surface_detail.gdshaderinc"
uniform vec4 road_color : source_color = vec4(0.204,0.212,0.220,1.0);
uniform bool winter_bridge_width_data = false;
varying vec3 world_position;
varying float winter_half_width;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    winter_half_width = winter_bridge_width_data ? UV2.x : 5.0;
    if (NORMAL.y < 0.0) { NORMAL = -NORMAL; }
}
void fragment() {
    ALBEDO = surface_detail(road_color.rgb,world_position.xz,true);
    if (icy_road) { ALBEDO = winter_wear_width(UV,world_position.xz,winter_half_width); }
    ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 if (icy_road) {
  vec2 road_uv = winter_road_uv(UV);
  vec4 finish = texture(ice_finish,road_uv);
  float frost = winter_edge_frost(UV,world_position.xz,winter_half_width);
  ROUGHNESS = mix(max(0.18,finish.a*0.65),0.88,frost*0.60);
  SPECULAR = mix(0.55,0.25,max(finish.b*0.6,frost));
  NORMAL = winter_road_ice_normal(finish.rg,NORMAL,VIEW_MATRIX,world_position.xz,road_uv);
 }
 if (wet_road) {
  ROUGHNESS = wet_road_roughness(world_position.xz);
  SPECULAR = wet_road_specular(world_position.xz);
 }
 if (wet_road) NORMAL = wet_road_relief(world_position.xz,NORMAL,VIEW_MATRIX,1.0);
}
