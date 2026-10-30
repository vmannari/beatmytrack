shader_type canvas_item;
render_mode unshaded;

uniform vec4 wall_color : source_color = vec4(0.12, 0.1, 0.04, 1.0);
uniform vec4 floor_color : source_color = vec4(0.25, 0.19, 0.07, 1.0);
uniform vec4 light_color : source_color = vec4(0.9, 0.65, 0.2, 1.0);
uniform float light_strength = 0.3;
uniform vec2 stage_size = vec2(180.0, 140.0);

void fragment() {
	vec2 uv = UV;
	float floor_depth = smoothstep(0.59, 1.0, uv.y);
	vec3 backdrop = mix(wall_color.rgb * (0.92 - uv.y * 0.25), floor_color.rgb, floor_depth);
	// A low pool of medal-colored light grounds the existing native car cutout.
	vec2 pool = (uv - vec2(0.5, 0.86)) * vec2(2.2, 5.4);
	float illumination = exp(-dot(pool, pool) * 1.6);
	vec2 halo = (uv - vec2(0.5, 0.72)) * vec2(2.2, 2.8);
	backdrop += light_color.rgb * light_strength * (illumination + 0.17 * exp(-dot(halo, halo) * 2.5));
	// Restrained perspective floor seams, fading towards the back of the stage.
	float perspective = (uv.x - 0.5) / (0.28 + floor_depth * 0.95);
	float seam_x = 1.0 - smoothstep(0.012, 0.03, abs(sin(perspective * 9.424778)));
	float seam_y = max(1.0 - smoothstep(0.002, 0.009, abs(uv.y - 0.76)), 1.0 - smoothstep(0.002, 0.009, abs(uv.y - 0.94)));
	backdrop += light_color.rgb * (seam_x + seam_y) * floor_depth * illumination * 0.045;
	// Keep the stage edges quiet and let the car's real contact shadows read.
	backdrop *= 1.0 - 0.27 * pow(abs(uv.x - 0.5) * 2.0, 2.0);
	vec2 p = uv * stage_size;
	vec2 q = abs(p - stage_size * 0.5) - stage_size * 0.5 + vec2(4.0);
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 4.0;
	COLOR = vec4(backdrop, 1.0 - smoothstep(-0.8, 0.0, edge));
}
