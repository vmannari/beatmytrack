// Metres in the prevailing wind basis. Shared spatial phases keep neighbouring
// sheets coherent; only the visual clock advances this bounded local shear.
vec2 snow_flow_offset(vec2 p, float clock) {
	float region = dot(p,vec2(0.11,0.073));
	float cross_region = dot(p,vec2(-0.052,0.13));
	return vec2(
		2.7*sin(clock*0.83+region)+sin(clock*1.67+cross_region),
		3.1*sin(clock*1.15+cross_region)+1.3*sin(clock*0.63-region));
}
float snow_local_gust(vec2 p, float clock) {
	return 0.85+0.15*sin(clock*0.73+dot(p,vec2(0.075,0.12)));
}
