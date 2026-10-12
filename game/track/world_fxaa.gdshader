shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_color : hint_screen_texture, repeat_disable, filter_linear;
uniform float source_pixel_scale = 1.0;

float luminance(vec3 color) { return dot(color,vec3(0.299,0.587,0.114)); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = SCREEN_PIXEL_SIZE*source_pixel_scale;
	vec3 center = textureLod(world_color,uv,0.0).rgb;
	float middle = luminance(center);
	float nw = luminance(textureLod(world_color,uv+texel*vec2(-1,-1),0.0).rgb);
	float ne = luminance(textureLod(world_color,uv+texel*vec2(1,-1),0.0).rgb);
	float sw = luminance(textureLod(world_color,uv+texel*vec2(-1,1),0.0).rgb);
	float se = luminance(textureLod(world_color,uv+texel*vec2(1,1),0.0).rgb);
	float low = min(middle,min(min(nw,ne),min(sw,se)));
	float high = max(middle,max(max(nw,ne),max(sw,se)));
	vec3 result = center;
	if (high-low>max(0.05,high*0.125)) {
		// Follow the local edge, blending its coverage rather than blurring
		// low-contrast terrain, dust texture, or the opaque paint interiors.
		vec2 direction = vec2(sw+se-nw-ne,nw+sw-ne-se);
		float floor_gradient = max((nw+ne+sw+se)*0.03125,0.0078125);
		direction /= min(abs(direction.x),abs(direction.y))+floor_gradient;
		direction = clamp(direction,vec2(-6),vec2(6))*texel;
		vec3 near_edge = (textureLod(world_color,uv-direction/6.0,0.0).rgb+
			textureLod(world_color,uv+direction/6.0,0.0).rgb)*0.5;
		vec3 wide_edge = near_edge*0.5+(textureLod(world_color,uv-direction*0.5,0.0).rgb+
			textureLod(world_color,uv+direction*0.5,0.0).rgb)*0.25;
		float wide_luma = luminance(wide_edge);
		result = wide_luma<low || wide_luma>high ? near_edge : wide_edge;
	}
	COLOR = vec4(result,1.0);
}
