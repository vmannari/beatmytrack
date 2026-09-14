// Original world-space pigment pattern. Derivative filtering limits distant shimmer.
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
	float fine = pigment(p * vec2(18.0, 3.0));
	float visibility = 1.0 - smoothstep(0.05,0.22,length(fwidth(p)));
	if (road) {
		return base * (0.96 + broad * 0.08 + (fine-0.5)*0.055*visibility);
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
