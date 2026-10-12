// Immutable bridge geometry; lower/upper particle banks preserve emission layer.
uniform int dust_bridge_count = 0;
uniform vec4 dust_bridge_axes[16]; // World XZ origin and longitudinal unit vector.
uniform vec4 dust_bridge_sizes[16]; // Length, half width, height, ramp length.
uniform vec4 dust_bridge_roof = vec4(2.2,0.42,0.65,0.0); // Clearance, thickness, sandstone arch drop, desert.
uniform bool dust_upper_layer = false;

float dust_bridge_deck(float along, vec4 size) {
	return size.z*min(smoothstep(0.0,size.w,along),1.0-smoothstep(size.x-size.w,size.x,along));
}

// Clip the projected roof directly as well as the puff's world-space volume.
// This does not depend on mobile MSAA depth-texture resolve at bridge edges.
float dust_bridge_projected_visibility(vec3 world, vec3 camera_ray, float birth_height) {
	vec3 slope = camera_ray/max(camera_ray.y,0.01);
	for (int i = 0; i < dust_bridge_count; i++) {
		vec4 axes = dust_bridge_axes[i];
		vec4 size = dust_bridge_sizes[i];
		float roof = size.z+0.025;
		vec2 top = world.xz+slope.xz*(roof-world.y)-axes.xy;
		float along = dot(top,axes.zw);
		float along_slope = dot(slope.xz,axes.zw);
		float across = dot(top,vec2(-axes.w,axes.z));
		float margin = length(slope.xz)*size.z;
		if (along < -margin || along > size.x+margin || abs(across)>size.y+margin) { continue; }
		// Flat decks are exact immediately. Newton refinement solves the
		// smooth ramps without rasterizing another viewport or changing meshes.
		if (along<size.w || along>size.x-size.w) {
			for (int step = 0; step < 4; step++) {
				float u = clamp(along/size.w,0.0,1.0);
				float v = clamp((size.x-along)/size.w,0.0,1.0);
				float derivative = along<size.w ? size.z*6.0*u*(1.0-u)/size.w : -size.z*6.0*v*(1.0-v)/size.w;
				float difference = roof-dust_bridge_deck(along,size)-0.025;
				float next_roof = clamp(roof-difference/max(1.0-derivative*along_slope,0.1),0.025,size.z+0.025);
				along += along_slope*(next_roof-roof);
				roof = next_roof;
			}
			vec2 hit = world.xz+slope.xz*(roof-world.y)-axes.xy;
			across = dot(hit,vec2(-axes.w,axes.z));
		}
		if (along>=0.0 && along<=size.x && abs(across)<=size.y) {
			if (!dust_upper_layer || birth_height<roof-0.075) { return 0.0; }
		}
	}
	return 1.0;
}

float dust_bridge_visibility_at_height(vec3 world, float birth_height) {
	float visible = 1.0;
	for (int i = 0; i < dust_bridge_count; i++) {
		vec4 axes = dust_bridge_axes[i];
		vec4 size = dust_bridge_sizes[i];
		vec2 delta = world.xz - axes.xy;
		float along = dot(delta, axes.zw);
		float across = dot(delta, vec2(-axes.w, axes.z));
		float edge = min(min(along,size.x-along),size.y-abs(across));
		if (edge < -0.4) { continue; }
		float deck = size.z * min(smoothstep(0.0, size.w, along), 1.0 - smoothstep(size.x-size.w, size.x, along));
		float underside = deck-dust_bridge_roof.y;
		if (dust_bridge_roof.w > 0.5) {
			if (deck < dust_bridge_roof.x) {
				underside = deck + min(-0.06,-deck+mix(-0.05,dust_bridge_roof.x,smoothstep(1.0,dust_bridge_roof.x,deck)));
			} else {
				float t = clamp((along-size.w)/max(size.x-2.0*size.w,0.001),0.0,1.0);
				underside = max(dust_bridge_roof.x,deck-dust_bridge_roof.y-dust_bridge_roof.z*(1.0-sin(t*3.14159265359)));
			}
		}
		bool above = dust_upper_layer && birth_height >= deck-0.05;
		float layer = above
			? smoothstep(deck+0.025, deck+0.15, world.y)
			: 1.0-smoothstep(underside-0.15, underside, world.y);
		// Feather only outside the solid footprint; its interior stays sealed.
		visible = min(visible,mix(1.0,layer,smoothstep(-0.4,0.0,edge)));
	}
	return visible;
}

float dust_bridge_visibility(vec3 world) {
	return dust_bridge_visibility_at_height(world,100000.0);
}

// Upper-bank particles can be born on low ramps, then linger outside them.
// Their billboard corners must not cover a higher roof while their center is
// still below it. Ground-bank particles retain their original sealed layer.
float dust_bridge_surface_visibility(vec3 opaque_world, float particle_height) {
	if (!dust_upper_layer) { return dust_bridge_visibility(opaque_world); }
	float visible = 1.0;
	for (int i = 0; i < dust_bridge_count; i++) {
		vec4 axes = dust_bridge_axes[i];
		vec4 size = dust_bridge_sizes[i];
		vec2 delta = opaque_world.xz - axes.xy;
		float along = dot(delta,axes.zw);
		float across = dot(delta,vec2(-axes.w,axes.z));
		float edge = min(min(along,size.x-along),size.y-abs(across));
		if (edge < 0.0) { continue; }
		float deck = size.z * min(smoothstep(0.0,size.w,along),1.0-smoothstep(size.x-size.w,size.x,along));
		// Only elevated opaque surfaces block the projected card, not the
		// ground visible through the underpass. The bridge road is at +0.025.
		if (opaque_world.y >= deck-0.05) {
			visible = min(visible,smoothstep(deck-0.05,deck+0.025,particle_height));
		}
	}
	return visible;
}
