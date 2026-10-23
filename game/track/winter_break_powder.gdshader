shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
varying float life;
void vertex() {
	vec3 size=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*size.x,0.0),vec4(INV_VIEW_MATRIX[1].xyz*size.y,0.0),vec4(INV_VIEW_MATRIX[2].xyz*size.z,0.0),MODEL_MATRIX[3]);
	life=INSTANCE_CUSTOM.a;
}
void fragment() {
	vec2 p=UV*2.0-1.0;
	float radius=length(p);
	float cloud=1.0-smoothstep(0.32,1.0,radius);
	ALBEDO=vec3(0.80,0.88,0.94);
	ALPHA=cloud*cloud*life*life*0.31;
}
