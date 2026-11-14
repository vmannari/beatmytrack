shader_type canvas_item;
render_mode unshaded;

uniform sampler2D paint_mask : filter_linear_mipmap, repeat_disable;
uniform vec4 body_color : source_color = vec4(1.0);
uniform vec4 accent_color : source_color = vec4(1.0);
uniform vec4 detail_color : source_color = vec4(1.0);
uniform vec4 neutral_color : source_color = vec4(0.5,0.5,0.5,1.0);
varying vec4 canvas_tint;

void vertex() { canvas_tint = COLOR; }

void fragment() {
	vec4 picture = texture(TEXTURE, UV);
	vec4 mask = texture(paint_mask, UV);
	vec3 weights = clamp(mask.rgb / max(mask.a, 0.001), vec3(0.0), vec3(1.0));
	float painted = clamp(weights.r + weights.g + weights.b, 0.0, 1.0);
	vec3 pigment = vec3(1.0 - painted) + (weights.r * body_color.rgb + weights.g * accent_color.rgb + weights.b * detail_color.rgb) / neutral_color.rgb;
	// Keep a little of the photographed highlight when the selected paint is dark.
	vec3 glint = pow(clamp(picture.rgb, vec3(0.0), vec3(1.0)), vec3(8.0)) * 0.10;
	vec3 color = picture.rgb * pigment + glint * painted * (vec3(1.0) - clamp(pigment,vec3(0.0),vec3(1.0)));
	COLOR = vec4(color, picture.a) * canvas_tint;
}
