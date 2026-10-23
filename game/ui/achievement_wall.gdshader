shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// One static atlas and one instanced face draw for the entire collection.
uniform sampler2D medals : source_color, filter_linear_mipmap, repeat_disable;
varying flat vec4 state;
void vertex() {
	state = INSTANCE_CUSTOM;
}
void fragment() {
	vec2 cell = vec2(mod(state.x,10.0),floor(state.x/10.0)*5.0+state.y);
	vec4 face = texture(medals,(cell+UV)/vec2(10.0,20.0));
	ALBEDO = face.rgb * state.z;
	ALPHA = face.a;
	ALPHA_SCISSOR_THRESHOLD = 0.15;
}
