extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func run() -> void:
	root.size = Vector2i(1280,720)
	var game_script: Script = preload("res://core/game.gd")
	check(is_equal_approx(game_script.render_scale_for("night_city",0.667,true),0.55),"mobile night gets measured GPU headroom")
	check(is_equal_approx(game_script.render_scale_for("pine",0.667,true),0.667),"daylight retains mobile resolution")
	check(is_equal_approx(game_script.render_scale_for("night_city",1.0,false),1.0),"desktop resolution retained")
	check(is_equal_approx(game_script.render_scale_for("night_city",0.5,true),0.5),"night never raises an already lower render budget")
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = "night_city"
	doc.pieces = [RoadPieces.create("curve",Vector2(-10,-8)),RoadPieces.create("straight",Vector2(6,8),90)]
	for p: Vector2 in [Vector2(-20,-10),Vector2(0,10),Vector2(20,-10)]:
		doc.objects.append({"kind":"light","position":[p.x,p.y],"rotation":0.0,"scale":1.0})
	var track: NativeTrack = TrackCompiler.compile(doc)
	var visual := NativeTrackVisual.new()
	root.add_child(visual)
	visual.build(track,BridgePresentation.new(track))
	var tiles: Array[Node] = visual.find_children("*","MeshInstance3D",false,false).filter(func(node: Node) -> bool: return str(node.name).begins_with("LitTerrainTile"))
	# Godot renames duplicate sibling names; identify all terrain tiles by material.
	tiles.clear()
	for child: Node in visual.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial and child.material_override.shader == NativeTrackVisual.TERRAIN_SHADER: tiles.append(child)
	check(tiles.size() > 1,"night terrain is spatially partitioned")
	var area: float = 0.0
	var aligned: bool = true
	var bounded: bool = true
	for tile: MeshInstance3D in tiles:
		var arrays: Array = tile.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		bounded = bounded and tile.mesh.get_aabb().size.x <= 16.001 and tile.mesh.get_aabb().size.z <= 16.001
		for i: int in range(vertices.size()):
			aligned = aligned and uv[i].is_equal_approx((Vector2(vertices[i].x,vertices[i].z)+track.half_extent)/(track.half_extent*2.0))
		for i: int in range(0,vertices.size(),3): area += (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length()*0.5
	check(bounded,"each tile has bounded light-culling extent")
	check(aligned,"terrain sampling coordinates remain continuous across tiles")
	check(is_equal_approx(area,track.half_extent.x*track.half_extent.y*4.0),"tiles cover the original terrain area exactly")
	var lamps: Array[Node] = visual.find_children("*","OmniLight3D",true,false)
	check(lamps.size() == 3,"all authored lamps retained")
	check(lamps.all(func(lamp: OmniLight3D) -> bool: return lamp.light_energy == 5.0 and lamp.omni_range == 15.0 and not lamp.shadow_enabled),"lamp brightness, range and shadow settings preserved")
	check((visual.get_child(0) as MeshInstance3D).layers == 2,"fully hidden backdrop excludes point lights")
	var original := NativeTrackVisual.new()
	original.partition_night_ground = false
	root.add_child(original)
	original.build(track,BridgePresentation.new(track))
	check(_road_triangles(original) == _road_triangles(visual),"partitioning preserves every road triangle, normal, UV and kerb coordinate")
	original.queue_free()
	track.metadata.creator_document.objects.append({"kind":"light","position":[track.half_extent.x-1,0.0],"rotation":0.0,"scale":4.0})
	check(not visual._lamps_inside_terrain(track),"boundary and scaled lamps keep background illumination")
	visual.refresh_editor_objects(track,false)
	check((visual.get_child(0) as MeshInstance3D).layers == 1,"editor lamp edits restore backdrop lighting when needed")
	visual.queue_free()
	await process_frame
	var saved_scale: float = root.scaling_3d_scale
	root.scaling_3d_scale = 0.667
	var game: Node = preload("res://core/game.tscn").instantiate()
	game.initial_track = track
	root.add_child(game)
	root.scaling_3d_scale = 0.55
	root.remove_child(game)
	check(is_equal_approx(root.scaling_3d_scale,0.667),"leaving a race restores the previous viewport resolution")
	game.free()
	root.scaling_3d_scale = saved_scale
	if "--capture" in OS.get_cmdline_user_args(): await capture_local()
	print("NIGHT_LIGHTING: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func _road_triangles(visual: NativeTrackVisual) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in visual.get_children():
		if not node is MeshInstance3D or not node.material_override is ShaderMaterial: continue
		if node.material_override.shader != NativeTrackVisual.CREATOR_ROAD_SHADER: continue
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for first: int in range(0,vertices.size(),3):
			var row: Array = []
			for parameter: String in ["road_color","gravel","grass","kerb"]: row.append(node.material_override.get_shader_parameter(parameter))
			for index: int in range(first,first+3):
				for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
					row.append(null if arrays[attribute] == null else arrays[attribute][index])
			var key: String = var_to_bytes(row).hex_encode()
			result[key] = int(result.get(key,0))+1
	return result

func capture_local() -> void:
	var doc: Dictionary = TrackLibrary.new().load_document("track_c7ad183a78f7a033")
	if doc.is_empty(): return
	var track: NativeTrack = TrackCompiler.compile(doc)
	for partition: bool in [false,true]:
		var world := Node3D.new()
		root.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-58,-35,0)
		light.shadow_enabled = true
		world.add_child(light)
		TrackTheme.apply_lighting("night_city",environment.environment,light)
		var ground := NativeTrackVisual.new()
		ground.partition_night_ground = partition
		world.add_child(ground)
		ground.build(track,BridgePresentation.new(track))
		if "--keep-backdrop-lights" in OS.get_cmdline_user_args(): (ground.get_child(0) as MeshInstance3D).layers = 1
		var camera := FollowCamera.new()
		world.add_child(camera)
		camera.current = true
		camera.follow(Vector2(12,18),Vector2.ZERO,0,0,true)
		for i: int in range(5): await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/night-performance/"+("after" if partition else "before")+".png"))
		world.queue_free()
		await process_frame
