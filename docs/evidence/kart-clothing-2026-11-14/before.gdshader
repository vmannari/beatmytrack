shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Imported garment colours and UVs remain attached to every steering pose.
// Fine weave fades before becoming subpixel; there is no animated noise,
// displacement, extra draw pass or texture allocation.
varying vec3 garment_position;

vec3 display_to_linear(vec3 colour) {
	return mix(colour / 12.92, pow((colour + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), colour));
}

void vertex() {
	garment_position = VERTEX;
}

void fragment() {
	vec3 source = COLOR.rgb;
	vec3 pigment = clamp(vec3(0.29, 0.35, 0.38) + (source - vec3(0.2745, 0.3451, 0.3804)) * 1.50, vec3(0.05), vec3(0.70));
	float front = smoothstep(0.055, 0.115, garment_position.z)
		* (1.0 - smoothstep(0.34, 0.40, garment_position.z));
	// Broad tailored torso insert. The mask stays within the fixed chest, away
	// from the moving sleeves and their existing cuff/elbow colour panels.
	float chest = (1.0 - smoothstep(0.12, 0.17, abs(garment_position.x)))
		* smoothstep(0.52, 0.60, garment_position.y)
		* (1.0 - smoothstep(0.74, 0.79, garment_position.y))
		* front;
	pigment = mix(pigment, pigment * 1.16, chest);
	float yoke = smoothstep(0.705, 0.725, garment_position.y)
		* (1.0 - smoothstep(0.785, 0.805, garment_position.y))
		* (1.0 - smoothstep(0.17, 0.22, abs(garment_position.x))) * front;
	pigment = mix(pigment, vec3(0.46, 0.50, 0.50), yoke * 0.82);
	// Sewn torso panel edges are a few millimetres wide and softly filtered.
	float edge_width = max(fwidth(garment_position.x), 0.0015);
	float edge = 1.0 - smoothstep(0.002, 0.0035 + edge_width, abs(abs(garment_position.x) - 0.123));
	edge *= smoothstep(0.53, 0.58, garment_position.y)
		* (1.0 - smoothstep(0.70, 0.74, garment_position.y)) * front;
	pigment = mix(pigment, vec3(0.45, 0.49, 0.50), edge * 0.48);
	// The lower boot is part of the original suit surface. Separate its rubber
	// and leather response without splitting, moving or rebuilding that mesh.
	float boot = (1.0 - smoothstep(0.28, 0.34, garment_position.y))
		* (1.0 - smoothstep(-0.64, -0.54, garment_position.z));
	pigment = mix(pigment, vec3(0.105, 0.14, 0.155), boot);
	vec2 weave_uv = UV * 220.0;
	vec2 footprint = fwidth(weave_uv);
	float resolved = 1.0 - smoothstep(0.18, 0.50, max(footprint.x, footprint.y));
	float weave = sin(weave_uv.x * 6.2831853) * sin(weave_uv.y * 6.2831853);
	pigment *= 1.0 + weave * 0.035 * resolved * (1.0 - boot);
	ALBEDO = OUTPUT_IS_SRGB ? pigment : display_to_linear(pigment);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.93, 0.72, boot);
	SPECULAR = mix(0.14, 0.22, boot);
}
