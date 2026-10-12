shader_type sky;
// Original fixed photographic softboxes. Cached radiance, no frame animation.
void sky() {
	vec3 ray = normalize(EYEDIR);
	vec3 base = mix(vec3(0.10,0.13,0.17),vec3(0.22,0.25,0.30),smoothstep(-0.1,0.9,ray.y));
	float key = pow(max(0.0,dot(ray,normalize(vec3(-0.6,0.9,-0.4)))),28.0);
	float fill = pow(max(0.0,dot(ray,normalize(vec3(0.8,0.35,0.5)))),18.0);
	float top = pow(max(0.0,dot(ray,normalize(vec3(0.0,1.0,0.0)))),8.0);
	COLOR = base + vec3(1.05,0.98,0.87)*key + vec3(0.38,0.47,0.62)*fill + vec3(0.30)*top;
}
