shader_type canvas_item;
render_mode unshaded;

uniform bool vehicle = false;
uniform float phase_offset = 0.0;

float rounded_box(vec2 point, vec2 extent, float radius) {
	vec2 outside = abs(point) - extent + vec2(radius);
	return length(max(outside,vec2(0.0))) + min(max(outside.x,outside.y),0.0) - radius;
}

float cabin(vec2 point) {
	// Convex roof and sloping pillars: an anonymous, deliberately indistinct car.
	vec2 a = vec2(-0.53,-0.045);
	vec2 b = vec2(-0.31,-0.29);
	vec2 c = vec2(0.28,-0.27);
	vec2 d = vec2(0.51,-0.045);
	float left = dot(point-a,normalize(vec2(b.y-a.y,a.x-b.x)));
	float roof = dot(point-b,normalize(vec2(c.y-b.y,b.x-c.x)));
	float right = dot(point-c,normalize(vec2(d.y-c.y,c.x-d.x)));
	float bottom = dot(point-d,vec2(0.0,1.0));
	return max(max(left,roof),max(right,bottom));
}

void fragment() {
	float clock = TIME + phase_offset;
	if (vehicle) {
		vec2 point = (UV-vec2(0.5))*vec2(2.5,1.0);
		point.y += point.x*0.045;
		float blur = 0.027;
		float body = rounded_box(point-vec2(0.0,0.045),vec2(0.87,0.135),0.085);
		float roof = cabin(point);
		float wheels = min(length(point-vec2(-0.54,0.17)),length(point-vec2(0.55,0.17)))-0.112;
		float shape = min(min(body,roof),wheels);
		float silhouette = 1.0-smoothstep(-blur,blur,shape);
		float glass = (1.0-smoothstep(-blur,blur,cabin(point+vec2(0.0,-0.018))+0.045));
		vec3 paint = mix(vec3(0.23,0.34,0.41),vec3(0.43,0.55,0.61),clamp(0.5-point.y*2.0,0.0,1.0));
		paint = mix(paint,vec3(0.13,0.22,0.29),glass*0.7);
		float tires = 1.0-smoothstep(-blur,blur,wheels+0.018);
		paint = mix(paint,vec3(0.16,0.23,0.28),tires*0.6);
		float highlight = exp(-pow((point.y+0.015)/0.024,2.0))*0.09;
		paint += vec3(highlight);
		float shadow = exp(-pow(point.x/0.88,4.0)-pow((point.y-0.30)/0.065,2.0))*0.16;
		float pulse = 0.84+0.035*sin(clock*1.75);
		COLOR = vec4(paint,max(silhouette*0.75,shadow)*pulse);
	} else {
		// A broad, low-contrast diagonal sweep keeps the rows calm and coordinated.
		float sweep = fract(clock/3.4)*2.3-0.65;
		float band = exp(-pow((SCREEN_UV.x+SCREEN_UV.y*0.12-sweep)/0.19,2.0));
		float breathe = 0.94+0.025*sin(clock*1.75+SCREEN_UV.y*4.0);
		COLOR = vec4(COLOR.rgb+vec3(0.045,0.055,0.060)*band,COLOR.a*breathe*(0.94+0.06*band));
	}
}
