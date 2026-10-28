shader_type canvas_item;
uniform vec2 panel_size = vec2(760.0,480.0);

void fragment() {
	vec2 p = UV*panel_size;
	vec2 image_size = vec2(textureSize(TEXTURE,0));
	float cover = panel_size.x/image_size.x;
	vec2 sample_uv = vec2(0.5,0.23)+(p-vec2(panel_size.x*0.5,65.0))/(image_size*cover);
	vec3 scenery = texture(TEXTURE,sample_uv).rgb;
	float fade = mix(0.72,1.0,smoothstep(40.0,170.0,p.y));
	vec3 color = mix(scenery,vec3(0.025,0.065,0.085),fade);
	vec2 q = abs(p-panel_size*0.5)-(panel_size*0.5-vec2(12.0));
	float distance = length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-12.0;
	float aa = max(fwidth(distance),0.65);
	float edge = 1.0-smoothstep(-aa,aa,distance);
	float border = smoothstep(-2.0-aa,-1.0,distance);
	COLOR = vec4(mix(color,vec3(0.36,0.49,0.54),border),edge);
}
