shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 cable_points[49];
uniform vec4 pigment : source_color = vec4(0.13,0.18,0.18,1.0);
void vertex() {
	int point = clamp(int(round(UV.y*48.0)),0,48);
	vec3 direction = normalize(cable_points[min(point+1,48)]-cable_points[max(point-1,0)]);
	vec3 axis = abs(direction.y)>0.9 ? vec3(1.0,0.0,0.0) : vec3(0.0,1.0,0.0);
	vec3 side = normalize(cross(direction,axis));
	vec3 up = cross(side,direction);
	vec3 radial = side*cos(UV.x*6.2831853)+up*sin(UV.x*6.2831853);
	VERTEX = cable_points[point]+radial*0.011;
	NORMAL = radial;
}
void fragment() {
	ALBEDO = pigment.rgb;
	ROUGHNESS = 0.86;
	SPECULAR = 0.20;
}
