shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 soap_color : source_color = vec4(0.99,0.985,0.965,1.0);
varying vec4 patch;
varying float air;
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
void vertex() { patch = INSTANCE_CUSTOM; air = COLOR.r; }
void fragment() {
	vec2 p = UV*2.0-1.0;
	float distance = length(p);
	float border = 1.0-smoothstep(0.66,1.0,distance);
	float resolved = 1.0-smoothstep(0.35,1.5,length(fwidth(p*7.0)));
	float bubble = cells(p*7.0+patch.x*17.0);
	// Fine aeration stays a quiet surface texture; dense lather has no dark holes.
	float aeration = smoothstep(0.18,0.46,bubble)*resolved;
	float edge = smoothstep(0.42,0.95,distance);
	float age = (1.0-smoothstep(0.30,1.0,patch.y))*smoothstep(0.0,0.09,patch.y);
	float depth = textureLod(scene_depth,SCREEN_UV,0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,depth)*2.0-1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,depth);
	#endif
	vec4 scene = INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	float separation = -scene.z/scene.w+VERTEX.z;
	// Lather hugs opaque car surfaces and cannot draw a floating halo at their edge.
	float seated = 1.0-smoothstep(0.015,0.040,separation);
	ALPHA = border*age*seated*patch.z*(0.91-edge*aeration*0.16)*(1.0-air*0.18);
	if (ALPHA < 0.004) { discard; }
	ALBEDO = soap_color.rgb*(0.96+air*0.04+aeration*0.012);
	ROUGHNESS = mix(0.63-edge*aeration*0.20,0.23,air);
	SPECULAR = mix(0.30+edge*aeration*0.10,0.48,air);
	float height = (1.0-bubble*bubble)*resolved;
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL), r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	NORMAL = normalize(max(abs(determinant),0.000001)*NORMAL-sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2)*0.00016);
}
