shader_type spatial;
// Original smooth racing rubber. Faint moulding/abrasion, no road-tyre tread.
void fragment() {
	float shoulder = smoothstep(0.1,0.35,UV.y)*(1.0-smoothstep(0.65,0.9,UV.y));
	float grain = sin(UV.x*402.0+sin(UV.y*91.0))*sin(UV.y*277.0);
	float mould = exp(-abs(UV.y-0.5)*460.0);
	ALBEDO = mix(vec3(0.043,0.050,0.054),vec3(0.068,0.073,0.074),shoulder)+grain*0.0015-mould*0.005;
	ROUGHNESS = 0.86-shoulder*0.08;
	SPECULAR = 0.17;
}
