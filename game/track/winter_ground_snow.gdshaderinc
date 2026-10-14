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
	vec2 field = point-vec2(wind_surface_travel,0.0)+snow_flow_offset(point,wind_surface_elapsed);
	// Separate broad packets from almost isotropic grains. No card UVs,
	// screen-space projection or height gap; powder belongs to this surface.
	vec2 packet = texture(wind_surface_flow,field*vec2(0.06,0.12)).rg;
	float fine = texture(wind_surface_flow,field*vec2(0.20,0.26)).b;
	float stream = smoothstep(0.30,0.78,packet.r)*smoothstep(0.16,0.70,packet.g);
	float aa = max(fwidth(fine),0.04);
	float grains = smoothstep(0.34-aa,0.64+aa,fine);
	return clamp(stream*mix(0.22,1.0,grains)*snow_local_gust(point,wind_surface_elapsed)
		*wind_surface_strength*fade*weight*0.88,0.0,0.88);
}
