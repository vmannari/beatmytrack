shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D concrete_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 walkway_bounds = vec4(-54.0,-36.0,-48.0,-22.0);
varying vec2 floor_point;
varying vec3 surface_normal;
void vertex() {
	floor_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec2 p = floor_point;
	vec4 body = texture(concrete_map,p*0.45);
	vec4 broad = texture(concrete_map,mat2(vec2(0.8,-0.6),vec2(0.6,0.8))*p*0.027+vec2(0.31,0.67));
	vec4 pores = texture(concrete_map,p*1.6+vec2(0.17,0.43));
	float variation = (body.b-0.5)*0.065+(broad.b-0.5)*0.025+(pores.b-0.5)*0.012;
	vec2 slab = vec2(6.0,8.0);
	vec2 panel = (p+vec2(0.0,2.0))/slab;
	vec2 joint = (0.5-abs(fract(panel)-0.5))*slab;
	float aa = max(fwidth(p.x),fwidth(p.y))*0.65;
	float seam = 1.0-smoothstep(0.015-aa,0.035+aa,min(joint.x,joint.y));
	float panel_tone = (fract(sin(dot(floor(panel),vec2(127.1,311.7)))*43758.5453)-0.5)*0.014;
	float walkway = step(walkway_bounds.x,p.x)*step(p.x,walkway_bounds.z)*step(walkway_bounds.y,p.y)*step(p.y,walkway_bounds.w);
	float edge_bays = smoothstep(27.8,28.0,abs(p.y));
	float central_bays = (1.0-smoothstep(7.0,7.2,abs(p.y)))*smoothstep(2.5,3.0,p.x);
	float epoxy = max(edge_bays,central_bays)*(1.0-walkway);
	vec3 concrete = mix(vec3(0.225,0.235,0.226),vec3(0.175,0.225,0.205),epoxy*0.75);
	float wear = exp(-pow((abs(p.y)-18.0)/2.8,2.0))*smoothstep(0.25,0.65,broad.b)*0.015;
	vec3 pigment = clamp(concrete + variation*mix(1.0,0.60,epoxy) + panel_tone - seam*0.060 - wear,vec3(0.10),vec3(0.34));
	// Authored pigments are sRGB; Mobile shades in linear colour space.
	if (!OUTPUT_IS_SRGB) pigment = mix(pigment/12.92,pow((pigment+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),pigment));
	ALBEDO = pigment;
	vec2 slope = (body.rg*2.0-1.0)*0.10+(pores.rg*2.0-1.0)*0.04;
	vec3 normal_world = normalize(vec3(slope.x,1.0,slope.y));
	NORMAL = normalize((VIEW_MATRIX*vec4(mix(surface_normal,normal_world,step(0.5,surface_normal.y)),0.0)).xyz);
	ROUGHNESS = clamp(body.a-epoxy*0.045,0.76,0.97);
	SPECULAR = 0.18;
}
