shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D reflection_image : source_color, filter_linear, repeat_disable;
uniform bool reflection_enabled = false;
void fragment() {
	ALBEDO = vec3(0.18,0.20,0.22);
	ROUGHNESS = 0.30;
	METALLIC = 0.45;
	if (reflection_enabled) {
		vec2 uv = vec2(1.0-SCREEN_UV.x,SCREEN_UV.y);
		vec2 texel = 1.0/vec2(textureSize(reflection_image,0));
		vec4 reflection = texture(reflection_image,uv)*0.40;
		reflection += texture(reflection_image,uv+vec2(texel.x,0.0)*1.2)*0.15;
		reflection += texture(reflection_image,uv-vec2(texel.x,0.0)*1.2)*0.15;
		reflection += texture(reflection_image,uv+vec2(0.0,texel.y)*1.2)*0.15;
		reflection += texture(reflection_image,uv-vec2(0.0,texel.y)*1.2)*0.15;
		vec3 reflected = reflection.rgb / max(reflection.a,0.001);
		float weight = (0.30+pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0)*0.15)*reflection.a;
		ALBEDO *= 1.0-weight;
		EMISSION = reflected*weight;
	}
}
