shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying vec2 floor_point;
void vertex() { floor_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 p = floor_point;
	float grain = fract(sin(dot(floor(p*38.0),vec2(127.1,311.7)))*43758.5453);
	vec2 joint = abs(fract((p+vec2(0.0,2.0))/6.0)-0.5)*6.0;
	float seam = 1.0-smoothstep(0.012,0.038,min(joint.x,joint.y));
	float edge_bays = smoothstep(27.8,28.0,abs(p.y));
	float central_bays = (1.0-smoothstep(7.0,7.2,abs(p.y)))*smoothstep(2.5,3.0,p.x);
	vec3 concrete = mix(vec3(0.285,0.30,0.285),vec3(0.205,0.27,0.25),edge_bays);
	concrete = mix(concrete,vec3(0.26,0.285,0.26),central_bays);
	float tracks = exp(-pow((abs(p.y)-18.0)/2.5,2.0))*0.035;
	float stains = sin(p.x*0.13+sin(p.y*0.19))*sin(p.y*0.23+p.x*0.06)*0.009;
	float pool = pow(max(0.0,cos((p.x-4.0)*0.523599)),6.0)*exp(-pow((abs(p.y)-18.0)/3.7,2.0));
	ALBEDO = concrete + (grain-0.5)*0.009 + stains - seam*0.018 - tracks;
	EMISSION = vec3(0.06,0.064,0.052)*pool;
	ROUGHNESS = 0.94;
}
