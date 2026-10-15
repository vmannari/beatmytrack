shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 leaf_color : source_color = vec4(0.27,0.43,0.23,1.0);
void fragment() {
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
