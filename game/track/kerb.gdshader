shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform sampler2D exclusion : filter_nearest, repeat_disable;
uniform vec2 map_extent;
uniform vec4 red : source_color = vec4(0.651,0.243,0.188,1.0);
uniform vec4 pale_color : source_color = vec4(0.87,0.867,0.827,1.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
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
 ALBEDO = mix(red.rgb,pale_color.rgb,pale);
 ROUGHNESS = 1.0;
}
