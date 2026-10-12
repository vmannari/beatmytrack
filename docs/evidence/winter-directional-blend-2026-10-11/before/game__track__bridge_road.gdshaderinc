#include "res://track/surface_detail.gdshaderinc"
uniform vec4 road_color : source_color = vec4(0.204,0.212,0.220,1.0);
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    if (NORMAL.y < 0.0) { NORMAL = -NORMAL; }
}
void fragment() {
    ALBEDO = surface_detail(road_color.rgb,world_position.xz,true);
    if (icy_road) { ALBEDO = winter_wear(ALBEDO,UV,world_position.xz); }
    ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 if (icy_road) {
  vec4 finish = texture(ice_finish,world_position.xz/6.0);
  ROUGHNESS = finish.a;
  SPECULAR = mix(0.50,0.20,finish.b);
  NORMAL = winter_ice_normal(finish.rg,NORMAL,VIEW_MATRIX,world_position.xz,1.0);
 }
 if (wet_road) {
  ROUGHNESS = wet_road_roughness(world_position.xz);
  SPECULAR = wet_road_specular(world_position.xz);
 }
 if (wet_road) NORMAL = wet_road_relief(world_position.xz,NORMAL,VIEW_MATRIX,1.0);
}
