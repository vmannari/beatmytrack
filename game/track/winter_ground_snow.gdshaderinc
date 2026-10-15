#include "res://track/winter_wind_variation.gdshaderinc"
uniform float wind_surface_strength = 0.0;
uniform float wind_surface_elapsed = 0.0;
uniform float wind_surface_travel = 0.0;
uniform vec2 wind_surface_focus;
uniform vec2 wind_surface_car;
uniform sampler2D wind_surface_flow : filter_linear_mipmap, repeat_enable;

float winter_ground_powder(vec2 world, float weight) {
	if (wind_surface_strength <= 0.0 || weight <= 0.0) return 0.0;
	float fade = 1.0-smoothstep(23.0,30.0,length(world-wind_surface_focus));
	// Keep powder clear of the solid player footprint and its mixed MSAA edge.
	// A short soft diversion avoids recolouring the background at that edge.
	fade *= smoothstep(2.1,2.55,length(world-wind_surface_car));
	if (fade <= 0.0) return 0.0;
	vec2 wind = vec2(0.91,-0.414608);
	vec2 point = vec2(dot(world,wind),dot(world,vec2(-wind.y,wind.x)));
	vec3 event = snow_local_event(point,wind_surface_elapsed);
	float local_gust = event.x;
	if (local_gust <= 0.0) return 0.0;
	vec2 field = point-vec2(wind_surface_travel+event.y,0.0)+snow_flow_offset(point,wind_surface_elapsed);
	// Thin wind-aligned streams break into fine trailing grains. No card UVs,
	// screen-space projection or height gap; powder belongs to this surface.
	vec2 packet = texture(wind_surface_flow,field*vec2(0.055,0.42)).rg;
	float fine = texture(wind_surface_flow,field*vec2(0.14,0.70)).b;
	float stream = smoothstep(0.43,0.73,packet.r)*smoothstep(0.24,0.74,packet.g);
	// Small irregular clumps are resolved in world metres, instead of relying
	// on a high-frequency texture channel that mipmaps into a smooth mist.
	vec2 grain_point = mat2(vec2(5.5,-1.3),vec2(2.1,8.0))*field;
	vec3 random = snow_patch_random(floor(grain_point));
	vec2 grain_center = 0.5+(random.xy-0.5)*0.42;
	float radius = mix(0.16,0.38,fine)*mix(0.8,1.15,random.z);
	float aa = max(length(fwidth(grain_point))*0.55,0.025);
	float grains = 1.0-smoothstep(max(radius-aa,0.0),radius+aa,length(fract(grain_point)-grain_center));
	// Empty cells and a skewed basis avoid rows of identical dotted grains.
	grains *= smoothstep(0.18,0.32,random.z);
	// Resolved, denser white grains with clear holes between them. Keep the
	// local event fades and footprint, rather than adding a background haze.
	return clamp(sqrt(stream)*mix(0.012,1.0,grains)*local_gust
		*sqrt(clamp(wind_surface_strength,0.0,1.0))*fade*weight*0.92,0.0,0.85);
}
