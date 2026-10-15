shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
#include "res://track/winter_wind_variation.gdshaderinc"
uniform float travel;
uniform float elapsed;
uniform float strength;
uniform vec3 focus;
uniform vec2 protected_car;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
varying vec3 snow_world;
void vertex() {
	vec2 wind = vec2(0.91,-0.414608);
	vec2 side = vec2(-wind.y,wind.x);
	float along_focus = dot(focus.xz,wind);
	float across_focus = dot(focus.xz,side);
	// Wrapping changes only the bounded volume membership; motion is world-space.
	float grain_speed = 0.72+INSTANCE_CUSTOM.b*0.53;
	float along = mod(INSTANCE_CUSTOM.r*96.0+travel*grain_speed-along_focus+48.0,96.0)+along_focus-48.0;
	float across = mod(INSTANCE_CUSTOM.g*64.0-across_focus+32.0,64.0)+across_focus-32.0;
	vec2 flow_point = snow_grain_position(vec2(along,across),elapsed);
	vec2 p = wind*flow_point.x+side*flow_point.y+wind*VERTEX.x+side*VERTEX.z;
	// Small saltating grains skim the surface; no eye-height snow volume.
	VERTEX = vec3(p.x,0.026+INSTANCE_CUSTOM.b*INSTANCE_CUSTOM.b*0.060+abs(sin(elapsed*4.5+INSTANCE_CUSTOM.r*19.0))*0.012,p.y);
	NORMAL = vec3(0.0,1.0,0.0);
	snow_world = VERTEX;
}
void fragment() {
	vec2 p = UV*2.0-1.0;
	float grain = 1.0-smoothstep(0.1,1.0,dot(p,p));
	float fade = 1.0-smoothstep(22.0,31.0,length(snow_world.xz-focus.xz));
	// Resolved depth can mix road/car at an MSAA edge. Keep the small grains
	// outside the actual vehicle footprint as well as checking solid depth.
	if (length(snow_world.xz-protected_car) < 2.55) discard;
	if (grain <= 0.0 || fade <= 0.0 || strength <= 0.0) discard;
	vec2 wind = vec2(0.91,-0.414608);
	vec2 point = vec2(dot(snow_world.xz,wind),dot(snow_world.xz,vec2(-wind.y,wind.x)));
	float local_gust = snow_local_gust(point,elapsed);
	if (local_gust <= 0.0) discard;
	float depth = texture(scene_depth,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,depth)*2.0-1.0;
#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,depth);
#endif
	vec4 opaque = INV_VIEW_MATRIX*INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	if (opaque.y/opaque.w > 0.20) discard;
	ALBEDO = vec3(0.92,0.95,0.98);
	ROUGHNESS = 1.0;
	ALPHA = grain*fade*strength*local_gust*0.72;
}
