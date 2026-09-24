shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
varying vec4 tint;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { tint = COLOR; }
void fragment() {
    vec2 p = UV;
    float row = floor(p.y / 0.28);
    float x = p.x / 0.73 + mod(row,2.0)*0.5;
    vec2 cell = vec2(floor(x),row);
    float grain = hash(floor(p*85.0));
    float edge = min(min(fract(x),1.0-fract(x))*0.73,min(fract(p.y/0.28),1.0-fract(p.y/0.28))*0.28);
    float mortar = smoothstep(0.012,0.032,edge + (grain-0.5)*0.012);
    mortar = mix(1.0,mortar,tint.a);
    ALBEDO = pow(tint.rgb,vec3(2.2)) * mix(0.72,0.91+hash(cell)*0.16,mortar) * (0.96+grain*0.08);
    ROUGHNESS = 1.0;
}
