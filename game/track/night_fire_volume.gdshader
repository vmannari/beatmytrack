shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://track/shadow_depth.gdshaderinc"
uniform sampler3D flow_noise : repeat_enable, filter_linear;
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
uniform float elapsed=0.0;
varying vec3 local_surface;
varying mat4 world_to_volume;
varying float source_seed;
varying float source_spill;
varying float source_energy;
void vertex() {
	local_surface=VERTEX;
	world_to_volume=inverse(MODEL_MATRIX);
	source_seed=INSTANCE_CUSTOM.x;
	source_spill=INSTANCE_CUSTOM.y;
	source_energy=INSTANCE_CUSTOM.z;
}
vec4 combustion(vec3 p) {
	float h=p.y+0.5;
	vec3 flow=p*mix(vec3(0.115,0.145,0.115),vec3(0.23,0.145,0.23),source_spill)+vec3(source_seed*0.73,-elapsed*0.115,source_seed*0.39);
	vec3 coarse=texture(flow_noise,flow).rgb;
	float fine=texture(flow_noise,flow*3.17+vec3(0.17,-elapsed*0.057,0.31)).a;
	vec2 centre=(coarse.gb-0.5)*(0.17+0.25*h);
	float radius=length((p.xz-centre)*2.0);
	float envelope=0.84*pow(max(0.0,1.0-h),0.80)+0.025;
	// Spilled fuel breaks into lower, irregular burning patches across the floor.
	envelope*=mix(1.0,0.42+coarse.g*0.72+fine*0.18,source_spill);
	float turbulence=(coarse.r-0.5)*0.72+(fine-0.5)*0.52;
	float body=envelope-radius+turbulence;
	float ground_body=min(0.9-radius,(coarse.r-0.30)*1.7+(fine-0.5)*0.48-h*0.70);
	body=mix(body,ground_body,source_spill);
	float density=smoothstep(0.025,0.14,body)*(0.65+max(body,0.0))*smoothstep(0.0,0.07,h)*(1.0-smoothstep(0.91,1.0,h));
	float heat=clamp(body*1.65+(1.0-h)*0.20+fine*0.07,0.0,1.0);
	vec3 colour=mix(vec3(0.91,0.055,0.002),vec3(1.0,0.46,0.045),smoothstep(0.10,0.60,heat));
	colour=mix(colour,vec3(1.0,0.94,0.64),smoothstep(0.70,1.0,heat));
	return vec4(colour,density);
}
void fragment() {
	if(source_energy<=0.0001) discard;
	vec3 forward=(INV_VIEW_MATRIX*vec4(0.0,0.0,-1.0,0.0)).xyz;
	vec3 ray=normalize((world_to_volume*vec4(forward,0.0)).xyz);
	if(PROJECTION_MATRIX[3][3]<0.5) {
		vec3 camera=(world_to_volume*INV_VIEW_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
		ray=normalize(local_surface-camera);
	}
	vec3 origin=clamp(local_surface+ray*0.0005,vec3(-0.4999),vec3(0.4999));
	vec3 safe_ray=mix(vec3(0.00001),ray,step(vec3(0.00001),abs(ray)));
	vec3 distances=max((-vec3(0.5)-origin)/safe_ray,(vec3(0.5)-origin)/safe_ray);
	float length_inside=min(distances.x,min(distances.y,distances.z));
	float scene_depth=texture(depth_map,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	bool has_surface=scene_depth<0.999999;
#else
	bool has_surface=scene_depth>0.000001;
#endif
	if(has_surface) {
		vec3 opaque=shadow_world_position(depth_map,SCREEN_UV,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
		float until_opaque=dot((world_to_volume*vec4(opaque,1.0)).xyz-origin,ray);
		length_inside=max(0.0,min(length_inside,until_opaque));
	}
	float step_length=length_inside/32.0;
	vec3 sum=vec3(0.0); float coverage=0.0;
	for(int i=0;i<32;i++) {
		vec4 sample_fire=combustion(origin+ray*(float(i)+0.5)*step_length);
		float amount=1.0-exp(-sample_fire.a*step_length*9.0);
		sum+=(1.0-coverage)*sample_fire.rgb*amount;
		coverage+=(1.0-coverage)*amount;
	}
	vec3 colour=sum/max(coverage,0.0001);
	if(!OUTPUT_IS_SRGB) colour=mix(colour/12.92,pow((colour+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),colour));
	ALBEDO=colour; EMISSION=colour*0.65; ALPHA=coverage*source_energy;
}
