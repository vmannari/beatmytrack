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
	float patches = floor(pigment(p*2.2)*4.0)/3.0;
	return base * (0.89 + broad*0.14 + patches*0.075*visibility);
}
