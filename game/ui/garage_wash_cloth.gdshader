shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 pigment : source_color = vec4(0.443,0.561,0.584,1.0);
uniform bool cuff = false;
varying vec3 local_point;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float grain(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
void vertex() { local_point = VERTEX; }
void fragment() {
	vec2 weave_uv = cuff ? UV*vec2(48.0,12.0) : local_point.xz*720.0;
	float resolved = 1.0-smoothstep(0.35,1.6,length(fwidth(weave_uv)));
	float weave = (grain(weave_uv)*0.55+sin(weave_uv.x*6.28)*sin(weave_uv.y*6.28)*0.15-0.28)*resolved;
	float nap = grain(local_point.xz*46.0)-0.5;
	float seam = cuff ? (1.0-smoothstep(0.035,0.08,abs(UV.y-0.18)))*smoothstep(0.16,0.32,fract(UV.x*24.0))*(1.0-smoothstep(0.70,0.84,fract(UV.x*24.0))) : 0.0;
	ALBEDO = mix(pigment.rgb*(1.0+weave*0.16+nap*0.10),vec3(0.43,0.48,0.45),seam*0.85);
	ROUGHNESS = cuff ? 0.88 : 0.96;
	SPECULAR = 0.18;
	// Filter the fibre nap before its small physical shading-normal perturbation.
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL), r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	NORMAL = normalize(max(abs(determinant),0.000001)*NORMAL-sign(determinant)*(dFdx(weave)*r1+dFdy(weave)*r2)*0.00045);
}
