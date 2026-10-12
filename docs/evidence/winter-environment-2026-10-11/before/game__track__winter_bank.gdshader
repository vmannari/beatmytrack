shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;
#include "res://track/winter_ice.gdshaderinc"
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ice_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D overlay_mask : filter_nearest, repeat_disable;
uniform vec2 map_extent;
uniform bool smooth_road_bank = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 snow = mix(texture(snow_albedo,world_position.xz/11.0).rgb,texture(snow_albedo,vec2(-world_position.z,world_position.x)/19.0+vec2(0.31,0.57)).rgb,0.22)*vec3(0.69,0.70,0.72);
	ALBEDO = snow;
	if (smooth_road_bank) {
		vec2 map_uv = (world_position.xz+map_extent)/(map_extent*2.0);
		if (texture(overlay_mask,map_uv).r < 0.5) discard;
		vec3 ice = quiet_winter_ice(texture(ice_albedo,UV2.yx/vec2(5.0,9.0)).rgb);
		float powder = texture(snow_albedo,world_position.xz/4.0).r;
		float coverage = smoothstep(0.0,0.68,UV.x+(powder-0.65)*0.12*sin(UV.x*3.14159));
		float crest = smoothstep(0.35,0.60,UV.x)*(1.0-smoothstep(0.78,1.0,UV.x));
		vec3 piled = texture(snow_albedo,world_position.xz/4.0).rgb*vec3(0.83,0.83,0.84);
		ALBEDO = mix(ice,mix(snow,piled,crest*0.70),coverage);
	}
	ROUGHNESS = 1.0;
}
