shader_type spatial;
render_mode diffuse_toon, specular_schlick_ggx;
varying vec3 position_world;
float grain(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { position_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = position_world.xz;
	float g = grain(floor(p*120.0));
	vec2 panel = abs(fract((p+vec2(2.0,0.0))/4.0)-0.5);
	float join = smoothstep(0.497,0.499,max(panel.x,panel.y));
	float apron = 1.0-smoothstep(4.2,9.0,length(p));
	ALBEDO = mix(vec3(0.075,0.09,0.10),vec3(0.15,0.17,0.18),apron)*(0.994+g*0.012)*(1.0-join*0.22);
	ROUGHNESS = 0.83;
	METALLIC = 0.12;
}
