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




#include "res://vehicle/livery_finish.gdshaderinc"

// Original opaque finish: no overlay geometry, transparency or screen reads.
uniform vec4 paint_color : source_color = vec4(1.0);
uniform vec4 deposit_color : source_color = vec4(0.65, 0.5, 0.3, 1.0);
uniform float paint_roughness = 0.38;
uniform float paint_metallic = 0.12;
uniform float paint_specular = 0.35;
uniform float paint_clearcoat = 0.22;
uniform float paint_clearcoat_roughness = 0.3;
uniform float amount = 0.0;
uniform float wetness = 0.0;
uniform float snow = 0.0;
uniform float slow_amount = 0.0;
uniform float slow_snow = 0.0;
uniform float mud = 0.0;
uniform float smudge = 0.0;
uniform sampler2D wash_volume : filter_linear, repeat_disable;
uniform sampler2D slow_wash_volume : filter_linear, repeat_disable;
uniform vec3 wash_min;
uniform vec3 wash_size = vec3(1.0);
uniform float roof_height = 1.5;
uniform float axle_half = 1.28;
uniform float wheel_half_span = 0.83;
uniform float wheel_radius = 0.37;
uniform float rear_only = 0.0;
uniform float wheel_surface = 0.0;
uniform mat4 mesh_to_wheel;
uniform mat4 mesh_to_body;
varying vec3 body_point;
varying vec3 body_normal;
varying vec3 wheel_point;

float weather_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float weather_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(weather_hash(cell), weather_hash(cell + vec3(1,0,0)), f.x),
		mix(weather_hash(cell + vec3(0,1,0)), weather_hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(weather_hash(cell + vec3(0,0,1)), weather_hash(cell + vec3(1,0,1)), f.x),
		mix(weather_hash(cell + vec3(0,1,1)), weather_hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

float wheel_spray(vec3 p, float axle) {
	// A tire throws debris rearward/upward. The plume widens with distance;
	// both axles leave their own tapered fan rather than a random body stain.
	float behind = p.z - axle;
	float distance = max(behind, 0.0);
	float rise = wheel_radius * 0.75 + distance * 0.32;
	float width = wheel_radius * 0.48 + distance * 0.20;
	float fan = 1.0 - smoothstep(width * 0.25, width, abs(p.y - rise));
	float reach = smoothstep(-0.12, wheel_radius * 0.6, behind) * (1.0 - smoothstep(axle_half * 2.2, axle_half * 3.0, distance));
	return fan * reach;
}

float road_specks(vec2 p) {
	// Individual irregular splash droplets, rather than broad cloudy stains.
	vec2 cell = floor(p);
	vec2 centre = vec2(weather_hash(vec3(cell, 2.1)), weather_hash(vec3(cell, 7.3)));
	centre = vec2(0.5) + (centre - vec2(0.5)) * 0.66;
	float size = 0.055 + weather_hash(vec3(cell, 11.7)) * 0.27;
	float edge = length(fract(p) - centre) / size;
	float cluster = 0.5 + weather_hash(vec3(floor(cell * 0.25), 19.4)) * 0.5;
	float droplet = (1.0 - smoothstep(0.58, 1.0, edge)) * cluster;
	// Subpixel droplets become their average density instead of flickering
	// as the normal driving camera moves across the very fine splash field.
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	return mix(droplet, 0.10 * cluster, smoothstep(0.45, 1.25, footprint));
}



float wash_mask(vec3 point, sampler2D volume) {
	vec3 p = clamp((point - wash_min) / wash_size, vec3(0.0), vec3(1.0)) * 15.0;
	float slice = floor(p.z);
	vec2 uv = vec2((slice * 16.0 + p.x + 0.5) / 256.0, (p.y + 0.5) / 16.0);
	vec2 next_uv = vec2((min(slice + 1.0, 15.0) * 16.0 + p.x + 0.5) / 256.0, uv.y);
	return 1.0 - mix(texture(volume, uv).r, texture(volume, next_uv).r, fract(p.z));
}






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
else if (garage_finish_family==7) {

	body_point = (mesh_to_body * vec4(VERTEX, 1.0)).xyz;
	body_normal = normalize(mat3(mesh_to_body) * NORMAL);
	wheel_point = (mesh_to_wheel * vec4(VERTEX, 1.0)).xyz;

}
else if (garage_finish_family==8) {

	body_point = (mesh_to_body * vec4(VERTEX,1.0)).xyz;
	body_normal = normalize(mat3(mesh_to_body)*NORMAL);

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
else if (garage_finish_family==7) {

	vec3 n = normalize(body_normal);
	float remaining = wash_mask(body_point, wash_volume);
	float slow_remaining = wash_mask(body_point, slow_wash_volume);
	float side = abs(n.x);
	float upward = max(n.y, 0.0);
	// +Z is the authored rear, independent of camera or which side is seen.
	// Tire spray rises first, then flattens near the rear axle and begins
	// settling toward the tail. End panels use a lateral projection.
	float end_projection = smoothstep(0.40, 0.85, abs(n.z));
	float along = mix(body_point.z, body_point.x, end_projection);
	float rear_run = max(0.0, body_point.z + axle_half);
	float curved_rise = 0.40 * rear_run - 0.10 * rear_run * rear_run / max(axle_half, 0.25);
	float across = body_point.y - curved_rise * (1.0 - end_projection);
	vec3 flow_point = vec3(mix(body_point.x, body_point.z, end_projection), across, along);
	float mottling = weather_noise(flow_point * vec3(18.0, 26.0, 6.0));
	vec2 splash_point = vec2(along, across);
	float fine_specks = road_specks(splash_point * vec2(58.0, 150.0));
	float coarse_specks = road_specks(splash_point * vec2(11.0, 58.0) + vec2(8.2, 3.7));
	float speckles = max(fine_specks, coarse_specks * 0.90);
	float front_spray = wheel_spray(body_point, -axle_half);
	float rear_spray = wheel_spray(body_point, axle_half);
	float spray = max(front_spray, rear_spray);
	float near_wheels = smoothstep(wheel_half_span * 0.24, wheel_half_span * 0.80, abs(body_point.x));
	float side_spray = spray * near_wheels * (0.55 + side * 0.45);
	// The wake recirculates rear-wheel spray over the tailgate and bumper,
	// including their centre where the lateral tire fans do not reach.
	float rear_face = smoothstep(0.20, 0.75, n.z) * smoothstep(axle_half * 0.85, axle_half * 1.18, body_point.z);
	float road_film = 1.0 - smoothstep(wheel_radius * 1.1, min(roof_height * 0.58, wheel_radius * 2.4), body_point.y);
	float upper_fade = 1.0 - smoothstep(roof_height * 0.53, roof_height * 0.72, body_point.y);
	float rear_wake = rear_face * (0.26 + road_film * 0.69);
	// Reference-led dense sill/lower-door band. Fine splash scatter becomes
	// sparse upward, with the existing diagonal fans raising it behind tires.
	float side_band = near_wheels * (0.65 + side * 0.35) * road_film * 0.94;
	float coverage = clamp(max(side_band, side_spray * 0.72) * upper_fade, 0.0, 1.0);
	coverage = mix(max(coverage, rear_wake), rear_wake, rear_only);
	// Wheel batches may share tire rubber and rim spokes. Coat only the inner
	// radial area; authored wheel coordinates rotate the dirt with the rim.
	float rim_coverage = 1.0 - smoothstep(wheel_radius * 0.67, wheel_radius * 0.81, length(wheel_point.yz));
	coverage = mix(coverage, rim_coverage, wheel_surface);
	road_film = mix(road_film, 0.85, wheel_surface);
	float surface_wetness = wetness * mix(1.0, rear_face, rear_only);
	float streaks = weather_noise(flow_point * vec3(18.0, 40.0, 3.5));
	float texture_weight = mix(mottling, streaks, max(surface_wetness * 0.45, smudge * 0.85));
	float film = (0.24 + road_film * 0.68) * (0.68 + texture_weight * 0.40) * (1.0 + mud * 0.65);
	float splashes = speckles * (0.42 + road_film * 0.34);
	float deposit = clamp(amount * coverage * (film + splashes + smudge * streaks * 0.35) * remaining, 0.0, 0.94);
	float slow_scope = mix(1.0, rear_face, rear_only) * (1.0 - wheel_surface);
	float slow_deposit = slow_amount * (1.0 - coverage) * slow_scope * (0.42 + mottling * 0.20) * slow_remaining;
	deposit = 1.0 - (1.0 - deposit) * (1.0 - slow_deposit);
	// Dense grains in the lower film are darker than the loose upper dust;
	// Winter retains its snowy palette while using the same deposition shape.
	float grain_darkening = 0.32 * road_film;
	float packed_lower = road_film * (0.20 + mud * 0.25);
	vec3 residue = deposit_color.rgb * (0.87 + mottling * 0.18 - grain_darkening * speckles) * (1.0 - packed_lower);
	vec3 decorated_paint = apply_graphics(paint_color.rgb,body_point,n);
	ALBEDO = mix(decorated_paint * (1.0 - surface_wetness * 0.10), residue, deposit);
	float snow_coat = clamp(snow * max(coverage, upward * 0.38 * (1.0 - rear_only) * (1.0 - wheel_surface)) * (film + splashes) * remaining, 0.0, 0.94);
	snow_coat = 1.0 - (1.0 - snow_coat) * (1.0 - slow_snow * (1.0 - coverage) * slow_scope * 0.38 * slow_remaining);
	ALBEDO = mix(ALBEDO, vec3(0.8627, 0.9098, 0.9294) * (0.87 + mottling * 0.18), snow_coat);
	float icy = snow_coat * smoothstep(0.7, 0.9, speckles);
	deposit = max(deposit, snow_coat);
	ROUGHNESS = mix(paint_roughness, mix(0.90, 0.42, icy), deposit);
	ROUGHNESS = mix(ROUGHNESS, 0.19 + streaks * 0.09, surface_wetness * 0.85);
	METALLIC = paint_metallic * (1.0 - deposit);
	SPECULAR = mix(paint_specular, 0.45, surface_wetness);
	CLEARCOAT = mix(paint_clearcoat * (1.0 - deposit), 0.48, surface_wetness);
	CLEARCOAT_ROUGHNESS = mix(paint_clearcoat_roughness, 0.17, surface_wetness);

}
else if (garage_finish_family==8) {

	ALBEDO = apply_graphics(paint_color.rgb,body_point,normalize(body_normal));
	ROUGHNESS = paint_roughness;
	METALLIC = paint_metallic;
	SPECULAR = paint_specular;
	CLEARCOAT = paint_clearcoat;
	CLEARCOAT_ROUGHNESS = paint_clearcoat_roughness;

}
else { ALBEDO=shared_albedo.rgb; ROUGHNESS=shared_roughness; METALLIC=shared_metallic; SPECULAR=shared_specular; EMISSION=shared_emission.rgb; CLEARCOAT=shared_clearcoat; CLEARCOAT_ROUGHNESS=shared_clearcoat_roughness; }
}
