shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Seated-torso tailoring and UV-anchored weave retain the native steering poses.
varying vec3 garment_position;

vec3 display_to_linear(vec3 colour) {
	return mix(colour / 12.92, pow((colour + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), colour));
}

float band(float value, float low, float high, float feather) {
	return smoothstep(low - feather, low + feather, value)
		* (1.0 - smoothstep(high - feather, high + feather, value));
}

void vertex() {
	garment_position = VERTEX;
}

void fragment() {
	vec3 pigment = clamp(vec3(0.20, 0.27, 0.31)
		+ (COLOR.rgb - vec3(0.2745, 0.3451, 0.3804)) * 0.85, vec3(0.045), vec3(0.68));
	vec2 torso = vec2(garment_position.y - 0.40, garment_position.z - 0.05);
	float along = dot(torso, vec2(0.79, 0.61));
	float depth = dot(torso, vec2(0.61, -0.79));
	float chest_face = band(depth, 0.012, 0.16, 0.012);
	float torso_width = 1.0 - smoothstep(0.145, 0.18, abs(garment_position.x));
	float chest = torso_width * band(along, 0.095, 0.43, 0.012) * chest_face;
	// Large inserts and shoulder reinforcement read at ordinary Garage scale.
	pigment = mix(pigment, vec3(0.49, 0.55, 0.57), chest * 0.94);
	float yoke = band(along, 0.36, 0.54, 0.012)
		* (1.0 - smoothstep(0.225, 0.265, abs(garment_position.x)));
	pigment = mix(pigment, vec3(0.65, 0.68, 0.66), yoke * 0.96);
	float collar = smoothstep(0.51, 0.55, along)
		* (1.0 - smoothstep(0.11, 0.15, abs(garment_position.x)));
	pigment = mix(pigment, vec3(0.10, 0.15, 0.18), collar);
	float seam_width = max(fwidth(garment_position.x), 0.001);
	float side_seam = (1.0 - smoothstep(0.002, 0.004 + seam_width,
		abs(abs(garment_position.x) - 0.133)))
		* band(along, 0.10, 0.37, 0.012) * chest_face;
	float shoulder_seam = (1.0 - smoothstep(0.002, 0.005 + fwidth(along), abs(along - 0.36)))
		* (1.0 - smoothstep(0.22, 0.26, abs(garment_position.x)));
	float piping = max(side_seam, shoulder_seam);
	pigment = mix(pigment, vec3(0.66, 0.47, 0.25), piping * 0.86);
	float zip = (1.0 - smoothstep(0.007, 0.012, abs(garment_position.x)))
		* band(along, 0.11, 0.50, 0.008) * chest_face;
	pigment = mix(pigment, vec3(0.10, 0.15, 0.18), zip);
	float zip_teeth = (1.0 - smoothstep(0.0012, 0.0024 + seam_width, abs(garment_position.x))) * zip;
	pigment = mix(pigment, vec3(0.60, 0.64, 0.64), zip_teeth * 0.65);
	float boot = (1.0 - smoothstep(0.28, 0.34, garment_position.y))
		* (1.0 - smoothstep(-0.64, -0.54, garment_position.z));
	pigment = mix(pigment, vec3(0.085, 0.12, 0.14), boot);
	float leg = band(garment_position.y, 0.23, 0.43, 0.02)
		* band(garment_position.z, -0.73, -0.15, 0.035) * (1.0 - boot);
	float leg_insert = band(abs(garment_position.x), 0.115, 0.155, 0.007) * leg;
	pigment = mix(pigment, vec3(0.48, 0.54, 0.55), leg_insert * 0.86);
	vec2 weave_uv = UV * 145.0;
	vec2 footprint = fwidth(weave_uv);
	float resolved = 1.0 - smoothstep(0.18, 0.55, max(footprint.x, footprint.y));
	float weave = sin(weave_uv.x * 6.2831853) * sin(weave_uv.y * 6.2831853);
	pigment *= 1.0 + weave * 0.065 * resolved * (1.0 - boot);
	// Woven relief and rolled seams change the lighting without displacement.
	float waist_folds = band(along, 0.02, 0.15, 0.025) * torso_width * chest_face;
	float knee_folds = leg * band(garment_position.z, -0.58, -0.26, 0.05);
	float fold_height = sin(along * 165.0 + abs(garment_position.x) * 25.0) * waist_folds * 0.0011
		+ sin(garment_position.z * 140.0 + abs(garment_position.x) * 10.0) * knee_folds * 0.0008;
	float height = weave * 0.00012 * resolved * (1.0 - boot) + piping * 0.00035 + fold_height;
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, NORMAL);
	vec3 r2 = cross(NORMAL, dx);
	float determinant = dot(dx, r1);
	vec3 gradient = (r1 * dFdx(height) + r2 * dFdy(height))
		* sign(determinant) / max(abs(determinant), 0.00000001);
	NORMAL = normalize(NORMAL - gradient);
	ALBEDO = OUTPUT_IS_SRGB ? pigment : display_to_linear(pigment);
	METALLIC = 0.0;
	ROUGHNESS = mix(mix(0.91, 0.80, yoke), 0.70, boot);
	SPECULAR = mix(0.18, 0.24, boot);
}
