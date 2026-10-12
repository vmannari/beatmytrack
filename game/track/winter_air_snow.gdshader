shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
uniform float travel;
uniform float elapsed;
uniform float strength;
uniform vec3 focus;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
varying vec3 snow_world;
void vertex() {
	vec2 wind = vec2(0.91,-0.414608);
	vec2 side = vec2(-wind.y,wind.x);
	float along_focus = dot(focus.xz,wind);
	float across_focus = dot(focus.xz,side);
	// Wrapping changes only the bounded volume membership; motion is world-space.
	float along = mod(INSTANCE_CUSTOM.r*96.0+travel-along_focus+48.0,96.0)+along_focus-48.0;
	float across = mod(INSTANCE_CUSTOM.g*64.0-across_focus+32.0,64.0)+across_focus-32.0;
	vec2 p = wind*along+side*across+wind*VERTEX.x+side*VERTEX.z;
	VERTEX = vec3(p.x,0.4+INSTANCE_CUSTOM.b*2.3+sin(elapsed*2.0+INSTANCE_CUSTOM.r*19.0)*0.12,p.y);
	NORMAL = vec3(0.0,1.0,0.0);
	snow_world = VERTEX;
}
void fragment() {
	float depth = texture(scene_depth,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,depth)*2.0-1.0;
#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,depth);
#endif
	vec4 opaque = INV_VIEW_MATRIX*INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	if (opaque.y/opaque.w > 0.20) discard;
	vec2 p = UV*2.0-1.0;
	float grain = 1.0-smoothstep(0.1,1.0,dot(p,p));
	float fade = 1.0-smoothstep(22.0,31.0,length(snow_world.xz-focus.xz));
	ALBEDO = vec3(0.72,0.79,0.87);
	ROUGHNESS = 1.0;
	ALPHA = grain*fade*strength*0.40;
}
