shader_type sky;
float cloud_noise(vec2 p) {
 vec2 cell = floor(p);
 vec2 f = smoothstep(vec2(0.0),vec2(1.0),fract(p));
 vec4 seed = vec4(dot(cell,vec2(127.1,311.7)),dot(cell+vec2(1,0),vec2(127.1,311.7)),dot(cell+vec2(0,1),vec2(127.1,311.7)),dot(cell+vec2(1,1),vec2(127.1,311.7)));
 vec4 n = fract(sin(seed)*43758.5453);
 return mix(mix(n.x,n.y,f.x),mix(n.z,n.w,f.x),f.y);
}
// Dark cloud cover with two bright, soft-edged breaks. Rough asphalt blurs
// these openings; smooth standing water retains their brighter reflection.
// The engine filters this static environment once, not every weather frame.
void sky() {
 float elevation = smoothstep(-0.15,0.8,EYEDIR.y);
 // Broad angular openings keep reflections readable across the road ahead,
 // rather than concentrating the sky highlight beside the following camera.
 float opening = pow(max(dot(EYEDIR,normalize(vec3(-0.25,0.80,-0.55))),0.0),18.0);
 float fringe = pow(max(dot(EYEDIR,normalize(vec3(0.03,0.90,-0.44))),0.0),36.0);
 COLOR = mix(vec3(0.06,0.07,0.08),vec3(0.14,0.16,0.18),elevation);
 vec2 cloud_uv = EYEDIR.xz/max(EYEDIR.y,0.15);
 float cloud = cloud_noise(cloud_uv*9.0+vec2(3.7,9.2))*0.7+cloud_noise(cloud_uv*21.0)*0.3;
 float break_up = mix(0.30,1.0,smoothstep(0.30,0.66,cloud));
 COLOR += (vec3(3.0,3.08,3.16)*opening + vec3(1.3,1.36,1.43)*fringe)*break_up;
}
