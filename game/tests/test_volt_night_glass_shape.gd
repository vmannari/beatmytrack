extends "res://tests/test_volt_night_windows.gd"
## Compare canopy reflections while preserving the owner's preferred side glass.
const BEFORE_SOURCE := "res://../docs/evidence/volt-night-glass-shape-2026-11-06/before/game/vehicle/electric_glass.gdshader"

func model_checks() -> void:
	# Model/lifetime checks also run separately headless; native-only still
	# verifies actual prepared hits in the production Game below.
	if "--procedural" not in OS.get_cmdline_user_args() and "--native-only" not in OS.get_cmdline_user_args(): await super.model_checks()

func native_checks() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var source: Shader = GLASS
	var final_code: String = source.code
	var before_code: String = FileAccess.get_file_as_string(BEFORE_SOURCE)
	var procedural: bool = "--procedural" in OS.get_cmdline_user_args()
	BASE.enabled = not procedural
	for simple: bool in [false,true]:
		var doc: Dictionary = TrackDocument.create_default()
		doc.theme = "night_city"
		doc["automatic_scenery"] = false
		check(TrackDocument.validate(doc).is_empty(), "valid track fixture: "+str(TrackDocument.validate(doc)))
		var track: NativeTrack = TrackCompiler.compile(doc)
		if track == null: return
		var canonical: PackedByteArray = var_to_bytes([track.content_hash,track.metadata,track.route,track.cells])
		var records := LocalRecords.new("user://volt-glass-shape.json")
		var paint: Dictionary = VehicleLivery.defaults("electric")
		paint.colors.body = "1926ac"
		records.settings = {"simple_car_models":simple,"vehicle_liveries":{"electric":paint}}
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.vehicle_id = "electric"
		game.production_mode = true
		game.preference_records = records
		var hits: int = BASE.hits
		root.add_child(game)
		while not game.preparation_complete: await process_frame
		check(BASE.hits == hits+(0 if procedural else 1), "requested procedural/prepared production car")
		game.set_process(false)
		game.set_physics_process(false)
		game.hitch_diagnostics.persist_enabled = false
		game.paused = true
		game._present_frame(0.0)
		game.race_cues.reset()
		game.process_mode = Node.PROCESS_MODE_DISABLED
		var state: Array = game.sim.state.snapshot()
		var bindings: Array[Dictionary] = glass(game.car)
		var label: String = "simple" if simple else "full"
		source.code = before_code
		await capture(label+"-race-before")
		source.code = final_code
		await capture(label+"-race-after")
		game.camera.size = 6.0
		game.camera.position += game.car.global_position+Vector3(0,0.6,0)-game.camera.focus
		for heading: int in [0,90,180,270]:
			game.car.rotation.y = deg_to_rad(heading)
			var prefix: String = label+"-heading-"+str(heading)
			# Submit mask materials first, then compare stable source/material RIDs.
			var masks: Dictionary = {}
			for part: String in ["canopy","sides"]:
				var group: Array[Dictionary] = []
				for binding: Dictionary in bindings:
					var canopy: bool = binding.material.get_shader_parameter("show_frit") == false
					if canopy == (part == "canopy"): group.append(binding)
				check(not group.is_empty(), part+" material group exists")
				var pictures: Array[Image] = []
				for white: bool in [false,true]:
					var marker := StandardMaterial3D.new()
					marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					marker.albedo_color = Color.WHITE if white else Color.BLACK
					for binding: Dictionary in group: assign(binding,marker)
					pictures.append(await capture(prefix+"-"+part+("-white" if white else "-black")))
				for binding: Dictionary in group: assign(binding,binding.material)
				masks[part] = pictures
			source.code = before_code
			var before: Image = await capture(prefix+"-before")
			source.code = final_code
			var after: Image = await capture(prefix+"-after")
			for part: String in ["canopy","sides"]:
				var pixels: int = 0
				var changes: int = 0
				var before_sum: float = 0.0
				var after_sum: float = 0.0
				var minimum: float = 1.0
				var maximum: float = 0.0
				var colours: Dictionary = {}
				for y: int in range(after.get_height()):
					for x: int in range(after.get_width()):
						if masks[part][1].get_pixel(x,y).r-masks[part][0].get_pixel(x,y).r < 0.95: continue
						pixels += 1
						var a: Color = after.get_pixel(x,y)
						var b: Color = before.get_pixel(x,y)
						if a != b: changes += 1
						before_sum += (b.r+b.g+b.b)/3.0
						after_sum += (a.r+a.g+a.b)/3.0
						minimum = minf(minimum,(a.r+a.g+a.b)/3.0)
						maximum = maxf(maximum,maxf(a.r,maxf(a.g,a.b)))
						colours[a.to_rgba32()] = true
				check(pixels > 100, part+" visibly sampled")
				if part == "sides": check(changes == 0, "preferred side/mirror glass pixels unchanged")
				else:
					check(after_sum < before_sum*0.8 and maximum < 0.15, "canopy avoids pale even fill")
					check(after_sum/maxi(1,pixels) > 1.0/255.0, "canopy retains visible glass above black")
					check(colours.size() >= 8 and maximum-minimum > 4.0/255.0, "curved canopy retains visible tonal variation")
				metrics.append({"view":prefix,"part":part,"pixels":pixels,"changed":changes,"before_mean_255":255.0*before_sum/maxi(1,pixels),"after_mean_255":255.0*after_sum/maxi(1,pixels),"maximum_channel_255":maximum*255.0,"minimum_mean_255":minimum*255.0,"colours":colours.size()})
		game.electric_glass_lighting.reset()
		for theme: String in ["pine","studio"]:
			TrackTheme.apply_lighting("pine",game.biome_environment,game.biome_light)
			if theme == "studio": ShowroomStudio._studio_glass(game.car,{})
			source.code = before_code
			var before: Image = await capture(label+"-"+theme+"-before")
			source.code = final_code
			var after: Image = await capture(label+"-"+theme+"-after")
			check(before.get_data() == after.get_data(), theme+" frame exact")
		check(state == game.sim.state.snapshot(), "simulation unchanged")
		check(canonical == var_to_bytes([track.content_hash,track.metadata,track.route,track.cells]), "track unchanged")
		game.preference_records = null
		game.queue_free()
		await process_frame
		await process_frame
	BASE.enabled = true
	source.code = final_code
