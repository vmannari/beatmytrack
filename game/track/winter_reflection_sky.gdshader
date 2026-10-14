shader_type sky;

// Static reflection-only sky: broad cloud shapes stay soft at 128px radiance.
// No TIME, scene capture, external artwork or per-frame cubemap updates.
void sky() {
	float elevation = clamp(EYEDIR.y,0.0,1.0);
	vec3 blue = mix(vec3(0.69,0.75,0.79),vec3(0.165,0.319,0.509),sqrt(elevation));
	float field = sin(EYEDIR.x*18.0+EYEDIR.z*7.0)
		+sin(EYEDIR.z*23.0-EYEDIR.x*9.0+1.7)*0.45;
	float cloud = smoothstep(0.15,1.15,field)*smoothstep(0.02,0.24,elevation);
	vec3 upper = mix(blue*0.65,vec3(0.90,0.95,1.0)*1.05,cloud*0.70);
	vec3 lower = mix(vec3(0.178,0.227,0.305),vec3(0.69,0.75,0.79),pow(1.0-clamp(-EYEDIR.y,0.0,1.0),0.4))*0.35;
	COLOR = mix(lower,upper,smoothstep(-0.03,0.03,EYEDIR.y));
}
