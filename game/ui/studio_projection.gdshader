shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec3 support[24];
varying vec2 world_floor;
void vertex() { world_floor = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
	float distance = -1000.0;
	for(int i=0;i<24;i++) { distance=max(distance,dot(support[i].xy,world_floor)-support[i].z); }
	ALBEDO=vec3(0.012,0.018,0.025);
	ALPHA=(1.0-smoothstep(-0.09,0.24,distance))*0.24;
}
