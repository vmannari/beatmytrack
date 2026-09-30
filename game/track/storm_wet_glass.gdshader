shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float weather_time = 0.0;
uniform float lightning = 0.0;

float hash21(vec2 p) {
 p = fract(p*vec2(123.34,456.21));
 p += dot(p,p+45.32);
 return fract(p.x*p.y);
}
// Sparse adhered beads: multiple sizes, with a clearer central driving corridor.
vec4 beads(vec2 uv, float scale, float seed, float screen_x) {
 vec2 cell = floor(uv*scale);
 vec2 local = fract(uv*scale)-0.5;
 float r = hash21(cell+seed);
 float keep = mix(0.32,0.62,smoothstep(0.12,0.40,abs(screen_x-0.5)));
 float enabled = step(r,keep);
 vec2 center = (vec2(hash21(cell+seed+3.1),hash21(cell+seed+7.9))-0.5)*0.52;
 float growth = 0.85+0.15*sin(weather_time*0.31+r*30.0);
 float radius = mix(0.10,0.27,hash21(cell+seed+13.7))*growth;
 vec2 q = (local-center)/radius;
 float shape = hash21(cell+seed+25.3);
 float angle = (hash21(cell+seed+41.2)-0.5)*2.5;
 q = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*q;
 q /= vec2(mix(0.62,1.12,shape),mix(1.30,0.78,shape));
 q.x += (q.y*q.y-0.25)*(shape-0.5)*0.48;
 float polar = atan(q.y,q.x);
 float edge = 1.0+0.16*sin(polar*3.0+shape*19.0)+0.08*sin(polar*5.0+r*23.0);
 float d = length(q)/edge;
 float feather = max(fwidth(d)*1.5,0.06);
 float mask = (1.0-smoothstep(0.58,1.03+feather,d))*enabled;
 float dome = sqrt(max(0.0,1.0-min(d*d,1.0)));
 return vec4(q*dome*mask,mask,exp(-pow((d-0.77)*5.0,2.0))*mask);
}
void fragment() {
 vec2 uv = SCREEN_UV;
 vec2 p = vec2(uv.x*SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x,uv.y);
 vec4 a = beads(p,10.0,2.7,uv.x);
 vec4 b = beads(p+vec2(0.17,0.43),23.0,31.4,uv.x);
 vec2 normal = a.xy+b.xy*0.40;
 float mask = max(a.z,b.z*0.80);
 float rim = max(a.w,b.w*0.65);
 // Thin uneven rivulets across the lens. They brighten and recede slowly.
 float wet = 0.0;
 float bank = 0.0;
 for (int i=0;i<6;i++) {
  float id = float(i);
  float x = (i<2 ? 0.09+id*0.15 : (i<4 ? 0.76+(id-2.0)*0.14 : 0.38+(id-4.0)*0.24));
  float winding = sin(uv.y*15.0+id*4.0)*0.008+sin(uv.y*38.0+id)*0.003;
  float width = 0.0022+0.0018*(0.5+0.5*sin(uv.y*23.0+id));
  float dx = uv.x-x-winding;
  float activity = 0.45+0.35*sin(weather_time*0.43+id*1.7);
  float stripe = (1.0-smoothstep(width,width*2.2,abs(dx)))*activity;
  wet = max(wet,stripe);
  bank += exp(-pow((abs(dx)-width)*900.0,2.0))*activity;
  normal.x += sign(dx)*stripe*0.30;
 }
 mask = max(mask,wet*0.65);
 vec2 offset = normal*vec2(SCREEN_PIXEL_SIZE.x,SCREEN_PIXEL_SIZE.y)*32.0;
 vec3 color = texture(screen_texture,clamp(uv+offset,vec2(0.001),vec2(0.999))).rgb;
 vec3 richer = texture(screen_texture,clamp(uv+offset*1.65,vec2(0.001),vec2(0.999))).rgb;
 color = mix(color,richer,mask*0.35);
 float facing = clamp(-normal.x*1.1-normal.y*1.5,0.0,1.0);
 color *= 1.0-mask*0.10-rim*0.04;
 color += vec3(0.79,0.90,1.0)*(rim*0.055+facing*0.22+bank*0.045)*(1.0+lightning*0.8);
 COLOR = vec4(color,clamp(mask*0.86+rim*0.12+bank*0.12,0.0,0.95));
}
