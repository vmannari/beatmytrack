shader_type canvas_item;
uniform vec2 panel_size = vec2(1180.0,610.0);
uniform float divide = 0.55;
uniform bool stacked = false;

void fragment() {
	vec2 p = UV*panel_size;
	vec2 art_size = stacked ? vec2(panel_size.x,panel_size.y*divide) : vec2(panel_size.x*divide,panel_size.y);
	vec2 image_size = vec2(textureSize(TEXTURE,0));
	float cover = max(art_size.x/image_size.x,art_size.y/image_size.y);
	vec2 sample_uv = vec2(0.5)+(p-art_size*0.5)/(image_size*cover);
	vec3 scenery = texture(TEXTURE,sample_uv).rgb;
	float coordinate = stacked ? UV.y : UV.x;
	float seam = smoothstep(divide-0.035,divide+0.008,coordinate);
	float grounding = smoothstep(0.3,1.0,p.y/max(art_size.y,1.0))*0.24;
	vec3 color = mix(scenery*(1.0-grounding),vec3(0.025,0.065,0.085),seam);
	vec2 q = abs(p-panel_size*0.5)-(panel_size*0.5-vec2(12.0));
	float distance = length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-12.0;
	float aa = max(fwidth(distance),0.65);
	float edge = 1.0-smoothstep(-aa,aa,distance);
	float border = smoothstep(-2.0-aa,-1.0,distance);
	COLOR = vec4(mix(color,vec3(0.36,0.49,0.54),border),edge);
}
