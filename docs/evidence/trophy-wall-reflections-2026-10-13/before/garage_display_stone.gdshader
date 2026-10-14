shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 stone_position;
float stone_noise(vec3 p) {
 return sin(p.x*1.7+sin(p.z*2.1))*sin(p.y*2.3+p.z*0.6)*0.5+0.5;
}
void vertex() { stone_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec3 p=stone_position;
 float bend=sin(p.x*2.7+p.z*1.8+sin(p.y*1.7))*0.35+sin(p.y*4.3+p.z*3.1)*0.16+sin(p.z*9.0+p.y*7.1)*0.035;
 float vein=abs(sin((p.z*0.73+p.y*0.86+p.x*0.31+bend)*4.0));
 float aa=max(fwidth(vein),0.012);
 float line=1.0-smoothstep(0.025,0.025+aa*1.7,vein);
 float cloud=stone_noise(p*1.6);
 ALBEDO=mix(vec3(0.105,0.120,0.122),vec3(0.165,0.177,0.174),cloud);
 ALBEDO=mix(ALBEDO,vec3(0.34,0.32,0.27),line*0.38);
 ROUGHNESS=0.32+cloud*0.10;
 METALLIC=0.0;
 SPECULAR=0.48;
}
