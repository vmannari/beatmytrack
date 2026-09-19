shader_type canvas_item;
render_mode unshaded;

// Original lightweight lens water: one screen copy, local samples, no global blur.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float fade = 1.0;
uniform float stretch = 1.2;
uniform float radius_px = 26.0;
uniform float shape_seed = 0.0;

void fragment() {
	vec2 q = (UV - vec2(0.5)) * vec2(2.4, 3.2);
	// Narrow at the upper shoulder, round and heavy at the lower end.
	float width = 0.65 + 0.18*sin(shape_seed*3.1) + 0.22 * smoothstep(-0.9, 0.5, q.y);
	q.x += (q.y*q.y-0.2)*sin(shape_seed*7.3)*0.18;
	vec2 oval = q / vec2(width, stretch);
	float polar = atan(oval.y,oval.x);
	float edge = 1.0+0.14*sin(polar*3.0+shape_seed*8.0)+0.07*sin(polar*5.0+shape_seed*3.0);
	float d = length(oval)/edge;
	float body = 1.0 - smoothstep(0.80, 1.02, d);
	float mask = body * fade;
	vec2 bend = oval * sqrt(max(0.0, 1.0-min(d*d, 1.0))) * body;
	vec2 offset = bend * min(radius_px*1.45, 44.0) * SCREEN_PIXEL_SIZE;
	vec3 scene = texture(screen_texture, clamp(SCREEN_UV+offset, vec2(0.001), vec2(0.999))).rgb;
	// Soft asymmetric glints, without the previous drawn bubble outlines.
	float glint = exp(-dot((oval-vec2(-0.38,-0.62))*vec2(2.8,5.0), (oval-vec2(-0.38,-0.62))*vec2(2.8,5.0)));
	float shade = exp(-dot((oval-vec2(0.25,0.70))*vec2(2.5,7.0), (oval-vec2(0.25,0.70))*vec2(2.5,7.0)));
	float rim = exp(-pow((d-0.86)*10.0, 2.0)) * max(0.0, -oval.x*0.55-oval.y*0.45);
	scene += vec3(0.70,0.85,0.94)*rim*0.30;
	scene = scene * (1.0-shade*0.23) + vec3(0.80,0.91,1.0)*glint*0.52;
	COLOR = vec4(scene, mask*0.94);
}
