uniform bool graphics_enabled = false;
uniform bool pattern_enabled = false;
uniform sampler2D livery_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D sticker_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 sticker_atlas_size = vec2(1024.0,1536.0);
uniform vec4 livery_body : source_color;
uniform vec4 livery_accent : source_color;
uniform vec4 livery_detail : source_color;
uniform vec3 graphic_bounds = vec3(1.76,1.52,4.18);
uniform vec4 hood_panel;
uniform vec4 roof_panel;
uniform vec2 panel_levels;
uniform vec4 hood_sticker;
uniform vec4 roof_sticker;
uniform int hood_emblem = -1;
uniform int roof_emblem = -1;

vec3 graphic_pigment(vec3 pigment, vec3 p, vec3 n) {
	if (!graphics_enabled) return pigment;
	if (pattern_enabled) {
		// Body-space projection survives batching, suspension, turns and zoom.
		vec3 q = vec3(p.x / graphic_bounds.x + 0.5, p.y / graphic_bounds.y, p.z / graphic_bounds.z + 0.5);
		vec3 weights = pow(abs(n), vec3(8.0));
		weights /= max(dot(weights,vec3(1.0)),0.0001);
		vec2 masks = texture(livery_mask,q.xz).rg * weights.y;
		masks += texture(livery_mask,vec2(1.0-q.y,q.z)).rg * weights.x;
		masks += texture(livery_mask,vec2(q.x,1.0-q.y)).rg * weights.z;
		pigment = mix(livery_body.rgb,livery_accent.rgb,masks.r);
		pigment = mix(pigment,livery_detail.rgb,masks.g);
	}
	return pigment;
}

vec3 panel_emblem(vec3 pigment, vec3 p, vec3 n, vec4 panel, float level, vec4 placement, int emblem) {
	if (emblem < 0 || n.y < 0.65 || p.y < level) return pigment;
	vec2 uv = (p.xz-panel.xy)/panel.zw;
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) return pigment;
	vec2 delta = (uv-placement.xy)*panel.zw;
	float c = cos(placement.w), s = sin(placement.w);
	vec2 sticker_uv = vec2(c*delta.x+s*delta.y,-s*delta.x+c*delta.y)/placement.z + vec2(0.5);
	if (any(lessThan(sticker_uv,vec2(0.0))) || any(greaterThan(sticker_uv,vec2(1.0)))) return pigment;
	vec2 tile = vec2(float(emblem % 4),float(emblem / 4));
	vec2 atlas_uv = (tile*256.0+16.0+sticker_uv*224.0)/sticker_atlas_size;
	vec4 ink = texture(sticker_atlas,atlas_uv);
	return mix(pigment,ink.rgb,ink.a);
}

vec3 apply_graphics(vec3 pigment, vec3 p, vec3 n) {
	if (!graphics_enabled) return pigment;
	pigment = graphic_pigment(pigment,p,n);
	pigment = panel_emblem(pigment,p,n,hood_panel,panel_levels.x,hood_sticker,hood_emblem);
	return panel_emblem(pigment,p,n,roof_panel,panel_levels.y,roof_sticker,roof_emblem);
}
