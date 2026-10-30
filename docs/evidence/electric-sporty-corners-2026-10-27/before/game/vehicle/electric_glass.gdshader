shader_type spatial;
render_mode unshaded;

// Opaque laminated glazing: one fixed analytic environment, with no scene
// capture or screen read. Shared-car glazing and production lights are intact.
uniform bool studio_mode = false;
uniform bool mirror_surface = false;
uniform vec3 glass_tint_srgb = vec3(0.045, 0.074, 0.090);

vec3 linear_from_display(vec3 value) {
	return mix(value/12.92,pow((value+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),value));
}

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
		float key = pow(max(0.0,dot(direction,normalize(vec3(-0.65,0.8,-0.35)))),6.0);
		float fill = pow(max(0.0,dot(direction,normalize(vec3(0.8,0.35,0.5)))),12.0);
		environment = vec3(0.07,0.11,0.14)+vec3(0.42,0.48,0.52)*key+vec3(0.17,0.21,0.24)*fill;
	}
	// An explicitly display-space palette avoids implicit/default uniform
	// conversions. Compatibility writes sRGB; Mobile expects linear output.
	vec3 colour = mix(glass_tint_srgb*0.55,environment,0.38+0.42*fresnel);
	// One analytic reflection response in both renderers, with a fitted frit.
	// No extra scene capture, transparency sorting, or screen-reading pass.
	if (!mirror_surface) {
		float edge = min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
		colour = mix(vec3(0.012,0.020,0.025),colour,smoothstep(0.006,0.027,edge));
	}
	ALBEDO = OUTPUT_IS_SRGB ? colour : linear_from_display(colour);
}
