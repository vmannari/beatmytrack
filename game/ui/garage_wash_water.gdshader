shader_type spatial;
render_mode blend_mix, depth_draw_never, diffuse_burley, specular_schlick_ggx;
uniform vec4 water_color : source_color = vec4(0.72,0.83,0.84,1.0);
varying vec4 drop;
void vertex() { drop = INSTANCE_CUSTOM; }
void fragment() {
	float rim = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
	float fade = (1.0-smoothstep(0.40,1.0,drop.y))*smoothstep(0.0,0.10,drop.y);
	ALBEDO = water_color.rgb;
	ROUGHNESS = 0.085;
	SPECULAR = 0.64;
	METALLIC = 0.0;
	ALPHA = fade*(0.18+rim*0.48);
}
