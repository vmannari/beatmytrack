shader_type spatial;
render_mode diffuse_toon, specular_schlick_ggx;

// Opaque laminated glazing: one fixed analytic environment, with no scene
// capture or screen read. Shared-car glazing and production lights are intact.
uniform bool studio_mode = false;
uniform vec4 glass_tint : source_color = vec4(0.045, 0.074, 0.090, 1.0);

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	vec3 direction = normalize((INV_VIEW_MATRIX * vec4(reflect(-view,n),0.0)).xyz);
	float fresnel = pow(1.0-clamp(dot(n,view),0.0,1.0),4.0);
	float sky = smoothstep(-0.20,0.55,direction.y);
	vec3 environment = mix(vec3(0.12,0.18,0.20),vec3(0.48,0.61,0.68),sky);
	float cloud = smoothstep(0.75,0.96,dot(direction,normalize(vec3(-0.55,0.78,0.30))));
	environment = mix(environment,vec3(0.78,0.83,0.83),cloud*0.55);
	if (studio_mode) {
		float key = pow(max(0.0,dot(direction,normalize(vec3(-0.65,0.8,-0.35)))),18.0);
		float fill = pow(max(0.0,dot(direction,normalize(vec3(0.8,0.35,0.5)))),12.0);
		environment = vec3(0.09,0.14,0.19)+vec3(0.72,0.78,0.81)*key+vec3(0.20,0.29,0.35)*fill;
	}
	ALBEDO = mix(glass_tint.rgb,environment,0.23+0.48*fresnel);
	EMISSION = environment*(0.10+0.12*fresnel);
	ROUGHNESS = 0.20;
	SPECULAR = 0.60;
	METALLIC = 0.10;
}
