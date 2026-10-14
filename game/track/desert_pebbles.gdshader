shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;
uniform sampler2D surface_factors : filter_linear_mipmap_anisotropic, repeat_enable;
#include "res://track/desert_sun_finish.gdshaderinc"
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	ALBEDO = COLOR.rgb;
	vec3 mineral = texture(surface_factors,world_position.xz/8.0,0.65).rgb;
	// Tagged stone faces catch small mineral highlights; scrub stays matte.
	vec2 finish = mineral_sun_finish(mineral+vec3(0.0,0.0,0.12),length(fwidth(world_position.xz)),UV2.x);
	ROUGHNESS = finish.x;
	SPECULAR = finish.y;
}
