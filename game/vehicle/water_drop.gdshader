shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*scale.x,INV_VIEW_MATRIX[1]*scale.y,INV_VIEW_MATRIX[2]*scale.z,MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV*2.0-1.0;
	float radius = dot(p,p);
	float aa = max(fwidth(radius),0.05);
	// Small, bounded beads with a filtered edge; no expanding haze profile.
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a*(1.0-smoothstep(0.65-aa,0.9+aa,radius));
}
