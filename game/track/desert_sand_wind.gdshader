shader_type spatial;
render_mode diffuse_lambert, specular_disabled, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float elapsed = 0.0;
uniform float strength = 0.0;
uniform vec3 focus;
varying vec3 world_position;
varying float presence;
varying float pigment;

float sand_hash(float p) {
    return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

float emission(float time, float seed) {
    // Short unequal bursts with long empty intervals; patches have independent
    // phases and skip whole cycles. Birth-time gating lets emitted grains settle.
    float period = 7.0 + sand_hash(seed + 3.0) * 7.0;
    float clock = time + seed * 31.0;
    float cycle = floor(clock / period);
    float local_time = mod(clock, period);
    float event_seed = sand_hash(seed * 39.0 + cycle * 7.0);
    float start = 0.8 + event_seed * 1.3;
    float duration = mix(1.1, 3.2, sand_hash(event_seed + 9.0));
    return step(0.20, event_seed) * smoothstep(start, start + 0.18, local_time)
        * (1.0 - smoothstep(start + duration - 0.35, start + duration, local_time));
}

void vertex() {
    float patch = INSTANCE_CUSTOM.x;
    float id = INSTANCE_CUSTOM.y;
    float grain = INSTANCE_CUSTOM.z;
    pigment = sand_hash(grain + 17.0);
    float life = mix(0.55, 1.35, sand_hash(grain + patch));
    float age = fract(elapsed / life + id) * life;
    float born = elapsed - age;
    float u = age / life;
    float speed = mix(2.4, 4.3, grain) * mix(0.65, 1.1, strength);
    // Individual short saltation hops, a few centimetres above the surface.
    // No continuous density sheet or volumetric-looking curl survives.
    float height = 4.0 * u * (1.0 - u) * mix(0.055, 0.28, sand_hash(grain + 5.0));
    float width = mix(0.65, 1.8, sand_hash(patch + 11.0));
    float lane = (sand_hash(id * 83.0 + patch) - 0.5) * width;
    float start = (sand_hash(grain + 8.0) - 0.5) * 0.65;
    vec3 corner = VERTEX;
    VERTEX.x = start + age * speed + corner.x * mix(0.065, 0.16, grain);
    VERTEX.y = height;
    VERTEX.z = lane + age * (grain - 0.5) * 0.18 + corner.z * mix(0.030, 0.050, pigment);
    NORMAL = vec3(0.0, 1.0, 0.0);
    presence = emission(born, patch) * smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.58, 1.0, u));
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    if (strength <= 0.0 || presence <= 0.01) discard;
    float distance_fade = 1.0 - smoothstep(14.0, 20.0, length(world_position.xz - focus.xz));
    if (distance_fade <= 0.0) discard;
    vec2 p = abs(UV * 2.0 - 1.0);
    float grain = (1.0 - smoothstep(0.60, 1.0, p.x)) * (1.0 - smoothstep(0.25, 1.0, p.y));
    // Opaque depth remains authoritative with both renderer conventions.
    float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    float gap = -view.z / view.w + VERTEX.z;
    float intersection = smoothstep(0.0, 0.018, gap);
    vec4 opaque_world = INV_VIEW_MATRIX * view;
    intersection *= 1.0 - smoothstep(world_position.y, world_position.y + 0.025, opaque_world.y / opaque_world.w);
    ALBEDO = mix(vec3(0.49, 0.34, 0.17), vec3(0.84, 0.66, 0.39), pigment);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    ALPHA = grain * presence * strength * mix(0.65, 1.0, pigment) * distance_fade * intersection;
}
