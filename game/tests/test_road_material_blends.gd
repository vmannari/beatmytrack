extends "res://tests/test_road_piece_materials.gd"
## Owner correction: Desert-like compacted finish with broad, smooth joins.

func _initialize() -> void:
	output = "res://../docs/evidence/road-material-blends-2026-10-27"
	run.call_deferred()

func domain() -> void:
	super.domain()
	var before_masks: GDScript
	var before_path: String = "res://../build/road-material-blends-2026-10-27/before/game/editor/creator_preview_masks.gd"
	if FileAccess.file_exists(before_path):
		before_masks = GDScript.new()
		before_masks.source_code = FileAccess.get_file_as_string(before_path).replace("\r\n","\n").replace("class_name CreatorPreviewMasks\n","")
		check(before_masks.reload() == OK,"captured task-start mask implementation compiles independently")
	for theme: String in ["pine","storm"]:
		var doc: Dictionary = circuit(theme); doc.pieces[0].surface = "gravel"
		var track: NativeTrack = TrackCompiler.compile(doc)
		var before: PackedByteArray = var_to_bytes([track.cells,track.deck_cells,track.metadata,track.kerbs.triangles,track.content_hash])
		var image: Image = CreatorPreviewMasks.road(track)
		var weights: Array = []
		for delta: float in [-4.0,-2.5,-1.5,-0.5,0.5,1.5,2.5,4.0]: weights.append(sample(image,track,Vector2(10+delta,-20)).g)
		if before_masks != null:
			var old_image: Image = before_masks.road(track)
			var old_weights: Array = []
			for delta: float in [-4.0,-2.5,-1.5,-0.5,0.5,1.5,2.5,4.0]: old_weights.append(sample(old_image,track,Vector2(10+delta,-20)).g)
			check(old_weights.slice(1,-1).all(func(value: float) -> bool: return value == 0.0 or value == 1.0) and weights.slice(1,-1).all(func(value: float) -> bool: return value > 0.0 and value < 1.0),theme+" task-start abrupt join becomes six intermediate blend samples")
			observations.append({"theme":theme,"task_start_transition_samples":old_weights,"current_transition_samples":weights})
		check(weights[0] > 0.99 and weights[-1] < 0.01,theme+" full materials survive beyond the blend")
		for i: int in range(1,weights.size()):
			check(weights[i] < weights[i-1] and float(weights[i-1])-float(weights[i]) < 0.4,theme+" material blend progresses smoothly at step "+str(i))
		check(weights[2] > 0.6 and weights[2] < 0.95 and weights[5] > 0.05 and weights[5] < 0.4,theme+" several metres of intermediate finish on both sides")
		check(before == var_to_bytes([track.cells,track.deck_cells,track.metadata,track.kerbs.triangles,track.content_hash]),theme+" visual blend preserves all canonical data and identity")
		doc.pieces[1].surface = "gravel"
		track = TrackCompiler.compile(doc); image = CreatorPreviewMasks.road(track)
		check(sample(image,track,Vector2(9,-20)).g > 0.99 and sample(image,track,Vector2(11,-20)).g > 0.99,theme+" equal-material joins have no artificial blend")
		var isolated: Dictionary = TrackDocument.create_blank(); isolated.theme = theme; isolated["automatic_scenery"] = false
		var loose: Dictionary = RoadPieces.create("straight",Vector2(-20,0),0,6); loose.length = 40; loose.surface = "gravel"
		var firm: Dictionary = RoadPieces.create("straight",Vector2(-20,12),0,6); firm.length = 40
		isolated.pieces = [loose,firm]
		track = TrackCompiler.compile(isolated); image = CreatorPreviewMasks.road(track)
		check(sample(image,track,Vector2.ZERO).g > 0.99 and sample(image,track,Vector2(0,2.8)).g > 0.99,theme+" gravel retains its finish at the grass boundary")
		check(sample(image,track,Vector2(0,12)).g < 0.01,theme+" separate nearby roads do not bleed across grass")
		doc = circuit(theme); doc.pieces[0].kind = "bridge"; doc.pieces[0].surface = "gravel"
		track = TrackCompiler.compile(doc)
		var deck: Image = CreatorPreviewMasks.bridge_materials(track)
		image = CreatorPreviewMasks.road(track)
		check(sample(deck,track,Vector2(9,-20)).b > 0.6 and sample(deck,track,Vector2(9,-20)).b < 0.95,theme+" bridge deck gradually reaches its ground joint")
		check(sample(image,track,Vector2(11,-20)).g > 0.05 and sample(image,track,Vector2(11,-20)).g < 0.4,theme+" ground road gradually meets the bridge finish")
		check(sample(deck,track,Vector2(-10,-20)).b > 0.99 and sample(image,track,Vector2(-10,-20)).g < 0.01,theme+" ground and deck remain independent at midspan")
		check(deck == track.editor_road_mask and CreatorPreviewMasks.bridge_materials(track) == deck,theme+" bridge installation reuses the worker's shared material image")
		var crossing: Dictionary = RoadPieces.create("straight",Vector2(-10,-40),90); crossing.length = 40
		doc.pieces.append(crossing)
		track = TrackCompiler.compile(doc)
		check(sample(CreatorPreviewMasks.bridge_materials(track),track,Vector2(-10,-20)).b > 0.99 and sample(CreatorPreviewMasks.road(track),track,Vector2(-10,-20)).g < 0.01,theme+" asphalt underpass cannot tint the gravel deck")
		var first: Dictionary = RoadPieces.create("bridge",Vector2(-30,0)); first.length = 40; first.surface = "gravel"
		var second: Dictionary = RoadPieces.create("bridge",Vector2(10,0)); second.length = 32; second.surface = "asphalt"
		isolated.pieces = [first,second]
		track = TrackCompiler.compile(isolated); deck = CreatorPreviewMasks.bridge_materials(track)
		check(sample(deck,track,Vector2(9,0)).b > 0.6 and sample(deck,track,Vector2(11,0)).b < 0.4,theme+" bridge-to-bridge join has the same gradual blend")
		var angle: float = 30.0
		first = RoadPieces.create("straight",Vector2(-30,-15),angle); first.length = 30; first.surface = "gravel"
		var end: Dictionary = RoadPieces.end_pose(first)
		second = RoadPieces.create("straight",end.position,angle); second.length = 30
		isolated.pieces = [first,second]
		track = TrackCompiler.compile(isolated); image = CreatorPreviewMasks.road(track)
		var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle))
		var left: float = sample(image,track,Vector2(end.position)-direction).g
		var right: float = sample(image,track,Vector2(end.position)+direction).g
		check(left > 0.5 and left < 0.99 and right > 0.01 and right < 0.5,theme+" oblique joined roads retain gradual intermediate values")
		observations.append({"theme":theme,"transition_samples":weights,"blend_half_metres":CreatorPreviewMasks.MATERIAL_BLEND_HALF})

func shot(label: String) -> void:
	await super.shot(label)
	if DisplayServer.get_name() == "headless" or not label.ends_with("-gravel"): return
	var selected: int = app.canvas.selected_piece
	app.canvas.selected_piece = -1; app.canvas.refresh()
	await super.shot(label+"-unselected")
	app.canvas.selected_piece = selected; app.canvas.refresh()

func editor() -> void:
	await super.editor()
	if DisplayServer.get_name() == "headless": return
	for theme: String in ["pine","storm"]:
		var doc: Dictionary = circuit(theme); doc.pieces[0].kind = "bridge"; doc.pieces[0].surface = "gravel"
		var track: NativeTrack = TrackCompiler.compile(doc)
		var view := SubViewport.new(); view.size = Vector2i(1280,720); view.own_world_3d = true; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 30
		view.add_child(camera); camera.position = Vector3(10,32,47); camera.look_at(Vector3(10,0,20)); camera.current = true
		var environment := WorldEnvironment.new(); environment.environment = Environment.new(); view.add_child(environment)
		var light := DirectionalLight3D.new(); light.shadow_enabled = true; view.add_child(light)
		TrackTheme.apply_lighting(theme,environment.environment,light)
		var visual := NativeTrackVisual.new(); visual.cache_road_meshes = false; visual.persist_road_meshes = false; visual.cache_race_world = false
		view.add_child(visual)
		await visual.build(track,BridgePresentation.new(track))
		var deck: MeshInstance3D = visual.find_child("BridgeAsphalt",true,false)
		check(deck != null and deck.material_override.get_shader_parameter("bridge_blend_mask") != null,theme+" real bridge renderer binds independent blend mask")
		check(deck != null and deck.material_override.get_shader_parameter("gravel_road_base") == TrackTheme.DESERT[0],theme+" real gravel finish uses Desert road palette")
		for frame: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		check(view.get_texture().get_image().save_png(output+"/"+RenderingServer.get_current_rendering_method()+"-"+theme+"-bridge-join.png") == OK,theme+" native bridge transition screenshot")
		view.queue_free(); await process_frame
