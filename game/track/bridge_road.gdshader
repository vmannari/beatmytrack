shader_type spatial;
render_mode diffuse_toon, specular_schlick_ggx, cull_disabled;
#include "res://track/surface_detail.gdshaderinc"
uniform vec4 road_color : source_color = vec4(0.204,0.212,0.220,1.0);
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    if (NORMAL.y < 0.0) { NORMAL = -NORMAL; }
}
void fragment() {
    ALBEDO = surface_detail(road_color.rgb,world_position.xz,true);
    ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 if (wet_road && 1.0 > 0.0) {
  float pool = road_puddle(world_position.xz)*1.0;
  ROUGHNESS = clamp(mix(0.70,0.36,pool)+(texture(surface_factors,world_position.xz/32.0).r-0.54)*0.6,0.28,0.82);
  SPECULAR = mix(0.16,0.30,pool)*1.0;
 }
 if (wet_road) NORMAL = wet_road_relief(world_position.xz,NORMAL,VIEW_MATRIX,1.0);
}
