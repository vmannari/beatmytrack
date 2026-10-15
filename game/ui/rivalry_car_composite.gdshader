shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
varying vec4 canvas_tint;
uniform bool linear_resolve = false;

void vertex() { canvas_tint = COLOR; }

vec3 to_linear(vec3 color) {
	return mix(pow((color+vec3(0.055))/1.055,vec3(2.4)),color/12.92,step(color,vec3(0.04045)));
}

vec3 to_display(vec3 color) {
	color = clamp(color,vec3(0.0),vec3(1.0));
	return mix(1.055*pow(color,vec3(1.0/2.4))-vec3(0.055),color*12.92,step(color,vec3(0.0031308)));
}

void fragment() {
	ivec2 extent = textureSize(TEXTURE,0);
	vec3 matte = texelFetch(TEXTURE,ivec2(0),0).rgb;
	vec2 pixel = UV*vec2(extent)-vec2(0.5);
	ivec2 base = ivec2(floor(pixel));
	vec2 weight = fract(pixel);
	// Keep built-in sampler access in fragment: passing TEXTURE to a helper
	// triggers the pinned engine's dummy renderer sampler assertion at startup.
	vec4 samples[4];
	for (int tap = 0; tap < 4; tap++) {
		ivec2 source_pixel = base+ivec2(tap%2,tap/2);
		vec4 sample_color = texelFetch(TEXTURE,clamp(source_pixel,ivec2(0),extent-ivec2(1)),0);
		if (sample_color.a < 0.0001) {
			samples[tap] = vec4(0.0);
			continue;
		}
		if (sample_color.a > 0.9999) {
			samples[tap] = sample_color;
			continue;
		}
		// Resolve silhouette coverage before the clear matte contaminates edges.
		vec4 interior = sample_color;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec4 adjacent = texelFetch(TEXTURE,clamp(source_pixel+ivec2(x,y),ivec2(0),extent-ivec2(1)),0);
				if (adjacent.a > interior.a) interior = adjacent;
			}
		}
		if (interior.a > 0.9999) {
			sample_color.rgb = interior.rgb*sample_color.a;
		} else if (linear_resolve) {
			vec3 pigment = max(vec3(0.0),to_linear(sample_color.rgb)-to_linear(matte)*(1.0-sample_color.a))/sample_color.a;
			sample_color.rgb = to_display(pigment)*sample_color.a;
		} else {
			sample_color.rgb = max(vec3(0.0),sample_color.rgb-matte*(1.0-sample_color.a));
		}
		samples[tap] = sample_color;
	}
	vec4 top = mix(samples[0],samples[1],weight.x);
	vec4 bottom = mix(samples[2],samples[3],weight.x);
	COLOR = mix(top,bottom,weight.y)*canvas_tint;
	COLOR.rgb *= canvas_tint.a;
}
