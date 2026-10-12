shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;
#include "res://track/surface_detail.gdshaderinc"
uniform sampler2D overlay_mask : filter_nearest, repeat_disable;
uniform sampler2D road_mask : filter_nearest, repeat_disable;
uniform vec2 map_extent;
uniform bool smooth_road_bank = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 snow = snow_detail(world_position.xz);
	ALBEDO = snow;
	if (smooth_road_bank) {
		vec2 map_uv = (world_position.xz+map_extent)/(map_extent*2.0);
		if (texture(overlay_mask,map_uv).r < 0.5) discard;
		// Broad aprons cannot spill across another road at a narrow island/junction.
		if (UV.x > 0.55 && texture(road_mask,map_uv).r > 0.5) discard;
		vec3 ice = winter_wear(vec3(0.0),UV2,world_position.xz);
		float powder = texture(snow_albedo,world_position.xz/4.0).r;
		float coverage = smoothstep(0.05,0.42,UV.x+(powder-0.65)*0.08*sin(UV.x*3.14159));
		float crest = smoothstep(0.35,0.60,UV.x)*(1.0-smoothstep(0.78,1.0,UV.x));
		vec3 piled = snow*1.03;
		float settled = 1.0-smoothstep(0.56,0.85,UV.x);
		ALBEDO = mix(ice,mix(snow,piled,crest*settled),coverage);
	}
	ROUGHNESS = 1.0;
}
