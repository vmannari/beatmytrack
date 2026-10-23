shader_type canvas_item;
uniform vec2 panel_size = vec2(1120.0,620.0);
uniform float hero_width = 358.0;
varying vec2 local_position;

void vertex() { local_position = VERTEX; }

void fragment() {
	vec2 p = local_position / max(panel_size,vec2(1.0));
	vec3 ink = vec3(0.043,0.082,0.110);
	vec3 scene = texture(TEXTURE,UV).rgb;
	scene *= mix(0.40,0.78,smoothstep(0.08,0.68,p.y));
	scene = mix(scene,ink,smoothstep(0.67,1.0,p.y)*0.88);
	float divide = hero_width / panel_size.x;
	vec3 color = mix(scene,ink,smoothstep(divide-0.06,divide+0.025,p.x));
	vec2 q = abs(local_position-panel_size*0.5)-(panel_size*0.5-vec2(12.0));
	float distance = length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-12.0;
	float aa = max(fwidth(distance),0.65);
	float edge = 1.0-smoothstep(-aa,aa,distance);
	float border = smoothstep(-1.5-aa,-0.6,distance);
	COLOR = vec4(mix(color,vec3(0.22,0.30,0.35),border),edge);
}
