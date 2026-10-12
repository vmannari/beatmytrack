shader_type canvas_item;
uniform vec2 panel_size = vec2(880.0,440.0);
uniform bool compact = false;
uniform bool panel_background = false;
uniform sampler2D scenery : filter_linear_mipmap;
uniform vec2 scenery_size = vec2(1902.0,827.0);
varying vec2 local_position;

void vertex() { local_position = VERTEX; }

void fragment() {
	vec2 p = local_position / max(panel_size,vec2(1.0));
	vec3 ink = vec3(0.025,0.065,0.085);
	float fade = compact ? 0.9 : smoothstep(0.22,0.57,p.x);
	float cover = max(panel_size.x/scenery_size.x,panel_size.y/scenery_size.y);
	vec2 scenery_uv = vec2(0.5)+(p-vec2(0.5))*panel_size/(scenery_size*cover);
	vec3 artwork = (panel_background ? texture(scenery,scenery_uv).rgb : texture(TEXTURE,UV).rgb) * 0.78;
	vec3 color = mix(artwork,ink,fade);
	vec2 q = abs(local_position-panel_size*0.5) - (panel_size*0.5-vec2(12.0));
	float distance = length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0)-12.0;
	float aa = max(fwidth(distance),0.65);
	float edge = 1.0-smoothstep(-aa,aa,distance);
	float border = smoothstep(-2.0-aa,-1.0,distance);
	COLOR = vec4(mix(color,vec3(0.36,0.49,0.54),border),edge);
}
