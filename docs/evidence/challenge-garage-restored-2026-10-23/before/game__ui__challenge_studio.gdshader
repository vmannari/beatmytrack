shader_type spatial;
render_mode unshaded, fog_disabled;
// Original quiet, continuous graphic bands across the floor and curved backdrop.
uniform vec4 ink : source_color = vec4(0.055,0.085,0.11,1.0);
uniform vec4 slate : source_color = vec4(0.13,0.20,0.25,1.0);
uniform vec4 petrol : source_color = vec4(0.16,0.29,0.32,1.0);
uniform vec4 brass : source_color = vec4(0.46,0.40,0.28,1.0);
varying vec3 studio_position;

void vertex() { studio_position = VERTEX; }

void fragment() {
	vec2 p = vec2(studio_position.x,studio_position.z+studio_position.y*0.65);
	float diagonal = smoothstep(-12.0,16.0,p.x+p.y*0.55);
	vec2 pool_position = (p-vec2(-3.0,4.0))*vec2(0.085,0.065);
	float pool = exp(-dot(pool_position,pool_position));
	float arc = length((p-vec2(3.5,3.0))*vec2(0.78,1.0));
	float ribbon = 1.0-smoothstep(1.7,2.4,abs(arc-10.0));
	float trace = 1.0-smoothstep(0.035,0.085,abs(arc-7.7));
	vec3 color = mix(ink.rgb,slate.rgb,diagonal*0.68);
	color = mix(color,petrol.rgb,pool*0.34+ribbon*0.22);
	color = mix(color,brass.rgb,trace*0.27);
	ALBEDO = color;
}
