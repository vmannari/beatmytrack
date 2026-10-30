shader_type canvas_item;
uniform bool patterned = false;
uniform vec4 body_colour : source_color;
uniform vec4 accent_colour : source_color;
uniform vec4 detail_colour : source_color;
uniform vec4 panel;
uniform vec3 bounds;
void fragment() {
	vec2 body_uv = (panel.xy+UV*panel.zw)/bounds.xz+vec2(0.5);
	vec2 masks = patterned ? texture(TEXTURE,body_uv).rg : vec2(0.0);
	COLOR = vec4(mix(mix(body_colour.rgb,accent_colour.rgb,masks.r),detail_colour.rgb,masks.g),1.0);
}
