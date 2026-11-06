shader_type spatial;
// Continuous light across shallow sand deposits; same shared surface logic.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D surface_factors : filter_linear_mipmap_anisotropic, repeat_enable;
// Keep crystalline frost and scraped compacted snow readable in the artwork.
vec3 quiet_winter_ice(vec3 artwork) {
	float grain = dot(artwork,vec3(0.2126,0.7152,0.0722));
	return vec3(0.50,0.56,0.60)+(grain-0.30)*0.20;
}

uniform float winter_seam_reflection_strength : hint_range(0.0,1.0) = 1.0;

// Packed A follows elongated existing artwork ridges; broad ice stays matte.
float winter_seam_weight(vec4 finish, float frost) {
	return finish.a*(1.0-smoothstep(0.20,0.75,frost))*winter_seam_reflection_strength;
}

vec2 winter_reflective_finish(vec4 finish, float frost) {
	float seam = winter_seam_weight(finish,frost);
	return vec2(mix(0.88,0.12,seam),mix(0.08,1.0,seam));
}

// Thin reflective facets catch the same static sky directions with stronger
// contrast; this feeds reflected lighting, not albedo or self-illumination.
vec4 winter_seam_radiance(vec3 normal, vec3 view, mat4 inverse_view, float seam) {
	// Most packed ice has exactly zero seam coverage. Its reflected radiance
	// is unused, so skip the directional cloud field on those fragments.
	if (seam <= 0.0) return vec4(0.0);
	vec3 direction = normalize((inverse_view*vec4(reflect(-view,normal),0.0)).xyz);
	float field = sin(direction.x*18.0+direction.z*7.0)
		+sin(direction.z*23.0-direction.x*9.0+1.7)*0.45;
	float cloud = smoothstep(0.15,1.15,field);
	vec3 light = mix(vec3(0.40,0.65,0.95),vec3(2.0,2.2,2.4),cloud);
	return vec4(light,seam*0.72);
}

uniform bool snow_edge_sources = false;
#define snow_road_sources surface_factors
uniform vec4 snow_source_bounds;
// A bounded Eulerian coordinate warp, in metres in the world wind basis.
// Texture phase is p.x + offset.x - travel: its spatial derivative changes
// transport speed, without travel*time multipliers stretching the field forever.
vec2 snow_spatial_offset(vec2 p) {
	return vec2(1.8*sin(p.x*0.095+p.y*0.12)+0.45*sin(p.x*0.17-p.y*0.08),0.0);
}
vec2 snow_flow_offset(vec2 p, float clock) {
	return vec2(
		1.6*sin(clock*0.92+p.y*0.13)+0.6*sin(clock*1.71-p.y*0.21),
		0.9*sin(clock*0.81+p.x*0.04+p.y*0.10)
		+0.35*sin(clock*1.93-p.x*0.06+p.y*0.17))+snow_spatial_offset(p);
}
float snow_flow_gradient(vec2 p) {
	// Gentler spatial acceleration; positive gradient (0.7525–1.2475).
	return 1.0+0.171*cos(p.x*0.095+p.y*0.12)+0.0765*cos(p.x*0.17-p.y*0.08);
}
vec2 snow_grain_position(vec2 target, float clock) {
	// Invert the same phase map for the tiny airborne pool. Bounded iterations
	// avoid per-frame CPU integration and make pause/retry exact.
	vec2 point = target;
	point.x -= snow_flow_offset(target,clock).x;
	for (int i = 0; i < 4; i++) {
		vec2 offset = snow_flow_offset(point,clock);
		point.x -= clamp((point.x+offset.x-target.x)/snow_flow_gradient(point),-12.0,12.0);
		point.y = target.y-offset.y;
	}
	return point;
}
vec3 snow_patch_random(vec2 key) {
	vec3 q = fract(vec3(key.xyx)*vec3(0.1031,0.1030,0.0973));
	q += dot(q,q.yxz+33.33);
	return fract((q.xxy+q.yzz)*q.zyx);
}
vec3 snow_local_event(vec2 p, float clock) {
	// Sparse world-fixed emission windows. Fine snow travels through them;
	// clear areas have no residual blanket. Each window has its own event clock.
	vec2 cell_size = vec2(18.0,10.0);
	vec2 cell = floor(p/cell_size);
	vec2 edge_origin = vec2(0.0);
	if (snow_edge_sources) {
		vec2 uv = (p-snow_source_bounds.xy)/snow_source_bounds.zw;
		if (any(lessThan(uv,vec2(0.0))) || any(greaterThanEqual(uv,vec2(1.0)))) return vec3(0.0);
		vec4 source = texture(snow_road_sources,uv);
		if (source.a < 0.5 || p.x < source.x) return vec3(0.0);
		edge_origin = source.xy;
		cell = floor(edge_origin/cell_size);
	}
	float seed = snow_patch_random(cell).z;
	float period = mix(8.0,13.0,seed);
	float event_clock = clock+seed*period;
	float cycle = floor(event_clock/period);
	float age = mod(event_clock,period);
	vec3 random = snow_patch_random(cell+vec2(cycle*19.19,cycle*7.73)+17.0);
	float duration = mix(3.2,5.2,random.z);
	float life = smoothstep(0.0,0.85,age)*(1.0-smoothstep(duration-1.3,duration,age));
	if (life <= 0.0) return vec3(0.0);
	vec2 center = (cell+0.5)*cell_size+(random.xy-0.5)*vec2(2.0,1.4);
	vec2 radius = mix(vec2(6.2,2.4),vec2(7.6,3.6),random.yz);
	// Only relocate the existing window: its upwind tip stays on the road edge.
	if (snow_edge_sources) center = edge_origin+vec2(radius.x,0.0);
	// Support stays inside its cell, so changing an event during the clear
	// interval cannot pop at a cell seam. Unequal sizes hide the allocation grid.
	float patch = 1.0-smoothstep(0.45,1.0,length((p-center)/radius));
	if (patch <= 0.0) return vec3(0.0);
	// Integrate a different speed for each finite event, plus a gentle surge.
	// The phase resets only while the event is invisible, so variation cannot
	// stretch the world field over a long race or cause visible phase jumps.
	float speed_delta = 12.0*(mix(0.50,1.20,random.x)-1.0);
	float frequency = mix(0.9,1.4,random.y);
	float phase = random.z*6.283185;
	float surge = (2.4/frequency)*(sin(age*frequency+phase)-sin(phase));
	float distance = age*speed_delta+surge;
	return vec3(patch*life,distance,speed_delta+2.4*cos(age*frequency+phase));
}
float snow_local_gust(vec2 p, float clock) {
	return snow_local_event(p,clock).x;
}

uniform float wind_surface_strength = 0.0;
uniform float wind_surface_elapsed = 0.0;
uniform float wind_surface_travel = 0.0;
uniform vec2 wind_surface_focus;
uniform vec2 wind_surface_car;
#define wind_surface_flow surface_factors

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

#define ice_albedo surface_factors
#define ice_finish surface_factors
const bool winter_snow = false;
#define snow_albedo surface_factors
vec3 snow_detail(vec2 p) {
	vec3 snow = texture(snow_albedo,p/11.0).rgb;
	vec3 other = texture(snow_albedo,vec2(-p.y,p.x)/19.0+vec2(0.31,0.57)).rgb;
	// Lift the blue pigment in the original artwork toward neutral white.
	// Actual cool lighting/shadows and the sculpted texture remain intact.
	vec3 original = mix(snow,other,0.22)*0.82;
	float blue = smoothstep(0.015,0.15,original.b-original.r);
	vec3 artwork = mix(original,vec3(original.b*0.98,original.b,original.b*1.01),blue*0.42);
	// Ground, banks and deposited snow share the bank's accepted neutral-white
	// value treatment. Their cool colour comes from the scene light/shadows.
	float detail = dot(artwork,vec3(0.2126,0.7152,0.0722));
	return vec3(clamp(detail*1.06+0.09,0.0,0.82));
}
// Baked original colour factors, generated by scripts/bake-surface-detail.py.

// Sparse dielectric minerals; the normal lighting pass supplies real sun,
// shadow and view response. No emission, animation clock or extra texture.
uniform float desert_glint_strength : hint_range(0.0,1.0) = 1.0;
// Direction toward the approved desert sun (-46, -48 degrees).
uniform vec3 desert_sun_direction = vec3(-0.5162,0.71934,0.46484);
vec2 mineral_sun_finish(vec3 mineral, float footprint, float weight) {
	float grains = smoothstep(0.52,0.59,mineral.r)*smoothstep(0.34,0.45,mineral.b);
	float resolved = 1.0-smoothstep(0.10,0.28,footprint);
	float glint = clamp(grains*resolved*weight*desert_glint_strength,0.0,1.0);
	float facets = smoothstep(0.04,0.14,glint);
	return vec2(mix(1.0,0.34,facets),glint*0.70);
}

// Fine, differently oriented grain faces let flat terrain catch the same
// real sun as sloped banks. Only resolved reflecting grains perturb shading;
// albedo, macro dune shape, geometry and inactive finish remain unchanged.
vec3 mineral_terrain_normal(vec3 mineral, float footprint, float weight, vec3 original, mat4 view) {
	float grains = smoothstep(0.52,0.59,mineral.r)*smoothstep(0.34,0.45,mineral.b);
	float resolved = 1.0-smoothstep(0.10,0.28,footprint);
	float glint = clamp(grains*resolved*weight*desert_glint_strength,0.0,1.0);
	float facets = smoothstep(0.35,0.65,glint)*0.65;
	if (facets <= 0.001) return original;
	vec2 tilt = vec2(sin(mineral.g*6.28318530718),sin(mineral.r*23.0+mineral.b*7.0-2.0))*0.95;
	vec3 grain_tilt = (view*vec4(tilt.x,0.0,tilt.y,0.0)).xyz;
	vec3 facet_normal = normalize(original+grain_tilt*facets);
	vec3 sun = (view*vec4(desert_sun_direction,0.0)).xyz;
	// Restrict the added finish to sun-catching faces instead of introducing
	// dark granular holes into the approved dune artwork.
	if (dot(facet_normal,sun) <= dot(original,sun)+0.02) return original;
	return facet_normal;
}

vec2 desert_sand_finish(vec2 p, float weight) {
	vec3 mineral = texture(surface_factors,p/24.0,0.65).rgb;
	return mineral_sun_finish(mineral,length(fwidth(p)),weight);
}
const bool icy_road = false;
const bool wet_road = false;
uniform bool piece_materials = false;
const bool fixed_piece_materials = false;
uniform vec4 gravel_road_base : source_color = vec4(0.6745,0.5451,0.3529,1.0);
global uniform float storm_ripple_time;
global uniform bool storm_ripples_enabled;
const bool packed_sand = true;
const bool desert_dunes = true;
uniform sampler2D desert_apron : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D desert_road_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 desert_road_reference = vec2(0.50,0.22);
uniform sampler2D dune_factors : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dune_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

vec3 dune_sand(vec2 p) {
	// Broad crests and wind ripples stay in the original artwork. Multi-metre
	// mineral patches vary independently of the dune tile, without runtime noise.
	vec3 sand = texture(dune_albedo,p/28.0).rgb;
	// Keep the authored dune shapes; slightly strengthen their wind ripple values.
	float ripple = dot(sand,vec3(0.2126,0.7152,0.0722));
	sand *= 1.0+(ripple-0.5)*0.22;
	vec2 mineral = texture(surface_factors,p/96.0+vec2(0.17,0.43)).gb;
	vec3 pigment = mix(vec3(0.58,0.57,0.54),vec3(0.63,0.62,0.59),smoothstep(0.35,0.65,mineral.x));
	// Preserve pale crest highlights and deepen the warmer sheltered faces.
	float face = dot(sand,vec3(0.2126,0.7152,0.0722));
	sand *= 0.84+smoothstep(0.16,0.64,face)*0.28;
	return sand*pigment*(0.92+mineral.y*0.17);
}

vec3 dune_relief(vec2 p, vec3 original, mat4 view, float weight) {
	if (!desert_dunes || weight <= 0.001) return original;
	vec2 slope = (texture(dune_factors,p/32.0).gb-0.5)*0.58;
	vec3 relief = normalize(vec3(-slope.x,1.0,-slope.y));
	return normalize(mix(original,(view*vec4(relief,0.0)).xyz,clamp(weight,0.0,1.0)));
}
// Original world-space pigment pattern. Derivative filtering limits distant shimmer.
#define painted_grass_texture surface_factors
const bool hybrid_grass = false;
// Original industrial-outskirts artwork; scene lights supply all illumination.
const bool industrial_ground = false;
#define night_ground_albedo surface_factors

vec3 industrial_ground_color(vec2 p) {
	vec2 uv = p / 12.0;
	vec2 phase = fract(uv);
	// Hide arbitrary image borders with a narrow, derivative-continuous blend.
	// The central 80% retains coherent slabs; world UVs span every mesh/tile.
	vec2 weight = smoothstep(vec2(0.0),vec2(0.10),phase)
		* (vec2(1.0)-smoothstep(vec2(0.90),vec2(1.0),phase));
	vec3 a = texture(night_ground_albedo,uv,0.5).rgb;
	vec3 b = texture(night_ground_albedo,uv+vec2(0.5,0.0),0.5).rgb;
	vec3 c = texture(night_ground_albedo,uv+vec2(0.0,0.5),0.5).rgb;
	vec3 d = texture(night_ground_albedo,uv+vec2(0.5),0.5).rgb;
	vec3 artwork = mix(mix(d,c,weight.x),mix(b,a,weight.x),weight.y);
	return artwork * 0.85;
}

#define grass_albedo surface_factors
#define grass_macro_mask surface_factors
#define grass_normal surface_factors

vec3 grass_relief(vec2 p, vec3 original, mat4 view, float weight) {
	if (!hybrid_grass || weight <= 0.001) return original;
	vec3 detail = texture(grass_normal,p/0.8).rgb*2.0-1.0;
	float fade = 1.0-smoothstep(0.025,0.10,length(fwidth(p)));
	vec3 world_normal = normalize(vec3(detail.x*0.11*fade,1.0,detail.y*0.11*fade));
	return normalize(mix(original,(view*vec4(world_normal,0.0)).xyz,weight));
}
float pigment(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec3 a = fract(vec3(cell.xyx) * 0.1031);
	a += dot(a, a.yzx + 33.33);
	float n00 = fract((a.x + a.y) * a.z);
	a = fract(vec3((cell + vec2(1,0)).xyx) * 0.1031); a += dot(a,a.yzx+33.33);
	float n10 = fract((a.x+a.y)*a.z);
	a = fract(vec3((cell + vec2(0,1)).xyx) * 0.1031); a += dot(a,a.yzx+33.33);
	float n01 = fract((a.x+a.y)*a.z);
	a = fract(vec3((cell + vec2(1,1)).xyx) * 0.1031); a += dot(a,a.yzx+33.33);
	return mix(mix(n00,n10,f.x),mix(n01,fract((a.x+a.y)*a.z),f.x),f.y);
}
// Shared broken, short fixed_grass fringe for road shoulders and painted terrain.
float grass_fringe(float coverage, vec2 p) {
	return smoothstep(0.55,0.98,coverage+(pigment(p*5.0)-0.5)*0.32);
}
// Halfway between the original broken edge and the quieter smooth shoulder.
// Painted terrain keeps its own fringe; only roadside fixed_grass uses this blend.
float shoulder_fringe(float coverage, vec2 p) {
	float settled = smoothstep(0.60,0.94,coverage+(texture(surface_factors,p/16.0).g-0.5)*0.04);
	return mix(settled,grass_fringe(coverage,p),0.5);
}
// Matte sand shared by terrain paint and roadside shoulders. Grain is
// isotropic (no fixed_grass-like diagonal strokes), with filtered fine minerals.
vec3 sand_detail(vec3 base, vec2 p) {
	if (winter_snow) return snow_detail(p);
	if (desert_dunes) return dune_sand(p);
	return base * (0.8 + texture(surface_factors,p/32.0).b * 0.4);
}

// Original sand pigment is retained; shallow mineral relief supplies actual
// directional light response instead of adding another colour/noise pattern.
uniform bool sand_relief_enabled = true;
vec3 sand_relief(vec2 p, vec3 original, mat4 view, float weight) {
	if (!sand_relief_enabled || winter_snow || desert_dunes || packed_sand || weight <= 0.001) return original;
	vec2 uv = p/32.0;
	float h = texture(surface_factors,uv).b;
	vec2 slope = vec2(texture(surface_factors,uv+vec2(0.06/32.0,0.0)).b-h,
		texture(surface_factors,uv+vec2(0.0,0.06/32.0)).b-h)*0.90;
	float fade = 1.0-smoothstep(0.12,0.35,length(fwidth(p)));
	vec3 relief = normalize(vec3(-slope.x*fade,1.0,-slope.y*fade));
	return normalize(mix(original,(view*vec4(relief,0.0)).xyz,clamp(weight,0.0,1.0)));
}

// Fine mineral grain on an even sandy bank, distinct from the smooth road.
vec3 desert_shoulder(vec3 base, vec2 p) {
	vec3 grit = texture(desert_apron,p/6.0).rgb;
	// Remove the artwork's broad pigment patches while retaining fine grit.
	// Mip-filtered local colour is subtracted, not painted as another deposit mask.
	vec3 local_sand = texture(desert_apron,p/6.0,5.0).rgb;
	float drift = texture(surface_factors,p/52.0+vec2(0.13,0.71)).g;
	return max(base*(0.93+(drift-0.5)*0.10)+(grit-local_sand)*0.52,vec3(0.0));
}

// Shared world-space baked asphalt. Random repair/crack shapes are removed;
// binder variation and mineral grain remain presentation-only.
vec3 dry_asphalt_detail(vec3 base, vec2 p) {
	// Fine aggregate stays subordinate to multi-metre binder variation.
	// Both fields reuse the baked factors; no per-frame noise or decals.
	float grain = texture(surface_factors,p/32.0,0.75).r;
	float broad = texture(surface_factors,p/384.0+vec2(0.23,0.41)).g;
	return base * (1.015+(grain-0.54)*0.22+(broad-0.5)*0.04);
}

// Night-only abandoned industrial road finish. One baked, mipfiltered data
// sample supplies oxidized binder, irregular old repairs and branching cracks.
// World coordinates continue across road pieces, painted asphalt and bridges.
const bool industrial_asphalt = false;
#ifdef BMT_NIGHT_ASPHALT
#define night_asphalt_wear surface_factors
#else
// Unspecialized non-Night bridges must also retain their original texture units.
#define night_asphalt_wear surface_factors
#endif
vec3 industrial_asphalt_detail(vec3 base, vec2 p) {
	vec3 wear = texture(night_asphalt_wear,p/48.0).rgb;
	float grain = texture(surface_factors,p/32.0,0.25).r-0.54;
	float mineral = texture(surface_factors,p/13.0,0.5).b-0.45;
	vec3 faded = base*vec3(1.24,1.20,1.12)*(0.96+wear.r*0.68+grain*0.70);
	faded += base*mineral*(0.20+wear.r*0.50);
	vec3 tar = base*(0.70+grain*0.28);
	vec3 asphalt = mix(faded,tar,wear.g*0.82);
	return asphalt*(1.0-wear.b*0.66);
}

// Wet asphalt is the baseline. Only the upper tail of the metre-scale basin
// field contains standing water; aggregate never drives puddle boundaries.
float road_puddle(vec2 p) {
 float basin = pigment(p*0.22+vec2(3.2,7.6))*0.70;
 basin += pigment(p*0.71+vec2(11.7,2.4))*0.24;
 basin += pigment(p*2.7+vec2(6.1,19.3))*0.06;
 float feather = max(fwidth(basin),0.008);
 return smoothstep(0.65-feather,0.72+feather,basin);
}

float wet_road_roughness(vec2 p) {
 float pool = road_puddle(p);
 float grain = (texture(surface_factors,p/32.0).r-0.54)*0.16;
 // Retain fine surface variation in standing water without losing its sheen.
 return mix(clamp(0.38+grain,0.33,0.43),clamp(0.18+grain*0.6,0.15,0.21),pool);
}

float wet_road_specular(vec2 p) {
 // Water-filled depressions retain a stronger environment highlight than
 // exposed binder/aggregate. The road remains a non-metallic dielectric.
 return mix(0.28,0.52,road_puddle(p));
}

// One contained impact per world-space cell; no neighbour search or particles.
vec2 rain_impact_hash(vec2 p) {
 vec3 h = fract(vec3(p.x,p.y,p.x)*vec3(0.1031,0.1030,0.0973));
 h += dot(h,h.yzx+33.33);
 return fract((h.xx+h.yz)*h.zy);
}

vec2 rain_impact_slope(vec2 p) {
 vec2 cell = floor(p/0.42);
 vec2 seed = rain_impact_hash(cell);
 float clock = storm_ripple_time+seed.x*0.38;
 float event = floor(clock/0.38);
 vec2 center = rain_impact_hash(cell+event*vec2(17.1,39.7));
 vec2 offset = fract(p/0.42)*0.42-(vec2(0.12)+center*0.18);
 float age = mod(clock,0.38);
 float radius = length(offset);
 float wave = clamp((radius-age*0.30)*35.0,-1.0,1.0);
 float envelope = smoothstep(0.0,0.025,age)*(1.0-smoothstep(0.14,0.26,age));
 float shoulder = 1.0-wave*wave;
 float ring = wave*shoulder*shoulder*4.0*envelope;
 return offset/max(radius,0.001)*ring*0.22;
}

vec3 wet_road_relief(vec2 p, vec3 original, mat4 view, float weight) {
 // Terrain uses this helper too: fixed_grass/sand pixels have no wet road weight.
 if (weight <= 0.001) return original;
 vec2 grain = vec2(texture(surface_factors,p/8.0).g,texture(surface_factors,p/8.0+vec2(0.37,0.61)).g)-vec2(0.5);
 float pool = road_puddle(p);
 float strength = mix(0.16,0.045,pool);
 strength *= 1.0-smoothstep(0.10,0.35,length(fwidth(p)));
 vec2 slope = grain*strength;
 if (storm_ripples_enabled) {
  float visibility = 1.0-smoothstep(0.18,0.40,length(fwidth(p)));
  if (pool*visibility*weight > 0.001) slope += rain_impact_slope(p)*pool*visibility;
 }
 vec3 ripple = (view*vec4(slope.x,0.0,slope.y,0.0)).xyz;
 return normalize(original+ripple*weight);
}

vec3 surface_detail(vec3 base, vec2 p, bool road) {
	float visibility = 1.0 - smoothstep(0.05,0.22,length(fwidth(p)));
	if (road && packed_sand) {
		float broad = texture(surface_factors,p/64.0).g;
		float grain = texture(surface_factors,p/32.0).r;
		return base * (0.97+(broad-0.5)*0.025+(grain-0.54)*0.035);
	}
	if (road && wet_road) {
		float grain = clamp((texture(surface_factors,p/32.0).r-0.54)*2.0,-0.3,0.3);
		float film = road_puddle(p);
		return base*mix(0.76,0.65,film)*(1.0+grain*mix(0.3,0.14,film));
	}
	if (road && icy_road) {
		return quiet_winter_ice(texture(ice_albedo,p/6.0).rgb);
	}
	if (road) { return industrial_asphalt ? industrial_asphalt_detail(base,p) : dry_asphalt_detail(base,p); }

	// Sparse short blade strokes rather than circular noise clouds.
	vec2 cell = floor(p * 2.4);
	float seed = fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	float other = fract(sin(dot(cell,vec2(269.5,183.3)))*43758.5453);
	vec2 local = fract(p * 2.4) - vec2(0.25+seed*0.5,0.25+other*0.5);
	float blade = (1.0-smoothstep(0.025,0.09,abs(local.x + local.y*(seed-0.5)*1.5)))
		* smoothstep(-0.35,-0.1,local.y) * (1.0-smoothstep(0.05,0.32,local.y));
	blade *= step(0.72,seed) * visibility;
	float plane = smoothstep(0.35,0.65,pigment(p*0.12));
	return base * (0.97 + plane*0.055 - blade*0.09);
}

// Filter baked grain along the local road axis for compacted sandy wear.
vec3 packed_wear(vec3 base, vec2 road_uv) {
 float tracks = texture(surface_factors,road_uv/vec2(45.0,4.0)).g;
 float broad = texture(surface_factors,road_uv/vec2(140.0,32.0)).g;
 float grooves = texture(surface_factors,road_uv/vec2(19.0,1.3)).g;
 return base*(1.0+(tracks-0.5)*0.015+(broad-0.5)*0.010+(grooves-0.5)*0.008);
}

// Offset phases hide texture boundaries; actual metre UVs turn the grooves
// with the road instead of painting an isotropic cloud over it.
vec3 compacted_road(vec3 base, vec2 metres) {
	vec2 uv = metres.yx/vec2(6.5,10.0);
	vec2 f = fract(uv);
	vec2 w = smoothstep(vec2(0.0),vec2(0.12),f)*(vec2(1.0)-smoothstep(vec2(0.88),vec2(1.0),f));
	vec3 a = texture(desert_road_albedo,uv,0.75).rgb;
	vec3 b = texture(desert_road_albedo,uv+vec2(0.5,0.0),0.75).rgb;
	vec3 c = texture(desert_road_albedo,uv+vec2(0.0,0.5),0.75).rgb;
	vec3 d = texture(desert_road_albedo,uv+vec2(0.5,0.5),0.75).rgb;
	vec3 artwork = mix(mix(d,c,w.x),mix(b,a,w.x),w.y);
	float reference_value = OUTPUT_IS_SRGB ? desert_road_reference.x : desert_road_reference.y;
	float pressed = clamp(dot(artwork,vec3(0.2126,0.7152,0.0722))/reference_value,0.82,1.18);
	return base*mix(0.99,pressed,0.25);
}

vec3 road_gravel_color(vec2 metres) {
	// The existing Desert road's settled directional texture and warm palette.
	return compacted_road(gravel_road_base.rgb,metres)*(wet_road ? 0.84 : 1.0);
}

vec2 road_material_metres(vec2 p, vec2 encoded_axis) {
	float angle = 0.5*atan(encoded_axis.y,encoded_axis.x+0.000001);
	vec2 axis = vec2(cos(angle),sin(angle));
	return vec2(dot(p,axis),dot(p,vec2(-axis.y,axis.x)));
}

float road_material_coverage(float weight, vec2 p) {
	float grains = texture(surface_factors,p/5.0).g-0.5;
	return clamp(weight+grains*0.12*4.0*weight*(1.0-weight),0.0,1.0);
}

// Winter's bank foot uses a settled deposit broken into wind-sized tongues
// and fine grains. Reuse that shoulder blend across the wider sand apron.
float desert_bank_coverage(float across, vec2 p) {
	float breakup = pigment(p*0.73+vec2(17.3,8.1))-0.5;
	float deposited = smoothstep(0.05,0.90,across)+breakup*0.30*4.0*across*(1.0-across);
	return shoulder_fringe(mix(0.48,1.06,clamp(deposited,0.0,1.0)),p);
}

// World-space grain avoids phase resets and triangular UV patches at joins.
vec3 packed_wear_world(vec3 base, vec2 p, vec2 axis) {
	float angle = atan(axis.y,axis.x+0.000001)*0.5;
	vec2 direction = vec2(cos(angle),sin(angle));
	float grain = texture(surface_factors,p/32.0).g*0.50;
	grain += texture(surface_factors,(p+direction*0.32)/32.0).g*0.25;
	grain += texture(surface_factors,(p-direction*0.32)/32.0).g*0.25;
	return base*(1.0+(grain-0.5)*0.05);
}

// Short, broken laying/wear grain aligned to the local road tangent. Sample
// the same world-space field on both sides, so reversed pieces agree and
// changing direction through a bend does not rotate texture coordinates.
vec3 directional_asphalt(vec3 base, vec2 p, vec2 encoded_axis) {
	float strength = smoothstep(0.15,0.75,length(encoded_axis));
	float angle = atan(encoded_axis.y,encoded_axis.x+0.000001)*0.5;
	vec2 direction = vec2(cos(angle),sin(angle));
	float worn = texture(surface_factors,p/32.0).g*0.4;
	worn += texture(surface_factors,(p+direction*0.28)/32.0).g*0.24;
	worn += texture(surface_factors,(p-direction*0.28)/32.0).g*0.24;
	worn += texture(surface_factors,(p+direction*0.56)/32.0).g*0.06;
	worn += texture(surface_factors,(p-direction*0.56)/32.0).g*0.06;
	float breakup = smoothstep(0.25,0.75,pigment(p*0.73+vec2(13.1,6.4)));
	return base*(1.0+(worn-0.5)*0.15*mix(0.25,1.0,breakup)*strength);
}

vec3 painted_grass(vec3 base, vec2 p) {
	if (industrial_ground) return industrial_ground_color(p);
	if (winter_snow) return snow_detail(p);
	if (desert_dunes) return dune_sand(p);
	if (hybrid_grass) {}
	// Cool neutral palettes use snow/concrete grain without green brush pigment.
	if (base.b > base.r * 0.95) return base * (0.94 + pigment(p * 0.7) * 0.06);
	// A 20 m tile gives legible brush clusters at driving scale. An offset
	// second sample and slower colour mask soften recognizable repetition.
	vec3 paint = texture(painted_grass_texture,p/20.0,0.75).rgb;
	vec3 broad = texture(painted_grass_texture,p/47.0+vec2(0.37,0.61),1.0).rgb;
	vec3 tint = base / vec3(0.3765,0.4196,0.2118);
	return mix(mix(paint,broad,0.18)*tint,base,0.18)*(0.82+pigment(p*0.08)*0.10);
}

vec2 winter_road_uv(vec2 metres) { return metres.yx/vec2(5.0,9.0); }

float winter_edge_frost(vec2 uv, vec2 p, float half_width) {
	float tongues = (pigment(p*0.73+vec2(17.3,8.1))-0.5)*0.85;
	float edge = 1.0-smoothstep(-0.25,2.80,half_width-abs(uv.y)+tongues);
	// Exactly the same settled/broken fringe method as the Grass shoulder.
	return shoulder_fringe(mix(0.48,1.05,edge),p);
}

vec3 winter_wear_width(vec2 uv, vec2 p, float half_width) {
	vec2 ice_uv = winter_road_uv(uv);
	vec3 artwork = texture(ice_albedo,ice_uv).rgb;
	vec3 local_ice = texture(ice_albedo,ice_uv,3.0).rgb;
	// Fine crystalline abrasion adds ice detail without strengthening broad threads.
	vec3 ice = quiet_winter_ice(artwork)+(artwork-local_ice)*0.22;
	// Whiten only fine positive scrape detail; broad directional threads stay quiet.
	float crystals = smoothstep(0.025,0.14,dot(artwork-local_ice,vec3(0.2126,0.7152,0.0722)));
	ice = mix(ice,vec3(0.84,0.86,0.87),crystals*0.55);
	float frost = texture(surface_factors,p/90.0,4.0).g;
	float dust = smoothstep(0.43,0.70,frost);
	float edge_snow = winter_edge_frost(uv,p,half_width)*0.68;
	// Faint frosted wheel paths follow the authored road axis through bends.
	float path = 1.0-smoothstep(0.07,0.20,abs(abs(uv.y)-1.15));
	float older = 1.0-smoothstep(0.04,0.14,abs(abs(uv.y)-1.62));
	float wear = texture(surface_factors,p/70.0,3.0).r;
	ice = mix(ice,vec3(0.77,0.80,0.82),(path*0.07+older*0.04)*smoothstep(0.22,0.72,wear));
	vec3 powder = mix(snow_detail(p),vec3(0.80,0.83,0.85),0.40);
	return mix(ice,powder,min(dust*0.20+edge_snow,1.0));
}

vec3 winter_wear(vec3 base, vec2 uv, vec2 p) { return winter_wear_width(uv,p,5.0); }

vec3 winter_ice_normal(vec2 slopes, vec3 original, mat4 view, vec2 p, float weight) {
	float detail = 1.0-smoothstep(0.08,0.25,length(fwidth(p)));
	vec2 slope = (slopes*2.0-1.0)*0.12*detail;
	return normalize(original+(view*vec4(-slope.x,0.0,-slope.y,0.0)).xyz*weight);
}

vec3 winter_road_ice_normal(vec2 slopes, vec3 original, mat4 view, vec2 p, vec2 road_uv) {
	// Transform baked texture slopes using the actual road-coordinate Jacobian.
	// This follows curves and rotated bridges without assuming world X/Z grain.
	vec2 dx = dFdx(p), dy = dFdy(p);
	float determinant = dx.x*dy.y-dx.y*dy.x;
	vec2 slope = (slopes*2.0-1.0)*0.09;
	float hx = dot(slope,dFdx(road_uv)), hy = dot(slope,dFdy(road_uv));
	vec2 gradient = abs(determinant) > 0.000001 ? vec2(hx*dy.y-hy*dx.y,hy*dx.x-hx*dy.x)/determinant : vec2(0.0);
	return normalize(original+(view*vec4(-gradient.x,0.0,-gradient.y,0.0)).xyz);
}

vec3 winter_snow_relief(vec2 p, vec3 original, mat4 view, float weight) {
	// The owner prefers the original textured snowfield; no cloud-like tilts.
	return original;
}

#include "res://track/kerb_paint.gdshaderinc"

uniform sampler2D overlay_mask : filter_nearest, repeat_disable;
uniform sampler2D verge_blend_mask : filter_linear, repeat_disable;
uniform sampler2D road_mask : filter_linear, repeat_disable;
uniform vec2 road_mask_texel;
uniform vec4 sand_color : source_color;
uniform vec2 map_extent;
uniform vec4 road_color : source_color;
uniform vec4 asphalt_base_color : source_color;
uniform bool gravel = false;
const bool fixed_gravel = true;
uniform bool grass_shoulder = false;
const bool fixed_grass_shoulder = false;
uniform bool grass = false;
const bool fixed_grass = false;
uniform bool kerb = false;
const bool fixed_kerb = false;
uniform bool asphalt_surface = false;
const bool fixed_asphalt_surface = false;
uniform bool edge_fringe = false;
uniform bool raised_road_edge = false;
const bool fixed_raised_road_edge = false;
uniform bool road_marking = false;
const bool fixed_road_marking = false;
uniform bool winter_width_data = false;
const bool fixed_winter_width_data = false;
uniform vec4 kerb_pale : source_color = vec4(0.87,0.867,0.827,1.0);
uniform vec4 grass_color : source_color;
varying vec3 world_position;
varying float bank_slope;
varying float winter_half_width;
varying vec4 desert_join;

void vertex() {
	bank_slope = 1.0-NORMAL.y;
	winter_half_width = COLOR.r*32.0;
	desert_join = COLOR;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Filter only the decorative sand join; road/marking masks stay exact.
float sand_coverage(vec2 uv) {
	vec2 d = 0.65 / vec2(textureSize(verge_blend_mask,0));
	float value = texture(verge_blend_mask,uv).b * 4.0;
	value += 2.0*(texture(verge_blend_mask,uv+vec2(d.x,0.0)).b+texture(verge_blend_mask,uv-vec2(d.x,0.0)).b);
	value += 2.0*(texture(verge_blend_mask,uv+vec2(0.0,d.y)).b+texture(verge_blend_mask,uv-vec2(0.0,d.y)).b);
	value += texture(verge_blend_mask,uv+d).b+texture(verge_blend_mask,uv-d).b;
	value += texture(verge_blend_mask,uv+vec2(d.x,-d.y)).b+texture(verge_blend_mask,uv+vec2(-d.x,d.y)).b;
	float sand = value / 16.0;
	if (sand > 0.001 && sand < 0.999) {
		sand = 1.0-grass_fringe(mix(0.55,0.98,1.0-sand),world_position.xz);
	}
	return sand;
}

void fragment() {
	vec2 map_uv = (world_position.xz + map_extent) / (map_extent * 2.0);
	// Every painted cell wins over the procedural road, including asphalt
	// paint used to open a junction. Obstacles keep their native footprints.
	if (any(lessThan(map_uv, vec2(0.0))) || any(greaterThan(map_uv, vec2(1.0)))
			|| texture(overlay_mask, map_uv).r < 0.5) { discard; }
	// Keep-road protects the road mesh, not its fixed_grass skirt or fixed_gravel fringe.
	vec3 mask = texture(overlay_mask,map_uv).rgb;
	float loose_road = fixed_piece_materials && (fixed_asphalt_surface || fixed_road_marking) ? texture(road_mask,map_uv).g : 0.0;
	if (fixed_piece_materials) {}
	vec2 material_metres = road_material_metres(world_position.xz,UV2);
	if ((fixed_grass || fixed_gravel) && mask.g < 0.5 && mask.b < 0.5) { discard; }
	float sand = 0.0;
	if (fixed_gravel || (fixed_grass && !winter_snow && !desert_dunes)) { sand = sand_coverage(map_uv); }
	float relief_weight = fixed_grass ? (1.0-sand) : 0.0;
	// Avoid shading a base that the fixed material role immediately replaces.
	if (fixed_asphalt_surface && icy_road && !edge_fringe) {}
	else if (fixed_asphalt_surface && packed_sand) {}
	else if (!(fixed_grass || fixed_gravel || fixed_kerb)) { ALBEDO = surface_detail(road_color.rgb, world_position.xz, fixed_asphalt_surface); }
	if (fixed_asphalt_surface && packed_sand && desert_join.a > 0.001) {}
	if (fixed_asphalt_surface && !wet_road && !icy_road && !packed_sand) {}
	float wet_coverage = wet_road && fixed_asphalt_surface ? 1.0 : 0.0;
	if (edge_fringe && !icy_road) {
		// UV.y spans the cosmetic blend strip (1.95 m for desert), so
		// curves never inherit the coarse canonical surface-grid staircase.
		float breakup = pigment(world_position.xz * (packed_sand ? 0.18 : 5.5) + vec2(4.1, 13.7));
		float cutoff = 0.84 + (breakup - 0.5) * 0.22;
		// Reuse the fixed_grass/sand shoulder's settled + broken fringe blend.
		// Remap it across a wider band, retaining texture through the transition.
		float asphalt_coverage = packed_sand ? 1.0-desert_bank_coverage(UV.y,world_position.xz) : 1.0 - smoothstep(cutoff - 0.30, cutoff + 0.20, UV.y);
		// Below the raised lip this is sand, with only sparse asphalt crumbs.
		if (fixed_raised_road_edge) asphalt_coverage = 0.08*(1.0-smoothstep(0.0,0.35,UV.y))*breakup;
		vec3 shoulder = packed_sand ? desert_shoulder(sand_color.rgb,world_position.xz) : sand_detail(sand_color.rgb, world_position.xz);
		ALBEDO = mix(shoulder, ALBEDO, asphalt_coverage);
		// Six-centimetre soft contact band, filtered with the existing strip UV.
		if (fixed_raised_road_edge) ALBEDO *= 1.0-0.18*(1.0-smoothstep(0.0,0.30,UV.y))*(0.75+0.25*breakup);
		wet_coverage *= asphalt_coverage;
	}
	if (fixed_raised_road_edge && !edge_fringe) ALBEDO *= desert_join.a;
	if (fixed_road_marking) {}
	if (fixed_grass) {}
	if (fixed_kerb) {}
	if (fixed_gravel) {
		ALBEDO = packed_sand ? desert_shoulder(road_color.rgb,world_position.xz) : sand_detail(road_color.rgb,world_position.xz);
		if (packed_sand) {
			float contact = 1.0-smoothstep(0.10,0.32,UV.y);
			ALBEDO *= 1.0-contact*0.025;
		}
		float fringe;
		if (packed_sand) {
			float drift_edge = UV.y+(texture(surface_factors,world_position.xz/28.0).g-0.5)*0.24*4.0*UV.y*(1.0-UV.y);
			fringe = smoothstep(0.58,1.0,drift_edge)*(1.0-sand);
		} else { fringe = (hybrid_grass ? shoulder_fringe(UV.y,world_position.xz) : grass_fringe(UV.y,world_position.xz))*(1.0-sand); }
		ALBEDO = mix(ALBEDO,painted_grass(grass_color.rgb,world_position.xz),fringe);
		relief_weight = fringe;
		if (fixed_grass_shoulder) {}
	}
	if (loose_road > 0.0 && fixed_asphalt_surface) {
		float coverage = edge_fringe ? 1.0-smoothstep(0.3,1.0,UV.y) : 1.0;
		vec3 stone = road_gravel_color(material_metres);
		if (fixed_raised_road_edge && !edge_fringe) {}
		ALBEDO = mix(ALBEDO,stone,loose_road*coverage);
		wet_coverage *= 1.0-loose_road;
	}
	if (fixed_piece_materials && fixed_road_marking) {}
	ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 if (icy_road && fixed_asphalt_surface && !edge_fringe) {}
 if (wet_road && wet_coverage > 0.0) {}
 if (wet_road && (fixed_road_marking || fixed_kerb)) {}
	bool verge_detail = fixed_grass_shoulder && UV.x < -0.5;
	NORMAL = grass_relief(world_position.xz,NORMAL,VIEW_MATRIX,verge_detail ? 0.0 : relief_weight);
	NORMAL = sand_relief(world_position.xz,NORMAL,VIEW_MATRIX,verge_detail ? 0.0 : (fixed_grass || fixed_gravel) ? (1.0-relief_weight)*(fixed_grass_shoulder ? 0.25 : 1.0) : 0.0);
	if (loose_road > 0.0 && fixed_asphalt_surface) NORMAL = sand_relief(world_position.xz,NORMAL,VIEW_MATRIX,loose_road*0.25);
	NORMAL = winter_snow_relief(world_position.xz,NORMAL,VIEW_MATRIX,(fixed_grass || fixed_gravel) ? 1.0 : 0.0);
	// Cosmetic skirts/loose sand carry dunes; the firm timed road stays smooth.
	NORMAL = dune_relief(world_position.xz,NORMAL,VIEW_MATRIX,fixed_grass ? 1.0 : (fixed_gravel ? smoothstep(0.6,1.0,UV.y)*(1.0-sand) : 0.0));
 if (desert_dunes && (fixed_grass || fixed_gravel)) {
  vec3 mineral = texture(surface_factors,world_position.xz/24.0,0.65).rgb;
  float footprint = length(fwidth(world_position.xz));
  vec2 finish = mineral_sun_finish(mineral,footprint,1.0);
  ROUGHNESS = finish.x;
  SPECULAR = finish.y;
  if (fixed_grass) NORMAL = mineral_terrain_normal(mineral,footprint,1.0,NORMAL,VIEW_MATRIX);
 }
 if (wet_road) NORMAL = wet_road_relief(world_position.xz,NORMAL,VIEW_MATRIX,wet_coverage);
	if (winter_snow && !fixed_kerb && !fixed_road_marking) {}
}

