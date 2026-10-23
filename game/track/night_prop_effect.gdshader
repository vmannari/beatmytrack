shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float elapsed=0.0;
uniform int effect_kind=0; // 0 fireflies; 1 flame; 2 ember; 3 smoke
varying float phase;
varying float seed;
varying float effect_energy;
float hash_value(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise_value(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); vec2 s=f*f*(3.0-2.0*f);
	return mix(mix(hash_value(i),hash_value(i+vec2(1.0,0.0)),s.x),mix(hash_value(i+vec2(0.0,1.0)),hash_value(i+vec2(1.0,1.0)),s.x),s.y);
}
void vertex() {
	seed=INSTANCE_CUSTOM.x;
	effect_energy=INSTANCE_CUSTOM.w;
	float rate=INSTANCE_CUSTOM.y;
	float age=fract(elapsed*rate+seed);
	phase=age;
	vec3 offset=vec3(0.0);
	if(effect_kind==0) {
		offset=vec3(sin(elapsed*0.53+seed*47.0)*0.48,sin(elapsed*0.71+seed*29.0)*0.25,cos(elapsed*0.47+seed*31.0)*0.48);
	} else if(effect_kind==1) {
		offset=vec3(sin(elapsed*3.0+seed*37.0)*0.05,0.0,cos(elapsed*2.0+seed*31.0)*0.04);
	} else {
		offset=vec3(sin(age*3.0+seed*47.0)*age*0.42,age*(effect_kind==2?1.65:2.4),cos(age*2.0+seed*23.0)*age*0.3);
	}
	// Instance scale applies to both the billboard and its animated excursion.
	vec3 world_center=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz+offset*INSTANCE_CUSTOM.z;
	vec3 scaled=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),1.0);
	if(effect_kind==1) scaled.y*=0.88+0.12*sin(elapsed*7.0+seed*71.0);
	if(effect_kind==3) scaled.xy*=0.45+age*1.6;
	VERTEX=(VIEW_MATRIX*vec4(world_center,1.0)).xyz+scaled;
	POSITION=PROJECTION_MATRIX*vec4(VERTEX,1.0);
}
void fragment() {
	vec2 p=UV*2.0-1.0;
	float alpha=0.0;
	vec3 tint=vec3(1.0);
	if(effect_kind==0 || effect_kind==2) {
		float r=length(p);
		float pulse=effect_kind==0?pow(max(0.0,sin(elapsed*1.5+seed*57.0)),2.0):sin(phase*3.14159);
		alpha=(exp(-r*r*6.0)*0.42+exp(-r*r*60.0)*0.58)*pulse;
		tint=effect_kind==0?vec3(0.66,1.0,0.16):vec3(1.0,0.35,0.045);
	} else if(effect_kind==1) {
		float y=UV.y;
		float n=noise_value(vec2(p.x*3.7+seed*23.0,y*5.0+elapsed*3.4));
		n=n*0.75+noise_value(vec2(p.x*8.0+seed*17.0,y*11.0+elapsed*6.8))*0.25;
		float bend=sin(y*8.0-elapsed*5.0+seed*57.0)*(0.10+0.10*(1.0-y));
		float width=mix(0.66,0.015,pow(1.0-y,0.68))*(0.65+0.55*n);
		float edge=abs(p.x+bend);
		alpha=(1.0-smoothstep(width*0.18,width,edge))*smoothstep(0.0,0.13,y)*smoothstep(1.0,0.8,y)*0.92;
		float core=clamp((1.0-edge/max(width,0.01))*y*1.4+n*0.2,0.0,1.0);
		tint=mix(vec3(0.95,0.075,0.004),vec3(1.0,0.79,0.27),core);
	} else {
		float r=length(p+vec2(sin(p.y*5.0+seed*23.0)*0.14,0.0));
		alpha=exp(-r*r*4.5)*sin(phase*3.14159)*0.11;
		tint=vec3(0.15,0.17,0.20);
	}
	if (!OUTPUT_IS_SRGB) tint=mix(tint/12.92,pow((tint+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),tint));
	ALBEDO=tint;
	EMISSION=effect_kind==3?vec3(0.0):tint*1.4;
	ALPHA=alpha*effect_energy;
}
