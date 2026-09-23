uniform bool icy_road = false;
uniform bool wet_road = false;
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
// Shared broken, short grass fringe for road shoulders and painted terrain.
float grass_fringe(float coverage, vec2 p) {
	return smoothstep(0.55,0.98,coverage+(pigment(p*5.0)-0.5)*0.32);
}
// Matte sand shared by terrain paint and roadside shoulders. Grain is
// isotropic (no grass-like diagonal strokes), with filtered fine minerals.
vec3 sand_detail(vec3 base, vec2 p) {
	float broad = pigment(p*0.65+vec2(8.3,21.7));
	float medium = pigment(p*4.3+vec2(19.2,3.8));
	float grain = pigment(p*19.0);
	float grit = pigment(p*8.7+vec2(31.4,7.1));
	float fine_visibility = 1.0-smoothstep(0.5,1.5,length(fwidth(p*19.0)));
	float grit_visibility = 1.0-smoothstep(0.6,1.6,length(fwidth(p*8.7)));
	float aa = max(0.035,fwidth(grit)*0.65);
	float dark_grit = smoothstep(0.72-aa,0.85+aa,grit);
	float light_grain = smoothstep(0.58,0.82,grain);
	return base*(0.965+(broad-0.5)*0.045+(medium-0.5)*0.045
		+(grain-0.5)*0.12*fine_visibility
		+light_grain*0.04*fine_visibility-dark_grit*0.16*grit_visibility);
}
vec3 surface_detail(vec3 base, vec2 p, bool road) {
	float visibility = 1.0 - smoothstep(0.05,0.22,length(fwidth(p)));
	if (road && wet_road) {
		float sheen = smoothstep(0.48,0.75,pigment(p*0.24 + vec2(3.2,7.6)));
		return mix(base,base*1.22+vec3(0.035,0.045,0.055),sheen*0.45);
	}
	if (road && icy_road) {
		float frost = pigment(p * 0.7);
		float streak = pow(0.5 + 0.5 * sin(p.x * 2.3 + pigment(p * 0.2) * 9.0), 18.0);
		return mix(base * (0.91 + frost * 0.12), vec3(0.62,0.74,0.82), streak * 0.14);
	}
	if (road) {
		// Fine mineral flecks in an even binder, not broad soft noise blobs.
		// Two sizes break up a regular grain pattern; filter toward each
		// layer's average when the flecks fall below a screen pixel.
		float grain = pigment(p * 12.0);
		float aa = max(0.035,fwidth(grain)*0.65);
		float mineral = smoothstep(0.57-aa,0.57+aa,grain);
		float pores = 1.0-smoothstep(0.30-aa,0.30+aa,grain);
		float fine_visibility = 1.0-smoothstep(0.8,1.8,length(fwidth(p*12.0)));
		float coarse = pigment(p * 3.7 + vec2(27.1,13.7));
		float coarse_aa = max(0.035,fwidth(coarse)*0.65);
		float chips = smoothstep(0.72-coarse_aa,0.72+coarse_aa,coarse);
		float chip_visibility = 1.0-smoothstep(0.8,1.8,length(fwidth(p*3.7)));
		return base * (1.0 + ((mineral-0.32)*0.032-(pores-0.14)*0.018)*fine_visibility
			+ (chips-0.08)*0.008*chip_visibility);
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
	// Cool neutral palettes use snow/concrete grain without green brush pigment.
	if (base.b > base.r * 0.95) return base * (0.94 + pigment(p * 0.7) * 0.06);
	// A 20 m tile gives legible brush clusters at driving scale. An offset
	// second sample and slower colour mask soften recognizable repetition.
	vec3 paint = texture(painted_grass_texture,p/20.0,0.75).rgb;
	vec3 broad = texture(painted_grass_texture,p/47.0+vec2(0.37,0.61),1.0).rgb;
	vec3 tint = base / vec3(0.3765,0.4196,0.2118);
	return mix(mix(paint,broad,0.18)*tint,base,0.18)*(0.82+pigment(p*0.08)*0.10);
}