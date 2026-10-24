shader_type spatial;
render_mode diffuse_lambert, specular_disabled, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D density_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 sand_color : source_color = vec4(0.72157, 0.69412, 0.65490, 1.0);
uniform float elapsed = 0.0;
uniform float strength = 0.0;
uniform vec3 focus;
varying vec3 world_position;
varying float presence;
varying float center_height;
varying vec2 field_position;

float sand_hash(float p) {
    return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

float emission(float time, float seed) {
    float period = 6.0 + sand_hash(seed + 3.0) * 5.0;
    float clock = time + seed * 31.0;
    float cycle = floor(clock / period);
    float local_time = mod(clock, period);
    float event_seed = sand_hash(seed * 39.0 + cycle * 7.0);
    float start = 0.8 + event_seed * 1.3;
    float duration = mix(1.8, 4.2, sand_hash(event_seed + 9.0));
    return step(0.12, event_seed) * smoothstep(start, start + 0.25, local_time)
        * (1.0 - smoothstep(start + duration - 0.45, start + duration, local_time));
}

void vertex() {
    float patch_seed = INSTANCE_CUSTOM.x;
    float id = INSTANCE_CUSTOM.y;
    float variation = INSTANCE_CUSTOM.z;
    float life = mix(2.2, 3.6, sand_hash(variation + patch_seed));
    float age = fract(elapsed / life + id) * life;
    float u = age / life;
    vec3 wind = normalize(MODEL_MATRIX[0].xyz);
    vec3 side = normalize(MODEL_MATRIX[2].xyz);
    vec3 center = MODEL_MATRIX[3].xyz;
    center += wind * age * mix(1.6, 3.2, variation) * mix(0.75, 1.0, strength);
    center += side * ((sand_hash(id * 83.0 + patch_seed) - 0.5) * 2.2 + age * (variation - 0.5) * 0.20);
    center.y += 0.06 + sin(u * PI) * mix(0.30, 0.85, variation);
    center_height = center.y;
    vec3 facing = normalize(INV_VIEW_MATRIX[2].xyz);
    vec3 along_view = normalize(wind - facing * dot(wind, facing));
    vec3 across_view = normalize(cross(facing, along_view));
    vec3 at = center + along_view * VERTEX.x * mix(1.2, 4.8, u)
        + across_view * VERTEX.y * mix(0.65, 2.8, u);
    VERTEX = transpose(mat3(MODEL_MATRIX)) * (at - MODEL_MATRIX[3].xyz);
    NORMAL = vec3(0.0, 1.0, 0.0);
    world_position = at;
    presence = emission(elapsed - age, patch_seed) * smoothstep(0.0, 0.12, u)
        * (1.0 - smoothstep(0.58, 1.0, u));
    vec3 world_wind = normalize(vec3(0.91, 0.0, -0.414608));
    vec3 world_side = vec3(-world_wind.z, 0.0, world_wind.x);
    field_position = vec2(dot(at, world_wind), dot(at, world_side));
}

void fragment() {
    if (strength <= 0.0 || presence <= 0.005) discard;
    float distance_fade = 1.0 - smoothstep(14.0, 20.0, length(world_position.xz - focus.xz));
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
    ALBEDO = sand_color.rgb * mix(0.97, 1.02, density.r);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    ALPHA = 0.28 * strength * presence * shape * distance_fade * intersection;
}
