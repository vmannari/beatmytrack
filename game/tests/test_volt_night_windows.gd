extends "res://tests/test_volt_night_glass.gd"
## Follow-up: compare the previous Night fix with darker window pigments.
const BeforeLighting = preload("res://../docs/evidence/volt-night-windows-2026-11-06/before/game/race/electric_glass_lighting.gd")
const ROOF_TINT := Vector3(0.026, 0.043, 0.055)

func model_checks() -> void:
	await super.model_checks()
	for prepared: bool in [false, true]:
		BASE.enabled = prepared
		for simple: bool in [false, true]:
			var car := CarVisual.new()
			car.vehicle_id = "electric"
			car.simple_model = simple
			root.add_child(car)
			while not car.model_ready: await process_frame
			var originals: Array[Dictionary] = glass(car)
			var context = Lighting.new()
			context.configure(car, "night_city")
			for binding: Dictionary in glass(car):
				var tint: Vector3 = binding.material.get_shader_parameter("glass_tint_srgb")
				check(tint.is_equal_approx(ROOF_TINT), "every Night pane uses the dark roof pigment")
			context.reset()
			var restored: Array[Dictionary] = glass(car)
			for index: int in range(originals.size()):
				check(restored[index].material == originals[index].material, "original window pigment restored")
			car.free()
	BASE.enabled = true

func set_tints(bindings: Array[Dictionary], key: String) -> void:
	for binding: Dictionary in bindings:
		binding.material.set_shader_parameter("glass_tint_srgb", binding[key])

func native_checks() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	for simple: bool in [false, true]:
		var doc: Dictionary = TrackDocument.create_default()
		doc.theme = "night_city"
		doc["automatic_scenery"] = false
		var track: NativeTrack = TrackCompiler.compile(doc)
		var canonical: PackedByteArray = var_to_bytes([track.content_hash, track.metadata, track.route, track.cells])
		var records := LocalRecords.new("user://volt-window-test.json")
		var paint: Dictionary = VehicleLivery.defaults("electric")
		paint.colors.body = "1926ac"
		records.settings = {"simple_car_models":simple, "vehicle_liveries":{"electric":paint}}
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.vehicle_id = "electric"
		game.production_mode = true
		game.preference_records = records
		var hits: int = BASE.hits
		root.add_child(game)
		while not game.preparation_complete: await process_frame
		check(BASE.hits == hits+1, "production Game uses prepared Volt")
		game.set_process(false)
		game.set_physics_process(false)
		game.hitch_diagnostics.persist_enabled = false
		game.paused = true
		game._present_frame(0.0)
		game.race_cues.reset()
		game.process_mode = Node.PROCESS_MODE_DISABLED
		var state: Array = game.sim.state.snapshot()
		# Read the actual previous helper's pigments, then restore production.
		game.electric_glass_lighting.reset()
		var previous = BeforeLighting.new()
		previous.configure(game.car, "night_city")
		var prior_tints: Array[Vector3] = []
		for binding: Dictionary in glass(game.car): prior_tints.append(binding.material.get_shader_parameter("glass_tint_srgb"))
		previous.reset()
		game.electric_glass_lighting.configure(game.car, "night_city")
		var bindings: Array[Dictionary] = glass(game.car)
		for index: int in range(bindings.size()):
			bindings[index].before = prior_tints[index]
			bindings[index].after = bindings[index].material.get_shader_parameter("glass_tint_srgb")
			check(bindings[index].after.is_equal_approx(ROOF_TINT), "production Game darkens each glass pigment")
			if "--before-windows" in OS.get_cmdline_user_args(): bindings[index].after = prior_tints[index]
		var label: String = "simple" if simple else "full"
		set_tints(bindings, "before")
		await capture(label+"-race-before")
		set_tints(bindings, "after")
		await capture(label+"-race-after")
		game.camera.size = 6.0
		game.camera.position += game.car.global_position + Vector3(0,0.6,0) - game.camera.focus
		for heading: int in [0,90,180,270]:
			game.car.rotation.y = deg_to_rad(heading)
			var prefix: String = label+"-heading-"+str(heading)
			set_tints(bindings, "before")
			var before: Image = await capture(prefix+"-before")
			set_tints(bindings, "after")
			var after: Image = await capture(prefix+"-after")
			for roof: bool in [false,true]:
				var group: Array[Dictionary] = []
				for binding: Dictionary in bindings:
					if binding.before.is_equal_approx(ROOF_TINT) == roof: group.append(binding)
				check(not group.is_empty(), "pane group exists")
				var masks: Array[Image] = []
				var part: String = "roof" if roof else "windows"
				for white: bool in [false,true]:
					var marker := StandardMaterial3D.new()
					marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					marker.albedo_color = Color.WHITE if white else Color.BLACK
					for binding: Dictionary in group: assign(binding, marker)
					masks.append(await capture(prefix+"-"+part+("-white" if white else "-black")))
				for binding: Dictionary in group: assign(binding, binding.material)
				var restored: Image = await capture(prefix+"-"+part+"-restored")
				check(restored.get_data() == after.get_data(), "entire frame restores after "+part+" mask")
				var count: int = 0
				var sums := Vector2.ZERO
				var changed: int = 0
				var maximum: float = 0.0
				var restore_changed: int = 0
				var restore_pane_changed: int = 0
				var restore_samples: Array[Dictionary] = []
				for y: int in range(after.get_height()):
					for x: int in range(after.get_width()):
						var restore_delta: bool = after.get_pixel(x,y) != restored.get_pixel(x,y)
						if restore_delta:
							restore_changed += 1
							if restore_samples.size() < 12: restore_samples.append({"x":x,"y":y,"before":str(after.get_pixel(x,y)),"after":str(restored.get_pixel(x,y))})
						if masks[1].get_pixel(x,y).r-masks[0].get_pixel(x,y).r < 0.95: continue
						if restore_delta: restore_pane_changed += 1
						count += 1
						var a: Color = after.get_pixel(x,y)
						var b: Color = before.get_pixel(x,y)
						sums += Vector2((b.r+b.g+b.b)/3.0, (a.r+a.g+a.b)/3.0)
						maximum = maxf(maximum, maxf(a.r, maxf(a.g, a.b)))
						if a != b: changed += 1
				check(count > 100, "visible "+part+" sampled")
				if roof: check(changed == 0, "roof pixels unchanged")
				else: check(sums.y < sums.x*0.80 and maximum < 0.15, "windows visibly darker")
				check(restore_pane_changed == 0, "pane pixels restore exactly")
				metrics.append({"view":prefix,"part":part,"pixels":count,"before_mean_255":sums.x*255.0/maxi(1,count),"after_mean_255":sums.y*255.0/maxi(1,count),"after_max_channel_255":maximum*255.0,"changed_pixels":changed,"restore_changed":restore_changed,"restore_pane_changed":restore_pane_changed,"restore_samples":restore_samples})
		# Exact day and studio comparison against the previous context helper.
		game.electric_glass_lighting.reset()
		for theme: String in ["pine", "studio"]:
			TrackTheme.apply_lighting("pine", game.biome_environment, game.biome_light)
			if theme == "studio": ShowroomStudio._studio_glass(game.car, {})
			previous.configure(game.car, "pine")
			var before: Image = await capture(label+"-"+theme+"-before")
			previous.reset()
			game.electric_glass_lighting.configure(game.car, "pine")
			var after: Image = await capture(label+"-"+theme+"-after")
			check(before.get_data() == after.get_data(), theme+" frame unchanged")
			game.electric_glass_lighting.reset()
		check(state == game.sim.state.snapshot(), "simulation unchanged")
		check(canonical == var_to_bytes([track.content_hash,track.metadata,track.route,track.cells]), "track unchanged")
		game.preference_records = null
		game.queue_free()
		await process_frame
		await process_frame
