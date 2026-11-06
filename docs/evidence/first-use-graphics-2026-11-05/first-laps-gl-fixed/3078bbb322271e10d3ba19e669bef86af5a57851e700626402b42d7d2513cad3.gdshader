
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void vertex() {
	vec3 particle_scale = vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*particle_scale.x,INV_VIEW_MATRIX[1]*particle_scale.y,INV_VIEW_MATRIX[2]*particle_scale.z,MODEL_MATRIX[3]);
}
void fragment() {
	if (COLOR.a <= 0.0) discard;
	vec2 p = UV*2.0-1.0;
	float radius = length(p);
	float haze = 1.0-smoothstep(0.12,1.0,radius);
	if (haze <= 0.0) discard;
	haze *= haze;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	ALPHA = COLOR.a*haze;
}
