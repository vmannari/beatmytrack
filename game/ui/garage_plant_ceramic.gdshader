shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 clay_color : source_color = vec4(0.47,0.49,0.44,1.0);
varying vec3 clay_position;
void vertex() {
	// World coordinates also survive the room's immutable mesh batching.
	clay_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec3 p = clay_position;
	float footprint = length(fwidth(p));
	float fine = (sin(p.x*731.0+p.y*31.0)*sin(p.z*683.0-p.y*827.0))*0.5;
	fine *= 1.0-smoothstep(0.001,0.006,footprint);
	float mottle = sin(p.x*23.0+sin(p.z*17.0))*sin(p.y*27.0+p.z*12.0);
	ALBEDO = clay_color.rgb*(1.0+mottle*0.018+fine*0.025);
	ROUGHNESS = 0.68+mottle*0.025+fine*0.07;
	SPECULAR = 0.3;
}
