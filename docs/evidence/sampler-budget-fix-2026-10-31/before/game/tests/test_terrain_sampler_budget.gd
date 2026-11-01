extends SceneTree
## GLES minimum is 16 fragment units; reserve eight for engine lighting.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(960,540)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0,65,40)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-55,-25,0)
	var sampler := RegEx.new()
	sampler.compile("uniform sampler2D ")
	for theme: String in ["pine","storm","desert","winter","night_city"]:
		var document: Dictionary = TrackDocument.create_default()
		document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		var visual := NativeTrackVisual.new()
		visual.theme_id = theme
		visual.colors = TrackTheme.palette(theme)
		visual.persist_road_meshes = false
		visual.cache_road_meshes = false
		root.add_child(visual)
		await visual.build(track,BridgePresentation.new(track))
		for node: Node in visual.get_children():
			if not node is MeshInstance3D: continue
			var material: ShaderMaterial = node.material_override as ShaderMaterial
			if node.name.begins_with("WinterSnowBanks"):
				checks += 1
				if material == null or material.get_shader_parameter("surface_factors") != NativeTrackVisual.SURFACE_FACTORS:
					failures += 1
					push_error("Winter banks need the real shared detail texture")
				checks += 1
				if not material.has_meta("surface_dynamic_material"):
					failures += 1
					push_error("Winter bank shader must obey the phone sampler budget")
			if material == null or not material.has_meta("surface_dynamic_material"): continue
			var count: int = sampler.search_all(material.shader.code).size()
			checks += 1
			if count > 8:
				failures += 1
				push_error("%s surface exceeds GLES budget: %d" % [theme,count])
		if DisplayServer.get_name() != "headless":
			for frame: int in range(8): await process_frame
			var folder: String = "res://../docs/evidence/terrain-phone-2026-10-12"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			root.get_texture().get_image().save_png(folder.path_join(theme + ".png"))
		visual.free()
	print("TERRAIN_SAMPLER_BUDGET: %d checks, %d failures" % [checks,failures])
	quit(1 if failures or checks == 0 else 0)
