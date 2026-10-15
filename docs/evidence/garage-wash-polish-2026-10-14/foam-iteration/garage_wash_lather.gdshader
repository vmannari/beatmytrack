shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 soap_color : source_color = vec4(0.94,0.96,0.91,1.0);
varying vec4 patch;
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453); }
float cells(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	float nearest = 2.0;
	for (int y=-1; y<=1; y++) {
		for (int x=-1; x<=1; x++) {
			vec2 o = vec2(float(x),float(y));
			vec2 d = o+hash2(cell+o)-f;
			nearest = min(nearest,dot(d,d));
		}
	}
	return sqrt(nearest);
}
void vertex() { patch = INSTANCE_CUSTOM; }
void fragment() {
	vec2 p = UV*2.0-1.0;
	float distance = length(p);
	float lobes = 0.88+0.06*sin(atan(p.y,p.x)*7.0+patch.x*20.0);
	float border = 1.0-smoothstep(lobes-0.22,lobes,distance);
	float resolved = 1.0-smoothstep(0.10,0.36,length(fwidth(p)));
	float bubble = cells(p*3.2+patch.x*17.0);
	float rim = smoothstep(0.18,0.40,bubble);
	float lather = mix(0.55,rim,resolved);
	float age = (1.0-smoothstep(0.24,1.0,patch.y))*smoothstep(0.0,0.12,patch.y);
	float depth = textureLod(scene_depth,SCREEN_UV,0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,depth)*2.0-1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,depth);
	#endif
	vec4 scene = INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	float separation = -scene.z/scene.w+VERTEX.z;
	// Lather hugs opaque car surfaces and cannot draw a floating halo at their edge.
	float seated = 1.0-smoothstep(0.008,0.028,separation);
	ALPHA = border*age*seated*patch.z*(0.12+lather*0.65);
	if (ALPHA < 0.004) { discard; }
	ALBEDO = soap_color.rgb*(0.93+lather*0.07);
	ROUGHNESS = mix(0.16,0.61,lather);
	SPECULAR = 0.46;
	float height = (1.0-bubble*bubble)*resolved;
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL), r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	NORMAL = normalize(max(abs(determinant),0.000001)*NORMAL-sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2)*0.0009);
}
