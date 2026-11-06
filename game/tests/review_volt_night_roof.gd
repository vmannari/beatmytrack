extends SceneTree
## Investigation only: production Game, private runner profile, no shipping edits.
const GLASS: Shader = preload("res://vehicle/electric_glass.gdshader")
var output: String = "res://../docs/evidence/volt-night-roof-2026-11-06"
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func capture(label: String) -> Image:
	for frame: int in range(6): await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	check(picture.save_png(output.path_join(label + ".png")) == OK, "save " + label)
	return picture

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	output = output.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = "night_city"
	doc["automatic_scenery"] = false
	var track: NativeTrack = TrackCompiler.compile(doc)
	var canonical: PackedByteArray = var_to_bytes([track.content_hash, track.cells, track.route, track.metadata])
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.vehicle_id = "electric"
	game.production_mode = true
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.hitch_diagnostics.persist_enabled = false
	game.paused = true
	game._present_frame(0.0)
	game.race_cues.reset()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var state: Array = game.sim.state.snapshot()
	var roof: Array[Dictionary] = []
	for mesh: MeshInstance3D in game.car.find_children("*", "MeshInstance3D", true, false):
		for index: int in range(mesh.mesh.get_surface_count()):
			var material: ShaderMaterial = mesh.get_active_material(index) as ShaderMaterial
			if material == null or material.shader != GLASS: continue
			var tint: Variant = material.get_shader_parameter("glass_tint_srgb")
			if tint is Vector3 and tint.is_equal_approx(Vector3(0.026,0.043,0.055)):
				roof.append({"node":mesh, "index":index, "material":material, "override":mesh.material_override != null})
	check(not roof.is_empty(), "production panoramic roof material found")
	await capture("night-production-camera")
	# Diagnostic close view preserves the race camera angle; production framing
	# above remains the acceptance context, and no shipping camera is changed.
	game.camera.size = 6.0
	game.camera.position += game.car.global_position + Vector3(0,0.6,0) - game.camera.focus
	var night: Image = await capture("night-close")
	var lights: Array[Node] = game.find_children("*", "Light3D", true, false)
	var energies: Array[float] = []
	for light: Light3D in lights:
		energies.append(light.light_energy)
		light.light_energy = 0.0
	game.biome_environment.ambient_light_energy = 0.0
	var dark: Image = await capture("all-lights-off-close")
	for index: int in range(lights.size()): lights[index].light_energy = energies[index]
	TrackTheme.apply_lighting("pine", game.biome_environment, game.biome_light)
	var day: Image = await capture("day-lighting-close")
	TrackTheme.apply_lighting("night_city", game.biome_environment, game.biome_light)
	var masks: Array[Image] = []
	for white: bool in [false,true]:
		var marker := StandardMaterial3D.new()
		marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.albedo_color = Color.WHITE if white else Color.BLACK
		for binding: Dictionary in roof:
			if binding.override: binding.node.material_override = marker
			else: binding.node.set_surface_override_material(binding.index, marker)
		masks.append(await capture("roof-mask-white" if white else "roof-mask-black"))
	for binding: Dictionary in roof:
		if binding.override: binding.node.material_override = binding.material
		else: binding.node.set_surface_override_material(binding.index, binding.material)
	var restored: Image = await capture("night-restored-close")
	var count: int = 0
	var sums: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	var maximum_difference: float = 0.0
	for y: int in range(night.get_height()):
		for x: int in range(night.get_width()):
			if masks[1].get_pixel(x,y).r - masks[0].get_pixel(x,y).r < 0.95: continue
			count += 1
			var pictures: Array[Image] = [night,dark,day]
			for index: int in range(3):
				var color: Color = pictures[index].get_pixel(x,y)
				sums[index] += Vector3(color.r,color.g,color.b)
				var difference: Color = color - night.get_pixel(x,y)
				maximum_difference = maxf(maximum_difference,maxf(absf(difference.r),maxf(absf(difference.g),absf(difference.b))))
	check(count > 100, "roof visibly occupies more than 100 interior pixels")
	check(maximum_difference <= 1.0/255.0, "roof ignores day/night and all lights off")
	check(night.get_data() == restored.get_data(), "material controls restore the original night frame exactly")
	check(game.sim.state.snapshot() == state, "simulation unchanged")
	check(canonical == var_to_bytes([track.content_hash, track.cells, track.route, track.metadata]), "track unchanged")
	for index: int in range(3):
		var average: Vector3 = sums[index] * 255.0 / maxi(count,1)
		rows.append({"lighting":["night","all_off","day"][index],"roof_mean_rgb_255":[average.x,average.y,average.z]})
	var report: Dictionary = {"checks":checks,"failures":failures,"roof_materials":roof.size(),"roof_interior_pixels":count,"maximum_lighting_difference_255":maximum_difference*255.0,"lighting":rows,"glass_sha256":FileAccess.get_sha256("res://vehicle/electric_glass.gdshader")}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("VOLT_NIGHT_ROOF: ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
