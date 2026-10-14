shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 finish_color : source_color = vec4(0.5,0.5,0.5,1.0);
uniform float finish_metallic = 0.0;
uniform float finish_roughness = 0.6;
uniform int finish_kind = 0;
varying vec3 surface_position;
varying vec3 surface_normal;
float hash_surface(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float surface_noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash_surface(cell),hash_surface(cell+vec2(1,0)),f.x),mix(hash_surface(cell+vec2(0,1)),hash_surface(cell+vec2(1,1)),f.x),f.y);
}
void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 n = abs(surface_normal);
	vec2 uv = n.y > 0.7 ? surface_position.xz : n.x > 0.7 ? surface_position.zy : surface_position.xy;
	float detail = 1.0-smoothstep(0.012,0.050,length(fwidth(uv)));
	float grain = surface_noise(uv*58.0)-0.5;
	float coarse = surface_noise(uv*3.4)-0.5;
	float bump = 0.0018;
	if (finish_kind == 1) { grain = sin(uv.y*340.0+surface_noise(uv*4.0)*3.0)*0.5; bump = 0.0007; }
	if (finish_kind == 2) { grain = surface_noise(uv*90.0)-0.5; bump = 0.0007; }
	if (finish_kind == 3) { grain = surface_noise(uv*35.0)-0.5; bump = 0.0022; }
	if (finish_kind == 4) { grain = sin(uv.x*290.0)*sin(uv.y*290.0)*0.5; bump = 0.0012; }
	if (finish_kind == 5) { grain = surface_noise(uv*72.0)-0.5; bump = 0.0011; }
	grain *= detail;
	ALBEDO = finish_color.rgb*(1.0+grain*0.025+coarse*0.03);
	ROUGHNESS = clamp(finish_roughness+grain*0.05+coarse*0.03,0.12,1.0);
	METALLIC = finish_metallic;
	SPECULAR = finish_kind == 5 ? 0.28 : 0.45;
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL), r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	vec3 gradient = sign(determinant)*(dFdx(grain)*r1+dFdy(grain)*r2);
	NORMAL = normalize(max(abs(determinant),0.000001)*NORMAL-gradient*bump);
}
