shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
uniform vec4 paint : source_color = vec4(0.5,0.5,0.5,1.0);
uniform bool self_lit = false;
uniform vec2 reveal_center = vec2(0.0);
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
	float visible = smoothstep(8.5,14.0,distance(world_point,reveal_center));
	ALBEDO = paint.rgb;
	ROUGHNESS = 1.0;
	EMISSION = self_lit ? paint.rgb*0.65 : vec3(0.0);
	ALPHA = visible*0.9;
}
