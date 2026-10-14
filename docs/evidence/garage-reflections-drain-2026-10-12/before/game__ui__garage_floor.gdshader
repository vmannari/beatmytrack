shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 position_world;
float grain(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float concrete_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(grain(cell),grain(cell+vec2(1.0,0.0)),f.x),mix(grain(cell+vec2(0.0,1.0)),grain(cell+vec2(1.0,1.0)),f.x),f.y);
}
void vertex() { position_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = position_world.xz;
	float g = grain(floor(p*120.0));
	float mottling = concrete_noise(p*1.7)*0.5 + concrete_noise(p*5.3)*0.5;
	vec2 panel = abs(fract((p+vec2(1.5,0.0))/3.0)-0.5);
	float join = smoothstep(0.497,0.499,max(panel.x,panel.y));
	float apron = 1.0-smoothstep(4.2,14.0,length(p));
	float display_pool = exp(-pow((p.x+9.2)/1.15,2.0)-pow((p.y-2.8)/4.5,2.0));
	float wall_pool = exp(-pow((p.y-7.3)/1.7,2.0))*(exp(-pow((p.x-5.0)/1.4,2.0))+exp(-pow((p.x+5.0)/1.4,2.0)));
	ALBEDO = mix(vec3(0.13,0.16,0.18),vec3(0.22,0.24,0.25),apron)*(0.95+g*0.012+mottling*0.09)*(1.0-join*0.32);
	ALBEDO += vec3(0.10,0.065,0.016)*display_pool + vec3(0.035,0.025,0.011)*wall_pool;
	ROUGHNESS = 0.54 + mottling*0.13;
	METALLIC = 0.035;
	vec3 concrete_normal = normalize(vec3(sin(p.x*111.0+p.y*73.0)*0.012,1.0,cos(p.y*95.0+p.x*41.0)*0.012));
	NORMAL = normalize((VIEW_MATRIX * vec4(concrete_normal,0.0)).xyz);
	// Soft analytic reflections of the two actual ceiling luminaires.
	// No screen reads or renderer-specific reflection buffers.
	vec3 reflected = reflect(normalize(position_world-CAMERA_POSITION_WORLD),vec3(0.0,1.0,0.0));
	vec2 ceiling = p + reflected.xz * (5.04-position_world.y) / max(reflected.y,0.02);
	float strip_x = 1.0-smoothstep(2.7,3.6,abs(ceiling.x));
	float strip_z = exp(-pow((ceiling.y+2.0)/0.48,2.0))+exp(-pow((ceiling.y-3.5)/0.48,2.0));
	EMISSION = vec3(0.18,0.15,0.095)*strip_x*strip_z*(0.75+0.25*mottling)*(1.0-join*0.3);
}
