shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform int garage_finish_family=0;
uniform vec4 shared_albedo : source_color;
uniform vec4 shared_emission : source_color;
uniform float shared_roughness=1.0;
uniform float shared_metallic=0.0;
uniform float shared_specular=0.5;
uniform float shared_clearcoat=0.0;
uniform float shared_clearcoat_roughness=0.5;


uniform sampler2D reflection_image : source_color, filter_linear, repeat_disable;
uniform bool reflection_enabled = false;
varying vec3 position_world;
float grain(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float concrete_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(grain(cell),grain(cell+vec2(1.0,0.0)),f.x),mix(grain(cell+vec2(0.0,1.0)),grain(cell+vec2(1.0,1.0)),f.x),f.y);
}







uniform vec4 finish_color : source_color = vec4(0.5,0.5,0.5,1.0);
uniform float finish_metallic = 0.0;
uniform float finish_roughness = 0.6;
uniform int finish_kind = 0;
varying vec3 surface_position;
varying vec3 surface_normal;
float hash_surface(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float surface_noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash_surface(cell),hash_surface(cell+vec2(1,0)),f.x),mix(hash_surface(cell+vec2(0,1)),hash_surface(cell+vec2(1,1)),f.x),f.y);
}




uniform vec4 timber_tint : source_color = vec4(0.31, 0.205, 0.12, 1.0);
varying vec3 grain_position;
varying vec3 grain_normal;
float timber_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 blend = fract(position);
	blend = blend * blend * (3.0 - 2.0 * blend);
	vec4 dots = vec4(dot(cell, vec2(127.1,311.7)), dot(cell+vec2(1.0,0.0), vec2(127.1,311.7)), dot(cell+vec2(0.0,1.0), vec2(127.1,311.7)), dot(cell+vec2(1.0), vec2(127.1,311.7)));
	vec4 values = fract(sin(dots) * 43758.5453);
	return mix(mix(values.x,values.y,blend.x),mix(values.z,values.w,blend.x),blend.y);
}




varying vec3 stone_position;
varying vec3 stone_normal;
uniform bool wall_reflections_enabled = true;
uniform vec4 stone_dark : source_color = vec4(0.20,0.225,0.23,1.0);
uniform vec4 stone_light : source_color = vec4(0.29,0.31,0.30,1.0);
uniform vec4 stone_vein : source_color = vec4(0.45,0.42,0.35,1.0);
float stone_noise(vec3 p) {
 return sin(p.x*1.7+sin(p.z*2.1))*sin(p.y*2.3+p.z*0.6)*0.5+0.5;
}




uniform vec4 leaf_color : source_color = vec4(0.27,0.43,0.23,1.0);



varying vec3 local_vertex;


void vertex() {
if (garage_finish_family==0) {
 position_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; 
}
else if (garage_finish_family==1) {

}
else if (garage_finish_family==2) {

	surface_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);

}
else if (garage_finish_family==3) {

	grain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	grain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);

}
else if (garage_finish_family==4) {
 stone_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; stone_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL); 
}
else if (garage_finish_family==5) {

}
else if (garage_finish_family==6) {
 local_vertex = VERTEX; 
}
}
void fragment() {
ALBEDO=vec3(1.0); ROUGHNESS=1.0; METALLIC=0.0; SPECULAR=0.5; EMISSION=vec3(0.0);
if (garage_finish_family==0) {

	vec2 p = position_world.xz;
	// A real opening exposes the grate's below-floor channel.
	if (abs(p.x + 6.5) < 0.335 && abs(p.y + 1.45) < 1.63) { discard; }
	float g = grain(floor(p*120.0));
	float mottling = concrete_noise(p*1.7)*0.5 + concrete_noise(p*5.3)*0.5;
	vec2 panel = abs(fract((p+vec2(1.5,0.0))/3.0)-0.5);
	float join = smoothstep(0.497,0.499,max(panel.x,panel.y));
	float apron = 1.0-smoothstep(4.2,14.0,length(p));
	float display_pool = exp(-pow((p.x+9.2)/1.15,2.0)-pow((p.y-2.8)/4.5,2.0));
	float wall_pool = exp(-pow((p.y-7.3)/1.7,2.0))*(exp(-pow((p.x-5.0)/1.4,2.0))+exp(-pow((p.x+5.0)/1.4,2.0)));
	ALBEDO = mix(vec3(0.13,0.16,0.18),vec3(0.22,0.24,0.25),apron)*(0.95+g*0.012+mottling*0.09)*(1.0-join*0.32);
	ALBEDO += vec3(0.10,0.065,0.016)*display_pool + vec3(0.035,0.025,0.011)*wall_pool;
	ROUGHNESS = 0.32 + mottling*0.12;
	METALLIC = 0.055;
	SPECULAR = 0.65;
	// Soft analytic reflections of the two actual ceiling luminaires.
	// No screen reads or renderer-specific reflection buffers.
	vec3 reflected = reflect(normalize(position_world-CAMERA_POSITION_WORLD),vec3(0.0,1.0,0.0));
	vec2 ceiling = p + reflected.xz * (5.04-position_world.y) / max(reflected.y,0.02);
	float strip_x = 1.0-smoothstep(2.7,3.6,abs(ceiling.x));
	float strip_z = exp(-pow((ceiling.y+2.0)/0.48,2.0))+exp(-pow((ceiling.y-3.5)/0.48,2.0));
	EMISSION = vec3(0.18,0.15,0.095)*strip_x*strip_z*(0.75+0.25*mottling)*(1.0-join*0.3);
	if (reflection_enabled) {
		vec2 uv = vec2(1.0-SCREEN_UV.x,SCREEN_UV.y);
		vec2 texel = 1.0/vec2(textureSize(reflection_image,0));
		vec4 reflection = texture(reflection_image,uv)*0.32;
		reflection += texture(reflection_image,uv+vec2(texel.x,0.0)*2.5)*0.17;
		reflection += texture(reflection_image,uv-vec2(texel.x,0.0)*2.5)*0.17;
		reflection += texture(reflection_image,uv+vec2(0.0,texel.y)*2.5)*0.17;
		reflection += texture(reflection_image,uv-vec2(0.0,texel.y)*2.5)*0.17;
		vec3 reflected_color = reflection.rgb / max(reflection.a,0.001);
		float weight = (0.13+pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),4.0)*0.25)*(1.0-join*0.50)*reflection.a;
		ALBEDO *= 1.0-weight;
		EMISSION += reflected_color*weight;
	}

}
else if (garage_finish_family==1) {

	ALBEDO = vec3(0.18,0.20,0.22);
	ROUGHNESS = 0.30;
	METALLIC = 0.45;
	if (reflection_enabled) {
		vec2 uv = vec2(1.0-SCREEN_UV.x,SCREEN_UV.y);
		vec2 texel = 1.0/vec2(textureSize(reflection_image,0));
		vec4 reflection = texture(reflection_image,uv)*0.40;
		reflection += texture(reflection_image,uv+vec2(texel.x,0.0)*1.2)*0.15;
		reflection += texture(reflection_image,uv-vec2(texel.x,0.0)*1.2)*0.15;
		reflection += texture(reflection_image,uv+vec2(0.0,texel.y)*1.2)*0.15;
		reflection += texture(reflection_image,uv-vec2(0.0,texel.y)*1.2)*0.15;
		vec3 reflected = reflection.rgb / max(reflection.a,0.001);
		float weight = (0.30+pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0)*0.15)*reflection.a;
		ALBEDO *= 1.0-weight;
		EMISSION = reflected*weight;
	}

}
else if (garage_finish_family==2) {

	vec3 n = abs(surface_normal);
	vec2 uv = n.y > 0.7 ? surface_position.xz : n.x > 0.7 ? surface_position.zy : surface_position.xy;
	float detail = 1.0-smoothstep(0.012,0.050,length(fwidth(uv)));
	float grain = surface_noise(uv*58.0)-0.5;
	float coarse = surface_noise(uv*3.4)-0.5;
	float bump = 0.0018;
	if (finish_kind == 1) { grain = sin(uv.y*340.0+surface_noise(uv*4.0)*3.0)*0.5; bump = 0.0007; }
	if (finish_kind == 2) { grain = surface_noise(uv*90.0)-0.5; bump = 0.0007; }
	if (finish_kind == 3) { grain = surface_noise(uv*35.0)-0.5; bump = 0.0022; }
	if (finish_kind == 4) { grain = sin(uv.x*290.0)*sin(uv.y*290.0)*0.5; bump = 0.0012; }
	if (finish_kind == 5) { grain = surface_noise(uv*72.0)-0.5; bump = 0.0011; }
	grain *= detail;
	ALBEDO = finish_color.rgb*(1.0+grain*0.025+coarse*0.03);
	ROUGHNESS = clamp(finish_roughness+grain*0.05+coarse*0.03,0.12,1.0);
	METALLIC = finish_metallic;
	SPECULAR = finish_kind == 5 ? 0.28 : 0.45;
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL), r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	vec3 gradient = sign(determinant)*(dFdx(grain)*r1+dFdy(grain)*r2);
	NORMAL = normalize(max(abs(determinant),0.000001)*NORMAL-gradient*bump);

}
else if (garage_finish_family==3) {

	// The station is turned against the side wall. Lengthwise veneer follows
	// the cabinet instead of the old workshop-wide striped plank projection.
	float across = mix(grain_position.y, grain_position.x, abs(grain_normal.y));
	float along = grain_position.z;
	float bend = timber_noise(vec2(along * 2.1,across * 3.0)) * 0.012;
	vec2 fibre_uv = vec2(along * 3.0,(across + bend) * 320.0);
	float filtered = 1.0 - smoothstep(0.5, 1.5, fwidth(fibre_uv.y));
	float grain = (timber_noise(fibre_uv)-0.5) * filtered;
	float broad = timber_noise(vec2(along * 0.7,across * 52.0))-0.5;
	float pores = smoothstep(0.72,0.92,timber_noise(fibre_uv * vec2(4.0,1.3))) * filtered;
	ALBEDO = timber_tint.rgb * (0.98 + grain * 0.10 + broad * 0.10 - pores * 0.06);
	ROUGHNESS = 0.49 + pores * 0.06 - grain * 0.025;
	SPECULAR = 0.32;

}
else if (garage_finish_family==4) {

 vec3 p=stone_position;
 float bend=sin(p.x*2.7+p.z*1.8+sin(p.y*1.7))*0.35+sin(p.y*4.3+p.z*3.1)*0.16+sin(p.z*9.0+p.y*7.1)*0.035;
 float vein=abs(sin((p.z*0.73+p.y*0.86+p.x*0.31+bend)*4.0));
 float aa=max(fwidth(vein),0.012);
 float line=1.0-smoothstep(0.025,0.025+aa*1.7,vein);
 float cloud=stone_noise(p*1.6);
 ALBEDO=mix(stone_dark.rgb,stone_light.rgb,cloud);
 ALBEDO=mix(ALBEDO,stone_vein.rgb,line*0.30);
 ROUGHNESS=wall_reflections_enabled ? 0.18+cloud*0.07 : 0.32+cloud*0.10;
 METALLIC=0.0;
 SPECULAR=0.48;
 // Bounded analytic reflections of the actual alcove and roof light layout.
 // Environment radiance remains the broader native material reflection.
 if (wall_reflections_enabled) {
  vec3 eye=normalize(INV_VIEW_MATRIX[3].xyz-p);
  vec3 n=normalize(stone_normal);
  vec3 ray=reflect(-eye,n);
  float sheen=0.045+0.20*pow(1.0-clamp(dot(n,eye),0.0,1.0),5.0);
  float highlights=0.0;
  if (ray.y>0.001) {
   float distance=(3.485-p.y)/ray.y;
   if (distance>0.0) {
    vec3 hit=p+ray*distance;
    for (int i=0;i<3;i++) {
     vec2 delta=hit.xz-vec2(-9.72,0.1+float(i)*2.7);
     float radius=0.065+distance*0.025;
     highlights+=exp(-dot(delta,delta)/(radius*radius))*0.85;
    }
   }
   distance=(5.48-p.y)/ray.y;
   if (distance>0.0) {
    vec3 hit=p+ray*distance;
    for (int i=0;i<3;i++) {
     float z=i==0 ? 1.0 : (i==1 ? 5.5 : 8.3);
     vec2 delta=abs(hit.xz-vec2(0.0,z));
     vec2 blur=vec2(0.10+distance*0.035);
     vec2 band=1.0-smoothstep(vec2(3.25,0.17),vec2(3.25,0.17)+blur,delta);
     highlights+=band.x*band.y*0.6;
    }
   }
  }
  EMISSION=vec3(1.0,0.88,0.65)*min(highlights,1.5)*sheen;
 }

}
else if (garage_finish_family==5) {

	float across = abs(UV.x*2.0-1.0);
	float footprint = max(fwidth(UV.x),fwidth(UV.y));
	float detail = 1.0-smoothstep(0.012,0.055,footprint);
	float midrib = 1.0-smoothstep(0.008+footprint,0.025+footprint,across);
	float vein_position = UV.y*12.0-across*2.8;
	float vein_distance = abs(fract(vein_position+0.5)-0.5);
	float veins = (1.0-smoothstep(0.015,0.045+footprint*12.0,vein_distance))*detail;
	float edge = smoothstep(0.84,1.0,across)*0.055;
	float variation = COLOR.r*(0.91+0.09*sin(UV.y*3.14159));
	vec3 pigment = leaf_color.rgb*variation;
	pigment = mix(pigment,pigment*vec3(1.22,1.08,0.84),COLOR.b*0.22);
	pigment *= mix(1.10,1.0,COLOR.g);
	ALBEDO = pigment*(1.0+midrib*0.13+veins*0.055+edge);
	ROUGHNESS = mix(0.71,0.46,COLOR.g)+veins*0.025;
	SPECULAR = 0.32;

}
else if (garage_finish_family==6) {

	float radius = length(local_vertex.xz);
	float phase = radius * 3200.0;
	float groove = 0.5 + 0.5 * cos(phase);
	float filtered = mix(groove, 0.5, smoothstep(0.5, 2.0, fwidth(phase)));
	float recorded = smoothstep(0.049, 0.055, radius) * (1.0 - smoothstep(0.145, 0.151, radius));
	ALBEDO = vec3(0.013, 0.018, 0.020) + filtered * recorded * 0.014;
	METALLIC = 0.15;
	SPECULAR = 0.62;
	ROUGHNESS = mix(0.23, 0.34, filtered * recorded);

}
}
