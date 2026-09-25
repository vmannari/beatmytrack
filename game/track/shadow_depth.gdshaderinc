// Read opaque world surfaces, not the HUD or later transparent particles.
vec3 shadow_world_position(sampler2D depth_map, vec2 uv, mat4 inverse_projection, mat4 inverse_view) {
	float depth = texture(depth_map, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 world = inverse_view * inverse_projection * vec4(ndc, 1.0);
	return world.xyz / world.w;
}
