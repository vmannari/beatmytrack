// A bounded Eulerian coordinate warp, in metres in the world wind basis.
// Texture phase is p.x + offset.x - travel: its spatial derivative changes
// transport speed, without travel*time multipliers stretching the field forever.
vec2 snow_spatial_offset(vec2 p) {
	return vec2(1.8*sin(p.x*0.095+p.y*0.12)+0.45*sin(p.x*0.17-p.y*0.08),0.0);
}
vec2 snow_flow_offset(vec2 p, float clock) {
	return vec2(
		1.6*sin(clock*0.92+p.y*0.13)+0.6*sin(clock*1.71-p.y*0.21),
		0.9*sin(clock*0.81+p.x*0.04+p.y*0.10)
		+0.35*sin(clock*1.93-p.x*0.06+p.y*0.17))+snow_spatial_offset(p);
}
float snow_flow_gradient(vec2 p) {
	// Gentler spatial acceleration; positive gradient (0.7525–1.2475).
	return 1.0+0.171*cos(p.x*0.095+p.y*0.12)+0.0765*cos(p.x*0.17-p.y*0.08);
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
vec3 snow_patch_random(vec2 key) {
	vec3 q = fract(vec3(key.xyx)*vec3(0.1031,0.1030,0.0973));
	q += dot(q,q.yxz+33.33);
	return fract((q.xxy+q.yzz)*q.zyx);
}
float snow_local_gust(vec2 p, float clock) {
	// Sparse world-fixed emission windows. Fine snow travels through them;
	// clear areas have no residual blanket. Each window has its own event clock.
	vec2 cell_size = vec2(18.0,10.0);
	vec2 cell = floor(p/cell_size);
	float seed = snow_patch_random(cell).z;
	float period = mix(8.0,13.0,seed);
	float event_clock = clock+seed*period;
	float cycle = floor(event_clock/period);
	float age = mod(event_clock,period);
	vec3 random = snow_patch_random(cell+vec2(cycle*19.19,cycle*7.73)+17.0);
	float duration = mix(3.2,5.2,random.z);
	float life = smoothstep(0.0,0.85,age)*(1.0-smoothstep(duration-1.3,duration,age));
	if (life <= 0.0) return 0.0;
	vec2 center = (cell+0.5)*cell_size+(random.xy-0.5)*vec2(2.0,1.4);
	vec2 radius = mix(vec2(6.2,2.4),vec2(7.6,3.6),random.yz);
	// Support stays inside its cell, so changing an event during the clear
	// interval cannot pop at a cell seam. Unequal sizes hide the allocation grid.
	float patch = 1.0-smoothstep(0.45,1.0,length((p-center)/radius));
	return patch*life;
}
