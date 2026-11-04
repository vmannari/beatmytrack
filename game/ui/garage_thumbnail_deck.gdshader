shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D reflection_image : source_color, filter_linear, repeat_disable;
uniform bool reflection_enabled = false;
varying vec3 deck_position;
varying float deck_top;
void vertex() {
	deck_position = VERTEX;
	deck_top = NORMAL.y;
}
void fragment() {
	float radius = length(deck_position.xz);
	float brushed = sin(radius*360.0)*0.002;
	float edge = smoothstep(3.40,3.58,radius);
	ALBEDO = mix(vec3(0.095,0.125,0.15),vec3(0.15,0.18,0.20),edge)+brushed;
	ROUGHNESS = 0.27;
	METALLIC = 0.62;
	if (reflection_enabled && deck_top > 0.5) {
		vec2 uv = vec2(1.0-SCREEN_UV.x,SCREEN_UV.y);
		vec2 texel = 1.0/vec2(textureSize(reflection_image,0));
		vec4 reflected = texture(reflection_image,uv)*0.50;
		reflected += texture(reflection_image,uv+vec2(texel.x,0.0))*0.125;
		reflected += texture(reflection_image,uv-vec2(texel.x,0.0))*0.125;
		reflected += texture(reflection_image,uv+vec2(0.0,texel.y))*0.125;
		reflected += texture(reflection_image,uv-vec2(0.0,texel.y))*0.125;
		float fresnel = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
		float weight = (0.42+fresnel*0.18)*reflected.a;
		ALBEDO *= 1.0-weight;
		EMISSION = reflected.rgb/max(reflected.a,0.001)*weight;
	}
}
