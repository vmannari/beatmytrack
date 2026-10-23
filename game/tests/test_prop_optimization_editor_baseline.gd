extends "res://tests/test_editor_incremental_objects.gd"
## Original unpruned and optimized editor batches in one native world.
func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/track-object-optimization-2026-10-16/editor-baseline-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(evidence)
	for biome: String in TrackTheme.IDS:
		var track: NativeTrack = props_fixture(biome)
		var viewport := SubViewport.new(); viewport.size = Vector2i(1280,720); viewport.own_world_3d = true; root.add_child(viewport)
		var original := BeforePropTrackVisual.new(); original.theme_id = biome; viewport.add_child(original); original._build_placed_objects(track)
		var before := NativeTrackVisual.new(); before.theme_id = biome; viewport.add_child(before)
		var batches = preload("res://tests/fixtures/prop_optimization_before/placed_object_batches.gd").new()
		await batches.refresh(before,track,false,func() -> bool: return true)
		var after := NativeTrackVisual.new(); after.theme_id = biome; viewport.add_child(after)
		await after.refresh_editor_objects(track,false)
		var native_after := NativeTrackVisual.new(); native_after.theme_id = biome; viewport.add_child(native_after); native_after._build_placed_objects(track)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 75
		viewport.add_child(camera); camera.look_at_from_position(Vector3(0,88,-78),Vector3(0,0,-1)); camera.current = true
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-58,-35,0); light.shadow_enabled = true; viewport.add_child(light)
		var ambient := WorldEnvironment.new(); ambient.environment = Environment.new()
		ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; ambient.environment.ambient_light_energy = 0.45
		ambient.environment.background_mode = Environment.BG_COLOR; ambient.environment.background_color = Color("45535a"); viewport.add_child(ambient)
		var images: Array[Image] = []
		for active: Node3D in [original,before,after,native_after]:
			original.visible = active == original; before.visible = active == before; after.visible = active == after
			native_after.visible = active == native_after
			for frame: int in range(8): await RenderingServer.frame_post_draw
			images.append(viewport.get_texture().get_image())
		for index: int in range(images.size()): images[index].save_png(evidence.path_join(biome+"-"+["native-original","editor-original","editor-optimized","native-optimized"][index]+".png"))
		var a: PackedByteArray = images[0].get_data(); var b: PackedByteArray = images[1].get_data(); var c: PackedByteArray = images[2].get_data()
		var prior_changed: int = 0; var prior_max: int = 0; var changed: int = 0; var maximum: int = 0
		for i: int in range(a.size()):
			var prior: int = absi(int(a[i])-int(b[i])); var delta: int = absi(int(b[i])-int(c[i]))
			if prior: prior_changed += 1
			if delta: changed += 1
			prior_max = maxi(prior_max,prior); maximum = maxi(maximum,delta)
		check(changed == 0,biome+" optimized editor is byte exact to original editor")
		check(a == images[3].get_data(),biome+" optimized native is byte exact to original native after settling")
		print("PROP_EDITOR_BASELINE ",biome," original_native_vs_editor_channels=",prior_changed," max=",prior_max," optimized_vs_original_editor_channels=",changed," max=",maximum)
		viewport.queue_free(); await process_frame
	print("PROP_EDITOR_BASELINE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
