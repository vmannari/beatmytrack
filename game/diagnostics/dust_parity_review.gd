extends RefCounted
## Identical frozen shipping puffs on desktop/Android; no simulation or saves.
var game: Node
var particles: Array[GPUParticles3D] = []
var sources: Array[ShaderMaterial] = []
var depth_card: MeshInstance3D
var reference: Image
var scene_heights: Image
var references: Dictionary = {}
var resolve_card: MeshInstance3D

func prepare(target: Node, track: NativeTrack) -> void:
	game = target
	game.set_physics_process(false)
	game.set_process(false)
	game.ai_enabled = false
	game.countdown_ticks = 0
	game.race_cues.reset()
	game.paused = false
	game.sim.state.position = track.spawn
	game.sim.state.heading = PI*0.5
	game.sim.state.velocity = Vector2(12,0)
	game.previous_position = track.spawn
	game.previous_heading = PI*0.5
	game.camera.speed_zoom_enabled = false
	game.call("_process",0.0)
	game.camera.follow(track.spawn,Vector2.ZERO,PI*0.5,0.0,true)
	game.sand_dust.sample(game.sim.state,DriveFrame.new(),track,game.bridge_presentation)
	game.sand_dust.visible = false
	for wheel: int in range(4):
		var source: GPUParticles3D = game.sand_dust.dust_emitters[wheel]
		var puff: GPUParticles3D = source.duplicate()
		puff.process_material = source.process_material.duplicate()
		puff.draw_pass_1 = source.draw_pass_1.duplicate()
		var material: ShaderMaterial = source.draw_pass_1.surface_get_material(0).duplicate()
		puff.draw_pass_1.surface_set_material(0,material)
		puff.amount = 1
		puff.amount_ratio = 1.0
		puff.randomness = 0.0
		puff.explosiveness = 1.0
		puff.speed_scale = 1.0
		puff.preprocess = 0.25
		puff.use_fixed_seed = true
		puff.seed = 341+wheel
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.get_node("World").add_child(puff)
		puff.emitting = true
		puff.restart()
		particles.append(puff)
		sources.append(material)
	# Complete real draw frames before freezing: a startup timer can expire
	# before the first GPU particle update when shader compilation stalls.
	for frame: int in range(4):
		game.paused = false
		game.hud.pause_menu.hide()
		await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
	for puff: GPUParticles3D in particles: puff.speed_scale = 0.0
	depth_card = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	depth_card.mesh = quad
	depth_card.extra_cull_margin = 1000.0
	depth_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var depth := ShaderMaterial.new()
	depth.shader = Shader.new()
	depth.shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;
uniform sampler2D opaque_depth : hint_depth_texture, filter_nearest, repeat_disable;
void vertex() { POSITION = vec4(VERTEX.xy,0.0,1.0); }
void fragment() {
	float d = texture(opaque_depth,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,d)*2.0-1.0;
#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,d);
#endif
	vec4 world = INV_VIEW_MATRIX*INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	float y = world.y/world.w;
	ALBEDO = y>0.7 ? vec3(1,0,0) : (y>0.12 ? vec3(0,1,0) : vec3(0,0,1));
}
"""
	depth.render_priority = 100
	depth_card.material_override = depth
	game.get_node("World").add_child(depth_card)
	depth_card.hide()
	resolve_card = MeshInstance3D.new()
	resolve_card.mesh = quad
	resolve_card.extra_cull_margin = 1000.0
	resolve_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var resolve := ShaderMaterial.new()
	resolve.shader = Shader.new()
	resolve.shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;
uniform sampler2D opaque_color : hint_screen_texture, filter_nearest, repeat_disable;
void vertex() { POSITION = vec4(VERTEX.xy*0.001+vec2(-0.998),0.0,1.0); }
void fragment() { ALBEDO = texture(opaque_color,SCREEN_UV).rgb*0.0; ALPHA = 0.0; }
"""
	resolve_card.material_override = resolve
	game.get_node("World").add_child(resolve_card)
	resolve_card.hide()
	print("DUST_PARITY_CAR_MATERIALS ",material_report())
	for puff: GPUParticles3D in particles:
		print("DUST_PARITY_PUFF ",puff.position," emitting=",puff.emitting," alive_scale=",puff.speed_scale," visible=",puff.is_visible_in_tree()," layers=",puff.layers," mask=",game.camera.cull_mask)

func select(feature: String) -> void:
	game.get_viewport().msaa_3d = Viewport.MSAA_DISABLED if feature.ends_with("no_msaa") else Viewport.MSAA_2X
	depth_card.visible = feature.begins_with("parity_scene_depth")
	resolve_card.visible = feature.contains("resolve_colour")
	for index: int in range(particles.size()):
		particles[index].visible = not feature.begins_with("parity_reference") and not feature.begins_with("parity_scene_depth")
		particles[index].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if feature=="parity_particle_shadows" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var source: ShaderMaterial = sources[index]
		var code: String = source.shader.code
		if feature=="parity_early_depth": code = code.replace("DEPTH = FRAGCOORD.z;","")
		if feature=="parity_computed_depth":
			code = code.replace("DEPTH = FRAGCOORD.z;","")
			code = code.replace("ALPHA = COLOR.a * alpha;","ALPHA = COLOR.a * alpha;\nvec4 actual_clip = PROJECTION_MATRIX*vec4(VERTEX,1.0);\nDEPTH = actual_clip.z/actual_clip.w*0.5+0.5;")
		if feature=="parity_particle_height":
			code = code.replace("ALBEDO = COLOR.rgb * mix(0.94,1.04,value);","ALBEDO = dust_density_height>0.7 ? vec3(1,0,0) : vec3(0,1,0);")
		var material: ShaderMaterial = source.duplicate()
		material.shader = Shader.new()
		material.shader.code = code
		for uniform: Dictionary in source.shader.get_shader_uniform_list():
			var value: Variant = source.get_shader_parameter(uniform.name)
			if value!=null: material.set_shader_parameter(uniform.name,value)
		particles[index].draw_pass_1.surface_set_material(0,material)
	game.paused = false
	game.hud.pause_menu.hide()

func capture_stats(feature: String) -> Dictionary:
	var captured: Image = game.get_viewport().get_texture().get_image()
	var aa: int = game.get_viewport().msaa_3d
	if feature.begins_with("parity_reference"): references[aa] = captured.duplicate()
	reference = references.get(aa)
	var pixels: int = 0
	var changed: int = 0
	var outside: int = 0
	var center: Vector2 = game.camera.unproject_position(VisualGeometry.world(game.sim.state.position))
	center *= Vector2(captured.get_size())/game.get_viewport().get_visible_rect().size
	var sampled: int = 0
	if feature.begins_with("parity_scene_depth"):
		for y: int in range(maxi(2,int(center.y)-250),mini(captured.get_height()-2,int(center.y)+250)):
			for x: int in range(maxi(2,int(center.x)-250),mini(captured.get_width()-2,int(center.x)+250)):
				var color: Color = captured.get_pixel(x,y)
				if color.r>0.9 and color.g<0.15 and color.b<0.15: sampled += 1
		if sampled>100 or scene_heights==null: scene_heights = captured.duplicate()
	if reference==null or scene_heights==null: return {"sampled_depth_roof_pixels":sampled}
	for y: int in range(maxi(2,int(center.y)-250),mini(captured.get_height()-2,int(center.y)+250)):
		for x: int in range(maxi(2,int(center.x)-250),mini(captured.get_width()-2,int(center.x)+250)):
			var solid: bool = true
			for oy: int in range(-1,2):
				for ox: int in range(-1,2):
					var sample: Color = scene_heights.get_pixel(x+ox,y+oy)
					if sample.r<0.9 or sample.g>0.15 or sample.b>0.15: solid = false
			var a: Color = reference.get_pixel(x,y)
			var b: Color = captured.get_pixel(x,y)
			var delta: float = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			if solid:
				pixels += 1
				if delta>2.0/255.0: changed += 1
			elif delta>2.0/255.0: outside += 1
	return {"opaque_roof_pixels":pixels,"changed_roof_pixels":changed,"changed_outside_pixels":outside,"sampled_depth_roof_pixels":sampled,"capture_center":[center.x,center.y]}

func material_report() -> Dictionary:
	var report: Dictionary = {"surfaces":0,"transparent":0,"depth_test_disabled":0,"alpha_below_one":0,"shader_alpha":0}
	for mesh: MeshInstance3D in game.car.find_children("*","MeshInstance3D",true,false):
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			report.surfaces += 1
			if material is BaseMaterial3D:
				report.transparent += int(material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED)
				report.depth_test_disabled += int(material.no_depth_test)
				report.alpha_below_one += int(material.albedo_color.a<0.999)
			elif material is ShaderMaterial:
				report.shader_alpha += int(material.shader.code.contains("ALPHA"))
	return report
