
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
#include "res://vehicle/dust_bridge_clip.gdshaderinc"
uniform sampler2D dust_texture : source_color, filter_linear_mipmap;
uniform float alpha_softness = 0.42;
uniform bool billowing = false;
uniform bool rally_dust = false;
uniform float intersection_fade = 0.45;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool dust_birth_height_available = false;
uniform bool dust_height_occlusion = true;
varying highp float dust_density_height;
varying vec2 cloud_uv;
varying highp vec3 dust_world;
varying highp float dust_center_height;
void vertex() {
	// Each particle gets a stable engine-random speed magnitude at spawn.
	// Separate direction from magnitude so none receive near-zero spin.
	float turn_direction = (INSTANCE_ID % 2 == 0) ? -1.0 : 1.0;
	float puff_angle = INSTANCE_CUSTOM.x * turn_direction;
	cloud_uv = UV;
	if (billowing) {
		// Rotation is affine across the card. Evaluate trig per vertex instead
		// of repeating it for every transparent pixel in every overlapping puff.
		float c = cos(puff_angle);
		float s = sin(puff_angle);
		cloud_uv = mat2(vec2(c,-s),vec2(s,c)) * (UV-0.5) + 0.5;
	}
	vec3 particle_scale = vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*particle_scale.x,INV_VIEW_MATRIX[1]*particle_scale.y,INV_VIEW_MATRIX[2]*particle_scale.z,MODEL_MATRIX[3]);
	dust_world = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
	dust_center_height = dust_birth_height_available ? INSTANCE_CUSTOM.z : MODEL_MATRIX[3].y;
	dust_density_height = MODEL_MATRIX[3].y;
}
void fragment() {
	if (COLOR.a <= 0.0) discard;
	if (billowing && length(UV*2.0-1.0) >= 1.0) discard;
	vec4 puff = texture(dust_texture,clamp(cloud_uv,vec2(0.0),vec2(1.0)));
	float alpha = smoothstep(0.02,alpha_softness,puff.a);
	float value = dot(puff.rgb,vec3(0.299,0.587,0.114));
	ALBEDO = COLOR.rgb * mix(0.72,1.12,value);
	ROUGHNESS = 1.0;
	if (billowing) {
		// Soft density with restrained texture variation, without baked dark lobes.
		vec2 p = UV * 2.0 - 1.0;
		alpha = (1.0-smoothstep(0.42,1.0,length(p))) * mix(0.80,1.0,puff.a);
		ALBEDO = COLOR.rgb * mix(0.94,1.04,value);
		if (rally_dust) {
			// Texture breaks the silhouette as well as the interior; avoid a
			// chain of opaque circles along the driven path. No extra samples.
			float radius = length(p);
			alpha = (1.0-smoothstep(0.18,0.86+0.14*puff.a,radius))
				* mix(0.35,1.0,smoothstep(0.10,0.85,puff.a))
				* mix(0.55,1.0,smoothstep(0.20,0.80,value));
		}
		if (alpha <= 0.0) discard;
		// Soften intersections with the road/car instead of cutting a billboard in half.
		float depth = texture(scene_depth,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV,depth) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0,depth);
#endif
		vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc,1.0);
		alpha *= smoothstep(0.0,intersection_fade,VERTEX.z-scene.z/scene.w);
		// A low-ramp upper puff can also project across a higher bridge roof.
		vec4 opaque_world = INV_VIEW_MATRIX * scene;
		// The billboard is a drawing proxy. Its upper corners must not place
		// low tyre dust above taller solid surfaces. Use the actual particle
		// trajectory height without shrinking or postponing the original cloud.
		if (dust_height_occlusion) {
			alpha *= 1.0-smoothstep(dust_density_height,dust_density_height+0.06,opaque_world.y/opaque_world.w);
		}
		alpha *= dust_bridge_surface_visibility(opaque_world.xyz/opaque_world.w,dust_center_height);
	}
	if (alpha <= 0.0) discard;
	alpha *= dust_bridge_visibility_at_height(dust_world,dust_center_height);
	if (alpha <= 0.0) discard;
	vec3 camera_ray = PROJECTION_MATRIX[3].w>0.5 ? INV_VIEW_MATRIX[2].xyz : normalize(INV_VIEW_MATRIX[3].xyz-dust_world);
	alpha *= dust_bridge_projected_visibility(dust_world,camera_ray,dust_center_height);
	ALPHA = COLOR.a * alpha;
}
