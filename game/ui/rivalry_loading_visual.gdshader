shader_type canvas_item;
render_mode unshaded;

uniform bool vehicle = false;
uniform float phase_offset = 0.0;
uniform vec4 silhouette_color : source_color = vec4(0.75,0.83,0.89,1.0);

void fragment() {
	float clock = TIME + phase_offset;
	if (vehicle) {
		// The atlas contains alpha masks rendered offline from the production models.
		vec2 blur = TEXTURE_PIXEL_SIZE*3.2;
		float silhouette = texture(TEXTURE,UV).a*0.28;
		silhouette += (texture(TEXTURE,UV+vec2(blur.x,0.0)).a+texture(TEXTURE,UV-vec2(blur.x,0.0)).a+texture(TEXTURE,UV+vec2(0.0,blur.y)).a+texture(TEXTURE,UV-vec2(0.0,blur.y)).a)*0.12;
		silhouette += (texture(TEXTURE,UV+blur).a+texture(TEXTURE,UV-blur).a+texture(TEXTURE,UV+vec2(blur.x,-blur.y)).a+texture(TEXTURE,UV+vec2(-blur.x,blur.y)).a)*0.06;
		float pulse = 0.84+0.035*sin(clock*1.75);
		COLOR = vec4(silhouette_color.rgb,silhouette*0.43*pulse);
	} else {
		// A broad, low-contrast diagonal sweep keeps the rows calm and coordinated.
		float sweep = fract(clock/3.4)*2.3-0.65;
		float band = exp(-pow((SCREEN_UV.x+SCREEN_UV.y*0.12-sweep)/0.19,2.0));
		float breathe = 0.94+0.025*sin(clock*1.75+SCREEN_UV.y*4.0);
		COLOR = vec4(COLOR.rgb+vec3(0.045,0.055,0.060)*band,COLOR.a*breathe*(0.94+0.06*band));
	}
}
