shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// Original procedural lens baked offline into linear refraction/coverage data.
uniform sampler2D glass_data : filter_linear, repeat_disable;
uniform float lightning = 0.0;
void fragment() {
 vec4 data = texture(glass_data,UV);
 float mask = data.b;
 float rim = data.a;
 COLOR = vec4(0.0);
 if (mask > 0.002) {
  vec2 normal = (data.rg-vec2(0.5))*4.0;
  vec2 offset = normal*SCREEN_PIXEL_SIZE*32.0;
  vec3 color = texture(screen_texture,clamp(SCREEN_UV+offset,vec2(0.001),vec2(0.999))).rgb;
  float facing = clamp(-normal.x*1.1-normal.y*1.5,0.0,1.0);
  color *= 1.0-mask*0.10-rim*0.04;
  color += vec3(0.79,0.90,1.0)*(rim*0.055+facing*0.22)*(1.0+lightning*0.8);
  COLOR = vec4(color,clamp(mask*0.86+rim*0.12,0.0,0.95));
 }
}
