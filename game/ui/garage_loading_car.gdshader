shader_type canvas_item;
render_mode unshaded;

uniform bool backdrop = false;
uniform bool compact_preview = false;
uniform float atlas_columns = 5.0;

void fragment() {
	float breathe = 0.5+0.5*sin(TIME*1.85);
	if (backdrop) {
		vec3 base = mix(vec3(0.028,0.055,0.080),vec3(0.045,0.100,0.125),UV.y);
		vec2 halo_at = vec2(0.5,compact_preview ? 0.30 : 0.47);
		vec2 halo_delta = (UV-halo_at)*vec2(2.0,3.0);
		float halo = exp(-dot(halo_delta,halo_delta)*2.0);
		vec2 floor_delta = (UV-vec2(0.5,compact_preview ? 0.53 : 0.76))*vec2(2.8,24.0);
		float floor_glow = exp(-dot(floor_delta,floor_delta)*2.0);
		vec3 ambience = vec3(0.025,0.115,0.155)*halo*(0.80+0.20*breathe);
		COLOR = vec4(base+ambience+vec3(0.015,0.065,0.085)*floor_glow,1.0);
	} else {
		float shape = texture(TEXTURE,UV).a;
		vec2 step_uv = TEXTURE_PIXEL_SIZE*1.8;
		float left = texture(TEXTURE,UV-vec2(step_uv.x,0.0)).a;
		float right = texture(TEXTURE,UV+vec2(step_uv.x,0.0)).a;
		float above = texture(TEXTURE,UV-vec2(0.0,step_uv.y)).a;
		float below = texture(TEXTURE,UV+vec2(0.0,step_uv.y)).a;
		float rim = max(0.0,shape-min(min(left,right),min(above,below)));
		float soft_edge = max(0.0,max(max(left,right),max(above,below))-shape);
		vec2 local_uv = vec2(fract(UV.x*atlas_columns),UV.y);
		float sweep_at = fract(TIME/4.8)*1.8-0.3;
		float sweep = exp(-pow((local_uv.x+local_uv.y*0.2-sweep_at)/0.16,2.0));
		vec3 tint = mix(vec3(0.12,0.33,0.43),vec3(0.50,0.77,0.82),1.0-local_uv.y);
		tint += vec3(0.09,0.13,0.14)*sweep;
		tint = mix(tint,vec3(0.65,0.91,0.97),min(1.0,rim*1.7));
		float opacity = shape*(0.46+0.20*breathe)+rim*0.22+soft_edge*0.13;
		COLOR = vec4(tint,min(1.0,opacity));
	}
}
