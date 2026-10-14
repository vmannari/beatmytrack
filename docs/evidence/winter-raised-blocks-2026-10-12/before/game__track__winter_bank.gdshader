shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;
#include "res://track/surface_detail.gdshaderinc"
uniform sampler2D overlay_mask : filter_nearest, repeat_disable;
uniform sampler2D road_mask : filter_nearest, repeat_disable;
uniform vec2 map_extent;
uniform bool smooth_road_bank = false;
varying vec3 world_position;
varying float bank_half_width;
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	bank_half_width = COLOR.r*32.0;
}
void fragment() {
	vec3 snow = snow_detail(world_position.xz);
	ALBEDO = snow;
	if (smooth_road_bank) {
		vec2 map_uv = (world_position.xz+map_extent)/(map_extent*2.0);
		if (texture(overlay_mask,map_uv).r < 0.5) discard;
		// Broad aprons cannot spill across another road at a narrow island/junction.
		if (UV.x > 0.55 && texture(road_mask,map_uv).r > 0.5) discard;
		// Metre-sized tongues plus fine settled grains, using the Grass fringe.
		float breakup = pigment(world_position.xz*0.73+vec2(17.3,8.1))-0.5;
		float deposited = smoothstep(0.0,0.22,UV.x)+breakup*0.60*(1.0-smoothstep(0.12,0.30,UV.x));
		float coverage = shoulder_fringe(mix(0.48,1.06,clamp(deposited,0.0,1.0)),world_position.xz);
		float crest = smoothstep(0.35,0.60,UV.x)*(1.0-smoothstep(0.78,1.0,UV.x));
		vec3 piled = snow*1.07;
		float settled = 1.0-smoothstep(0.56,0.85,UV.x);
		ALBEDO = mix(snow,piled,crest*settled);
		// Coherent snow-only strips do not need any of the ice/finish samples.
		if (coverage < 0.999) {
			vec3 ice = winter_wear_width(UV2,world_position.xz,max(bank_half_width,1.0));
			ALBEDO = mix(ice,ALBEDO,coverage);
		}
	}
	ROUGHNESS = 1.0;
}
