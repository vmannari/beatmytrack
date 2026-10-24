shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying vec2 floor_point;
void vertex() { floor_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 p = floor_point;
	float grain = fract(sin(dot(floor(p*36.0),vec2(127.1,311.7)))*43758.5453);
	vec2 joint = abs(fract((p+vec2(1.0))/8.0)-0.5)*8.0;
	float seam = 1.0-smoothstep(0.018,0.065,min(joint.x,joint.y));
	float lane = 1.0-smoothstep(6.8,7.0,abs(p.y-48.0));
	vec3 concrete = mix(vec3(0.31,0.34,0.35),vec3(0.255,0.285,0.30),lane);
	ALBEDO = concrete + (grain-0.5)*0.012 - seam*0.035;
	ROUGHNESS = 0.94;
}
