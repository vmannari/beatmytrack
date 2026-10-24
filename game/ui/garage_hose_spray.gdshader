shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, world_vertex_coords;
uniform float flow = 0.0;
uniform vec3 source;
uniform vec3 target;
uniform vec3 spread_x;
uniform vec3 spread_z;
uniform float droplet_scale = 1.0;
varying float opacity;
varying float sparkle;
void vertex() {
	vec4 seed = INSTANCE_CUSTOM;
	float lifetime = 0.20+seed.z*0.085;
	float cycle = floor(flow/lifetime+seed.y);
	float phase = fract(flow/lifetime+seed.y);
	float angle = seed.x*6.2831853+cycle*2.399963;
	float radial = sqrt(fract(seed.w+cycle*0.381966));
	vec3 end = target+(spread_x*cos(angle)+spread_z*sin(angle))*radial;
	vec3 gravity = vec3(0.0,-9.0,0.0);
	vec3 velocity = (end-source)/lifetime-gravity*lifetime*0.5;
	float age = phase*lifetime;
	vec3 at = source+velocity*age+gravity*age*age*0.5;
	vec3 motion = velocity+gravity*age;
	vec3 facing = INV_VIEW_MATRIX[2].xyz;
	vec3 projected = motion-facing*dot(motion,facing);
	vec3 along = length(projected)>0.001 ? normalize(projected) : INV_VIEW_MATRIX[1].xyz;
	vec3 across = normalize(cross(along,facing));
	float width = (0.006+seed.z*0.007)*droplet_scale;
	float streak = (0.018+seed.w*0.026)*droplet_scale;
	VERTEX = at+across*(UV.x-0.5)*width+along*(UV.y-0.5)*streak;
	opacity = smoothstep(0.0,0.05,phase)*(1.0-smoothstep(0.88,1.0,phase));
	sparkle = seed.z;
}
void fragment() {
	vec2 p = (UV-0.5)*2.0;
	float core = 1.0-smoothstep(0.20,1.0,dot(p,p));
	ALBEDO = mix(vec3(0.46,0.66,0.73),vec3(0.96,0.99,0.99),sparkle);
	ALPHA = core*opacity*(0.34+sparkle*0.38);
}
