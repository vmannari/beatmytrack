uniform bool graphics_enabled = false;
uniform bool pattern_enabled = false;
uniform bool panel_art = false;
uniform bool premium_full_color = false;
uniform bool premium_bus_paint = false;
uniform vec3 premium_bus_side = vec3(2.5,1.10,0.80);
uniform sampler2D premium_illustration : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float premium_side_scale = 3.0;
uniform int premium_vehicle_kind = 0;
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
uniform bool rear_sticker = false;

vec2 panel_ink(vec2 uv, vec2 tile) {
	// One texel gutter per 512px tile prevents neighbouring panels bleeding.
	uv = clamp(uv,vec2(0.0),vec2(1.0)) * (510.0/512.0) + vec2(1.0/512.0);
	return texture(livery_mask,(tile+uv)/vec2(3.0,2.0)).rg;
}

vec3 illustration_panel(vec2 uv, vec2 tile, vec3 ground) {
	vec2 fade = smoothstep(vec2(0.0),vec2(0.045),uv)*smoothstep(vec2(0.0),vec2(0.045),vec2(1.0)-uv);
	uv = clamp(uv,vec2(0.0),vec2(1.0))*(510.0/512.0)+vec2(1.0/512.0);
	return mix(ground,texture(premium_illustration,(tile+uv)/vec2(3.0,2.0)).rgb,fade.x*fade.y);
}

vec3 illustrated_pigment(vec3 p, vec3 n) {
	vec3 weights = pow(abs(n),vec3(12.0));
	weights /= max(dot(weights,vec3(1.0)),0.0001);
	float top_scale = premium_vehicle_kind==2 ? graphic_bounds.x*0.82 : hood_panel.z;
	float top_start = premium_vehicle_kind==2 ? -graphic_bounds.z*0.46 : hood_panel.y;
	float top_depth = premium_vehicle_kind==2 ? 0.95 : hood_panel.w;
	vec2 top_uv = vec2(-p.x/top_scale+0.5,(top_start+top_depth-p.z)/top_scale);
	vec2 top_tile = vec2(0.0,0.0);
	if (p.z > hood_panel.y+hood_panel.w+0.12) {
		top_uv = vec2(-p.x/graphic_bounds.x+0.5,0.9-(p.z-roof_panel.y)/graphic_bounds.x);
		top_tile=vec2(0.0,1.0);
		if (premium_vehicle_kind!=0) top_tile=vec2(2.0,1.0);
	}
	if (premium_vehicle_kind==1) {
		if (abs(p.x)<0.32) {
			top_uv=vec2(-p.x/0.75+0.5,(0.02-p.z)/1.5);
			if (premium_bus_paint) top_uv.x=-p.x/0.42+0.5;
			top_tile=vec2(0.0,0.0);
		} else {
			top_uv=vec2(p.z/1.2+0.5,0.70-(abs(p.x)-0.55)/1.2);
			if (p.x>0.0) top_uv.x=1.0-top_uv.x;
			top_tile=vec2(p.x<0.0 ? 1.0 : 2.0,0.0);
		}
	}
	vec2 side_uv = vec2(p.z/premium_side_scale+0.5,0.96-p.y/premium_side_scale);
	if (premium_bus_paint) side_uv=vec2(p.z/premium_bus_side.x+0.5,(premium_bus_side.y-p.y)/premium_bus_side.z);
	if (n.x>0.0) side_uv.x=1.0-side_uv.x;
	vec2 end_uv = vec2((n.z<0.0 ? -p.x : p.x)/graphic_bounds.x+0.5,1.0-p.y/graphic_bounds.y);
	vec3 ground = texture(premium_illustration,vec2(2.5,1.5)/vec2(3.0,2.0)).rgb;
	if (premium_bus_paint) {
		vec2 ground_uv=vec2(p.z/graphic_bounds.z+0.5,1.0-p.y/graphic_bounds.y);
		ground_uv=clamp(ground_uv,vec2(0.0),vec2(1.0))*(510.0/512.0)+vec2(1.0/512.0);
		ground=texture(premium_illustration,(vec2(2.0,1.0)+ground_uv)/vec2(3.0,2.0)).rgb;
	}
	vec3 colour = illustration_panel(top_uv,top_tile,ground)*weights.y;
	colour += illustration_panel(side_uv,vec2(n.x<0.0 ? 1.0 : 2.0,0.0),ground)*weights.x;
	colour += illustration_panel(end_uv,vec2(n.z<0.0 ? 0.0 : 1.0,1.0),ground)*weights.z;
	return colour;
}

vec3 panel_pigment(vec3 p, vec3 n) {
	vec3 q = vec3(p.x / graphic_bounds.x + 0.5, p.y / graphic_bounds.y, p.z / graphic_bounds.z + 0.5);
	vec3 weights = pow(abs(n), vec3(8.0));
	weights /= max(dot(weights,vec3(1.0)),0.0001);
	vec2 masks = panel_ink(q.xz,vec2(0.0,0.0)) * weights.y;
	vec2 side_uv = vec2(n.x < 0.0 ? q.z : 1.0-q.z,1.0-q.y);
	masks += panel_ink(side_uv,vec2(n.x < 0.0 ? 1.0 : 2.0,0.0)) * weights.x;
	vec2 end_uv = vec2(n.z < 0.0 ? 1.0-q.x : q.x,1.0-q.y);
	masks += panel_ink(end_uv,vec2(n.z < 0.0 ? 0.0 : 1.0,1.0)) * weights.z;
	vec3 pigment = mix(livery_body.rgb,livery_accent.rgb,masks.r);
	return mix(pigment,livery_detail.rgb,masks.g);
}

vec3 graphic_pigment(vec3 pigment, vec3 p, vec3 n) {
	if (!graphics_enabled) return pigment;
	if (pattern_enabled && premium_full_color) return illustrated_pigment(p,n);
	if (pattern_enabled) return panel_pigment(p,n);
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
	// The Forklift has one rear-facing panel. Existing cars keep their X/Z mapping.
	vec3 panel_point = rear_sticker ? vec3(p.x,p.z,-p.y) : p;
	vec3 panel_normal = rear_sticker ? vec3(n.x,n.z,-n.y) : n;
	pigment = panel_emblem(pigment,panel_point,panel_normal,hood_panel,panel_levels.x,hood_sticker,hood_emblem);
	return panel_emblem(pigment,p,n,roof_panel,panel_levels.y,roof_sticker,roof_emblem);
}
