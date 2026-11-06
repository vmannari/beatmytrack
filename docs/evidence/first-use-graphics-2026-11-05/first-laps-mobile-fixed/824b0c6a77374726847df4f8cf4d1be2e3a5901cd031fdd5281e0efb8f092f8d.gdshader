shader_type spatial;
render_mode diffuse_lambert, specular_disabled, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D density_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 sand_color : source_color = vec4(0.75686, 0.64314, 0.47059, 1.0);
uniform float elapsed = 0.0;
uniform float strength = 0.0;
uniform float lift_history[48];
uniform float lift_elapsed = 0.0;
uniform vec3 focus;
uniform float source_fade_start = 14.0;
uniform float source_fade_end = 20.0;
varying vec3 world_position;
varying float presence;
varying float center_height;
varying vec2 field_position;
varying vec3 root_position;

float sand_hash(float p) {
    return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

float emission(float time, float seed) {
    float period = 2.4 + sand_hash(seed + 3.0) * 1.6;
    float clock = time + seed * 31.0;
    float cycle = floor(clock / period);
    float local_time = mod(clock, period);
    float event_seed = sand_hash(seed * 39.0 + cycle * 7.0);
    float start = 0.20 + event_seed * 0.40;
    float duration = min(mix(1.1, 1.65, sand_hash(event_seed + 9.0)), period - start - 0.15);
    return smoothstep(start, start + 0.25, local_time)
        * (1.0 - smoothstep(start + duration - 0.45, start + duration, local_time));
}

float audible_lift(float age) {
    float at = clamp((age - lift_elapsed) * 12.0, 0.0, 46.0);
    int index = int(floor(at));
    return mix(lift_history[index], lift_history[index + 1], fract(at));
}

void vertex() {
    float patch_seed = INSTANCE_CUSTOM.x;
    float id = INSTANCE_CUSTOM.y;
    float variation = INSTANCE_CUSTOM.z;
    // Even age spacing avoids piles of coincident cards at the narrow root.
    float life = mix(2.8, 3.6, sand_hash(patch_seed + 11.0));
    float age = fract(elapsed / life + id) * life;
    float u = age / life;
    vec3 wind = normalize(MODEL_MATRIX[0].xyz);
    vec3 side = normalize(MODEL_MATRIX[2].xyz);
    vec3 center = MODEL_MATRIX[3].xyz;
    root_position = center;
    center += wind * age * mix(1.8, 2.8, patch_seed) * mix(0.75, 1.0, strength);
    // Each instance starts at a traced texture edge; scatter begins in flight.
    center += side * age * (variation - 0.5) * 0.20;
    center.y += 0.015 + sin(u * PI) * mix(0.30, 0.85, variation);
    center_height = center.y;
    vec3 facing = normalize(INV_VIEW_MATRIX[2].xyz);
    vec3 along_view = normalize(wind - facing * dot(wind, facing));
    vec3 across_view = normalize(cross(facing, along_view));
    float spread = smoothstep(0.0, 0.20, u);
    vec3 at = center + along_view * VERTEX.x * mix(0.10, mix(2.0, 8.5, u), spread)
        + across_view * VERTEX.y * mix(0.08, mix(0.8, 3.0, u), spread);
    VERTEX = transpose(mat3(MODEL_MATRIX)) * (at - MODEL_MATRIX[3].xyz);
    NORMAL = vec3(0.0, 1.0, 0.0);
    world_position = at;
    // Audible swells can always lift a stream; local eddies preserve variation.
    float sound_birth = sqrt(max(0.0, audible_lift(age))) * mix(0.80, 1.0, variation);
    presence = step(age, elapsed) * max(emission(elapsed - age, patch_seed), sound_birth) * smoothstep(0.0, 0.025, age)
        * (1.0 - smoothstep(0.58, 1.0, u)) * mix(1.0, 0.80, u);
    vec3 world_wind = normalize(vec3(0.91, 0.0, -0.414608));
    vec3 world_side = vec3(-world_wind.z, 0.0, world_wind.x);
    field_position = vec2(dot(at, world_wind), dot(at, world_side));
}

void fragment() {
    if (strength <= 0.0 || presence <= 0.005) discard;
    float distance_fade = 1.0 - smoothstep(14.0, 20.0, length(world_position.xz - focus.xz));
    distance_fade *= 1.0 - smoothstep(source_fade_start, source_fade_end, length(root_position.xz - focus.xz));
    if (distance_fade <= 0.0) discard;
    vec2 flow = field_position * vec2(0.11, 0.32) - vec2(elapsed * 0.25, 0.0);
    vec3 broad = texture(density_texture, flow * 0.48).rgb;
    vec3 density = texture(density_texture, flow + (broad.rg - 0.5) * 0.28).rgb;
    vec2 p = UV * 2.0 - 1.0 + (broad.rg - 0.5) * 0.22;
    float rim = 1.0 - smoothstep(0.08, 1.0, length(p));
    float wisps = smoothstep(0.22, 0.70, density.r) * mix(0.30, 1.0, density.g);
    float shape = rim * rim * wisps * mix(0.80, 1.0, density.b);
    if (shape <= 0.005) discard;
    float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    float gap = -view.z / view.w + VERTEX.z;
    float intersection = smoothstep(0.0, 0.16, gap);
    vec4 opaque_world = INV_VIEW_MATRIX * view;
    // Proxy corners cannot place low powder above a taller car/bridge roof.
    intersection *= 1.0 - smoothstep(center_height, center_height + 0.06, opaque_world.y / opaque_world.w);
    // Airborne sunlit powder keeps the terrain hue while lifting its value
    // enough to read against similarly coloured ground at the driving zoom.
    float pigment_value = 1.35;
    float pigment_saturation = 0.48;
    float opacity = 0.38;
    float opacity_cap = 0.043;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    // Stay below this renderer's bright-channel clipping point, preserving hue.
    pigment_value = 1.0;
    pigment_saturation = 0.58;
    opacity = 0.42;
    opacity_cap = 0.07;
#endif
    // Fine airborne grains scatter a little more neutral light than the
    // settled pigment. Preserve its warm hue without dense yellow cores.
    vec3 pigment = mix(vec3(dot(sand_color.rgb, vec3(0.2126, 0.7152, 0.0722))), sand_color.rgb, pigment_saturation);
    ALBEDO = pigment * pigment_value * mix(0.97, 1.02, density.r);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    // Preserve broken wisps at driving scale; sparse cores need contrast
    // against sunlit dune detail while their feathered tails stay transparent.
    // Keep a tightly shared root from becoming an opaque overlapping core.
    ALPHA = min(opacity_cap, opacity * strength * presence * sqrt(shape) * distance_fade * intersection);
}
