// Original world-space pigment pattern. Derivative filtering limits distant shimmer.
uniform sampler2D painted_grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
float pigment(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec3 a = fract(vec3(cell.xyx) * 0.1031);
	a += dot(a, a.yzx + 33.33);
	float n00 = fract((a.x + a.y) * a.z);
	a = fract(vec3((cell + vec2(1,0)).xyx) * 0.1031); a += dot(a,a.yzx+33.33);
	float n10 = fract((a.x+a.y)*a.z);
	a = fract(vec3((cell + vec2(0,1)).xyx) * 0.1031); a += dot(a,a.yzx+33.33);
	float n01 = fract((a.x+a.y)*a.z);
	a = fract(vec3((cell + vec2(1,1)).xyx) * 0.1031); a += dot(a,a.yzx+33.33);
	return mix(mix(n00,n10,f.x),mix(n01,fract((a.x+a.y)*a.z),f.x),f.y);
}
vec3 surface_detail(vec3 base, vec2 p, bool road) {
	float broad = pigment(p * 0.65);
	float fine = pigment(p * 12.0);
	float visibility = 1.0 - smoothstep(0.05,0.22,length(fwidth(p)));
	if (road) {
		return base * (0.96 + broad * 0.08 + (fine-0.5)*0.018*visibility);
	}
	// Sparse short blade strokes rather than circular noise clouds.
	vec2 cell = floor(p * 2.4);
	float seed = fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	float other = fract(sin(dot(cell,vec2(269.5,183.3)))*43758.5453);
	vec2 local = fract(p * 2.4) - vec2(0.25+seed*0.5,0.25+other*0.5);
	float blade = (1.0-smoothstep(0.025,0.09,abs(local.x + local.y*(seed-0.5)*1.5)))
		* smoothstep(-0.35,-0.1,local.y) * (1.0-smoothstep(0.05,0.32,local.y));
	blade *= step(0.72,seed) * visibility;
	float plane = smoothstep(0.35,0.65,pigment(p*0.12));
	return base * (0.97 + plane*0.055 - blade*0.09);
}

vec3 painted_grass(vec3 base, vec2 p) {
	// A 20 m tile gives legible brush clusters at driving scale. An offset
	// second sample and slower colour mask soften recognizable repetition.
	vec3 paint = texture(painted_grass_texture,p/20.0,2.0).rgb;
	vec3 broad = texture(painted_grass_texture,p/47.0+vec2(0.37,0.61),1.0).rgb;
	vec3 tint = base / vec3(0.3765,0.4196,0.2118);
	return mix(mix(paint,broad,0.35)*tint,base,0.62)*(0.82+pigment(p*0.08)*0.10);
}
