extends SceneTree
const Lighting = preload("res://race/electric_glass_lighting.gd")
const GLASS: Shader = preload("res://vehicle/electric_glass.gdshader")
const BASE = preload("res://vehicle/modular_car_base.gd")
var checks: int = 0
var failures: int = 0
var output: String
var old_shader: Shader
var metrics: Array[Dictionary] = []
var pipeline_settles: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func glass(car: CarVisual) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mesh: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for index: int in range(1 if mesh.material_override != null else mesh.mesh.get_surface_count()):
			var surface: ShaderMaterial = mesh.get_active_material(index) as ShaderMaterial
			if surface != null and surface.shader in [GLASS,old_shader]:
				result.append({"node":mesh,"index":index,"material":surface,"override":mesh.material_override != null})
	return result

func assign(binding: Dictionary, material: Material) -> void:
	if binding.override: binding.node.material_override = material
	else: binding.node.set_surface_override_material(binding.index,material)

func model_checks() -> void:
	for prepared: bool in [false,true]:
		BASE.enabled = prepared
		for simple: bool in [false,true]:
			var before_hits: int = BASE.hits
			var car := CarVisual.new()
			car.vehicle_id = "electric"
			car.simple_model = simple
			root.add_child(car)
			while not car.model_ready: await process_frame
			if prepared: check(BASE.hits == before_hits + 1,"actual prepared base hit")
			var original: Array[Dictionary] = glass(car)
			check(original.size() >= 4,"full glass set found")
			var context = Lighting.new()
			context.configure(car,"pine")
			check(context._bindings.is_empty(),"day allocates no glass copies")
			context.configure(car,"night_city")
			var night: Array[Dictionary] = glass(car)
			for index: int in range(original.size()):
				check(night[index].material != original[index].material,"night material owned")
				check(night[index].material.get_shader_parameter("night_mode") == true,"night parameter enabled")
				check(original[index].material.get_shader_parameter("night_mode") != true,"source material remains daytime")
			context.configure(car,"night_city")
			var repeated: Array[Dictionary] = glass(car)
			for index: int in range(night.size()): check(repeated[index].material == night[index].material,"same-theme configure reuses bindings")
			var other := CarVisual.new()
			other.vehicle_id = "electric"
			other.simple_model = simple
			root.add_child(other)
			while not other.model_ready: await process_frame
			for binding: Dictionary in glass(other): check(binding.material.get_shader_parameter("night_mode") != true,"second car stays daytime")
			context.configure(car,"pine")
			var restored: Array[Dictionary] = glass(car)
			for index: int in range(original.size()): check(restored[index].material == original[index].material,"day restores exact original material")
			context.configure(car,"night_city")
			var replacement := StandardMaterial3D.new()
			assign(original[0],replacement)
			context.reset()
			check(original[0].node.get_active_material(original[0].index) == replacement,"reset preserves later material replacement")
			context.configure(other,"night_city")
			other.free()
			context.reset()
			check(context._bindings.is_empty(),"freed car bindings release safely")
			car.free()
	BASE.enabled = true
	var hover := CarVisual.new()
	hover.vehicle_id = "hovercraft"
	root.add_child(hover)
	while not hover.model_ready: await process_frame
	var context = Lighting.new()
	context.configure(hover,"night_city")
	check(context._bindings.is_empty(),"Hovercraft is outside Volt correction")
	for binding: Dictionary in glass(hover): check(binding.material.get_shader_parameter("night_mode") != true,"Hovercraft shared shader remains daytime default")
	hover.free()

func capture(label: String) -> Image:
	# Match the existing exact-image fixtures: Mobile can replace an initial
	# ubershader with its optimized specialization after the first few draws.
	var previous: float = -1.0
	var quiet: int = 0
	var rounds: int = 0
	for round: int in range(30):
		for frame: int in range(2): await RenderingServer.frame_post_draw
		var count: float = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		quiet = quiet+1 if count == previous else 0
		previous = count
		rounds = round+1
		if round >= 4 and quiet >= 4: break
	check(quiet >= 4,"pipeline counters settle before "+label)
	pipeline_settles.append({"view":label,"rounds":rounds,"pipeline_count":previous})
	var picture: Image = root.get_texture().get_image()
	check(picture.save_png(output.path_join(label+".png")) == OK,"save "+label)
	return picture

func old_capture(car: CarVisual, label: String) -> Image:
	var bindings: Array[Dictionary] = glass(car)
	for binding: Dictionary in bindings:
		var material: ShaderMaterial = binding.material.duplicate()
		material.shader = old_shader
		assign(binding,material)
	var picture: Image = await capture(label)
	for binding: Dictionary in bindings: assign(binding,binding.material)
	return picture

func same_shader_pair(car: CarVisual, label: String) -> void:
	# Hold shader/material RIDs and draw ordering fixed across the source change.
	# Distinct shader resources can choose different coplanar edge fragments.
	var bindings: Array[Dictionary] = glass(car)
	var comparison := Shader.new()
	comparison.code = old_shader.code
	for binding: Dictionary in bindings:
		var material: ShaderMaterial = binding.material.duplicate()
		material.shader = comparison
		assign(binding,material)
	var before: Image = await capture(label+"-before")
	comparison.code = GLASS.code
	var after: Image = await capture(label+"-after")
	check(before.get_data() == after.get_data(),label+" pixels unchanged with stable shader identity")
	for binding: Dictionary in bindings: assign(binding,binding.material)

func native_checks() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	for simple: bool in [false,true]:
		var doc: Dictionary = TrackDocument.create_default()
		doc.theme = "night_city"
		doc["automatic_scenery"] = false
		var track: NativeTrack = TrackCompiler.compile(doc)
		var canonical: PackedByteArray = var_to_bytes([track.content_hash,track.metadata,track.route,track.cells])
		var records := LocalRecords.new("user://volt-glass-test.json")
		var paint: Dictionary = VehicleLivery.defaults("electric")
		paint.colors.body = "1926ac"
		records.settings = {"simple_car_models":simple,"vehicle_liveries":{"electric":paint}}
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.vehicle_id = "electric"
		game.production_mode = true
		game.preference_records = records
		var before_hits: int = BASE.hits
		root.add_child(game)
		while not game.preparation_complete: await process_frame
		check(BASE.hits == before_hits+1,"actual Game restores prepared Volt")
		game.set_process(false)
		game.set_physics_process(false)
		game.hitch_diagnostics.persist_enabled = false
		game.paused = true
		game._present_frame(0.0)
		game.race_cues.reset()
		game.process_mode = Node.PROCESS_MODE_DISABLED
		var state: Array = game.sim.state.snapshot()
		var bindings: Array[Dictionary] = glass(game.car)
		for binding: Dictionary in bindings: check(binding.material.get_shader_parameter("night_mode") == true,"production Game installs night glass")
		var label: String = "simple" if simple else "full"
		# Submit diagnostic mask materials before the comparisons too. Their
		# first use can change Mobile's scene rendering beyond the marked mesh.
		var warm_roof: Array[Dictionary] = []
		for binding: Dictionary in bindings:
			if str(binding.node.name).begins_with("ReferencePanoramicRoof"): warm_roof.append(binding)
		for white: bool in [false,true]:
			var marker := StandardMaterial3D.new()
			marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			marker.albedo_color = Color.WHITE if white else Color.BLACK
			for binding: Dictionary in warm_roof: assign(binding,marker)
			await capture(label+("-control-warm-white" if white else "-control-warm-black"))
		for binding: Dictionary in warm_roof: assign(binding,binding.material)
		await capture(label+"-control-warm-restored")
		await old_capture(game.car,label+"-race-before")
		await capture(label+"-race-after")
		game.camera.size = 6.0
		game.camera.position += game.car.global_position + Vector3(0,0.6,0) - game.camera.focus
		for heading: int in [0,90,180,270]:
			game.car.rotation.y = deg_to_rad(heading)
			var prefix: String = label+"-heading-"+str(heading)
			var before: Image = await old_capture(game.car,prefix+"-before")
			var after: Image = await capture(prefix+"-after")
			var roof: Array[Dictionary] = []
			for binding: Dictionary in bindings:
				if str(binding.node.name).begins_with("ReferencePanoramicRoof"): roof.append(binding)
			check(not roof.is_empty(),"roof identified")
			var masks: Array[Image] = []
			for white: bool in [false,true]:
				var marker := StandardMaterial3D.new()
				marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				marker.albedo_color = Color.WHITE if white else Color.BLACK
				for binding: Dictionary in roof: assign(binding,marker)
				masks.append(await capture(prefix+("-white" if white else "-black")))
			for binding: Dictionary in roof: assign(binding,binding.material)
			var restored: Image = await capture(prefix+"-restored")
			check(restored.get_data() == after.get_data(),"native controls restore corrected frame")
			var pixels: int = 0
			var before_sum: float = 0.0
			var after_sum: float = 0.0
			var maximum_after: float = 0.0
			var restored_pixels: int = 0
			var restored_roof_pixels: int = 0
			for y: int in range(after.get_height()):
				for x: int in range(after.get_width()):
					var restore_changed: bool = after.get_pixel(x,y) != restored.get_pixel(x,y)
					if restore_changed: restored_pixels += 1
					if masks[1].get_pixel(x,y).r-masks[0].get_pixel(x,y).r < 0.95: continue
					if restore_changed: restored_roof_pixels += 1
					pixels += 1
					var b: Color = before.get_pixel(x,y)
					var a: Color = after.get_pixel(x,y)
					before_sum += (b.r+b.g+b.b)/3.0
					after_sum += (a.r+a.g+a.b)/3.0
					maximum_after = maxf(maximum_after,maxf(a.r,maxf(a.g,a.b)))
			check(pixels > 100,"roof visibly sampled")
			check(after_sum < before_sum*0.40 and maximum_after < 0.15,"night roof stays dark instead of pale")
			check(restored_roof_pixels == 0,"roof pixels restore exactly")
			metrics.append({"view":prefix,"pixels":pixels,"before_mean_255":before_sum*255.0/maxi(1,pixels),"after_mean_255":after_sum*255.0/maxi(1,pixels),"after_max_channel_255":maximum_after*255.0,"restored_changed_pixels":restored_pixels,"restored_roof_changed_pixels":restored_roof_pixels})
		game.electric_glass_lighting.configure(game.car,"pine")
		TrackTheme.apply_lighting("pine",game.biome_environment,game.biome_light)
		await same_shader_pair(game.car,label+"-day")
		game.electric_glass_lighting.configure(game.car,"night_city")
		ShowroomStudio._studio_glass(game.car,{})
		await same_shader_pair(game.car,label+"-studio")
		check(state == game.sim.state.snapshot(),"simulation unchanged")
		check(canonical == var_to_bytes([track.content_hash,track.metadata,track.route,track.cells]),"track unchanged")
		game.preference_records = null
		game.queue_free()
		await process_frame
		await process_frame

func run() -> void:
	output = OS.get_environment("BMT_VOLT_GLASS_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	old_shader = Shader.new()
	old_shader.code = FileAccess.get_file_as_string("res://../docs/evidence/volt-night-roof-fix-2026-11-06/before/game/vehicle/electric_glass.gdshader")
	if "--original-glass" in OS.get_cmdline_user_args():
		var comparison_source: Shader = GLASS
		comparison_source.code = old_shader.code
	await model_checks()
	if DisplayServer.get_name() != "headless": await native_checks()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"pipeline_settles":pipeline_settles},"\t"))
	print("VOLT_NIGHT_GLASS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
