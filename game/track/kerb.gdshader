shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform sampler2D exclusion : filter_nearest, repeat_disable;
uniform vec2 map_extent;
uniform bool sand_berm = false;
uniform sampler2D surface_factors : filter_linear_mipmap_anisotropic, repeat_enable;
#include "res://track/kerb_paint.gdshaderinc"
uniform vec4 red : source_color = vec4(0.682,0.341,0.286,1.0);
uniform vec4 pale_color : source_color = vec4(0.87,0.867,0.827,1.0);
varying vec3 world_position;
varying float face_up;
varying float height_ratio;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 face_up = NORMAL.y;
 height_ratio = clamp((VERTEX.y - 0.018) / 0.10, 0.0, 1.0);
}
void fragment() {
 vec2 map_uv = (world_position.xz+map_extent)/(2.0*map_extent);
 if (texture(exclusion,map_uv).r > 0.5) { discard; }
 float pale;
 if (UV.y < 0.0) { pale = mod(floor(UV.x),2.0); }
 else {
  float count = max(1.0,2.0*floor(UV.y/3.0)+1.0);
  float block = max(UV.y/count,0.001);
  float aa = max(fwidth(UV.x),0.001);
  pale = smoothstep(block-aa,block+aa,mod(UV.x+block,2.0*block));
  if (UV.x < aa || UV.x > UV.y-aa) { pale = 1.0; }
 }
 // Broad illustrated facet values stay distinct even when toon sunlight
 // places both the crown and bevel in the same lighting band.
 float bevel = smoothstep(0.025, 0.12, 1.0 - face_up);
 float foot = 1.0 - smoothstep(0.0, 0.18, height_ratio);
 // Source-grid kerbs contain tiny boundary triangles. Use a softer height
 // ramp there so the shading does not emphasize every raster-cell facet.
 if (UV.y < 0.0) { bevel = 1.0 - smoothstep(0.05, 0.95, height_ratio); }
 float side_tone = UV.y < 0.0 ? 0.60 : 0.34;
 float foot_strength = UV.y < 0.0 ? 0.12 : 0.35;
 float tone = mix(0.78, side_tone, bevel) * (1.0 - foot * bevel * foot_strength);
 ALBEDO = mix(red.rgb,pale_color.rgb,pale) * tone;
 if (sand_berm) {
  vec3 grit = texture(surface_factors,world_position.xz/12.0).rgb;
  float clods = texture(surface_factors,world_position.xz/5.0).g;
  ALBEDO = red.rgb * (0.68+grit.b*0.40+clods*0.26) * mix(1.0,0.70,bevel);
 } else {
  ALBEDO = racing_kerb_paint(mix(red.rgb,pale_color.rgb,pale),world_position.xz,UV.x,face_up) * tone;
 }
 ROUGHNESS = 1.0;
}
