// A bounded Eulerian coordinate warp, in metres in the world wind basis.
// Texture phase is p.x + offset.x - travel: its spatial derivative changes
// transport speed, without travel*time multipliers stretching the field forever.
vec2 snow_spatial_offset(vec2 p) {
	return vec2(3.8*sin(p.x*0.095+p.y*0.12)+0.85*sin(p.x*0.17-p.y*0.08),0.0);
}
vec2 snow_flow_offset(vec2 p, float clock) {
	return vec2(
		4.2*sin(clock*0.92+p.y*0.13)+1.5*sin(clock*1.71-p.y*0.21),
		1.8*sin(clock*0.81+p.x*0.04+p.y*0.10)
		+0.7*sin(clock*1.93-p.x*0.06+p.y*0.17))+snow_spatial_offset(p);
}
float snow_flow_gradient(vec2 p) {
	// Strictly positive (0.4945–1.5055); no reversed phase or singular folds.
	return 1.0+0.361*cos(p.x*0.095+p.y*0.12)+0.1445*cos(p.x*0.17-p.y*0.08);
}
vec2 snow_grain_position(vec2 target, float clock) {
	// Invert the same phase map for the tiny airborne pool. Bounded iterations
	// avoid per-frame CPU integration and make pause/retry exact.
	vec2 point = target;
	point.x -= snow_flow_offset(target,clock).x;
	for (int i = 0; i < 4; i++) {
		vec2 offset = snow_flow_offset(point,clock);
		point.x -= clamp((point.x+offset.x-target.x)/snow_flow_gradient(point),-12.0,12.0);
		point.y = target.y-offset.y;
	}
	return point;
}
float snow_local_gust(vec2 p, float clock) {
	// Overlapping unequal periods: neighbouring patches surge at different times.
	float pulse = 0.5+0.30*sin(clock*0.67+dot(p,vec2(0.065,0.14)))
		+0.20*sin(clock*1.43+dot(p,vec2(-0.12,0.19)));
	return 0.42+0.58*smoothstep(0.18,0.84,pulse);
}
