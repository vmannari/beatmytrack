shader_type spatial;
render_mode diffuse_lambert, cull_back;
varying vec3 stone_position;

float stone_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	vec3 k = vec3(19.19,73.73,31.31);
	float a = fract(sin(dot(i,k))*43758.5453);
	float b = fract(sin(dot(i+vec3(1,0,0),k))*43758.5453);
	float c = fract(sin(dot(i+vec3(0,1,0),k))*43758.5453);
	float d = fract(sin(dot(i+vec3(1,1,0),k))*43758.5453);
	float e = fract(sin(dot(i+vec3(0,0,1),k))*43758.5453);
	float g = fract(sin(dot(i+vec3(1,0,1),k))*43758.5453);
	float h = fract(sin(dot(i+vec3(0,1,1),k))*43758.5453);
	float j = fract(sin(dot(i+vec3(1,1,1),k))*43758.5453);
	return mix(mix(mix(a,b,f.x),mix(c,d,f.x),f.y),mix(mix(e,g,f.x),mix(h,j,f.x),f.y),f.z);
}
void vertex() {
	stone_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec3 pigment = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) pigment = mix(pigment/12.92,pow((pigment+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),pigment));
	float broad = stone_noise(stone_position*2.3);
	float footprint = length(fwidth(stone_position));
	float fine_fade = 1.0-smoothstep(0.008,0.06,footprint);
	float pores = stone_noise(stone_position*57.0);
	float bands = sin(stone_position.y*36.0+broad*3.0)*0.012*(1.0-smoothstep(0.02,0.12,footprint));
	float weather = (broad-0.5)*0.09+(pores-0.5)*0.10*fine_fade+bands;
	ALBEDO = pigment*(1.0+weather);
	ROUGHNESS = 0.91+(pores-0.5)*0.06*fine_fade;
	SPECULAR = 0.16;
	// Screen-filtered mineral relief fades out before it can shimmer in motion.
	vec3 perturb = vec3(dFdx(pores),dFdy(pores),0.0)*0.07*fine_fade;
	NORMAL = normalize(NORMAL+perturb);
}
