shader_type spatial;
// Original UV tread, restrained rubber relief; no external texture dependency.
void fragment() {
	float middle = smoothstep(0.28,0.37,UV.y)*(1.0-smoothstep(0.65,0.74,UV.y));
	float groove = 1.0-smoothstep(0.025,0.065,abs(fract(UV.y*18.0)-0.5));
	float diagonal = 1.0-smoothstep(0.04,0.12,abs(fract(UV.x*64.0+abs(UV.y-0.5)*6.0)-0.5));
	float tread = max(groove,diagonal)*middle;
	ALBEDO = mix(vec3(0.065,0.070,0.078),vec3(0.035,0.041,0.047),tread*0.55);
	ROUGHNESS = 0.84+tread*0.10;
	SPECULAR = 0.18;
}
