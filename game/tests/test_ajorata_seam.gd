extends SceneTree
## Actual owner track: edge paint must not close a connected driving lane.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func cap_triangles(visual: Node, cut: Dictionary, parameter: String = "road_marking") -> int:
	var result: int = 0
	for child: Node in visual.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial: continue
		var material: ShaderMaterial = child.material_override
		if material.shader.resource_path != "res://track/creator_road.gdshader" or not material.get_shader_parameter(parameter): continue
		var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i: int in range(0,vertices.size(),3):
			var center: Vector2 = Vector2.ZERO
			for j: int in range(3): center += Vector2(vertices[i+j].x,-vertices[i+j].z)/3.0
			var delta: Vector2 = center-Vector2(cut.point)
			if absf(delta.dot(cut.normal)) < 0.75 and absf(delta.dot(Vector2(cut.normal).orthogonal())) < float(cut.span)*0.30: result += 1
	return result

func lost_caps(shape: Dictionary, cut: Dictionary) -> int:
	var count: int = 0
	for polygon: PackedVector2Array in shape.contours:
		for i: int in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i+1)%polygon.size()]
			var middle: Vector2 = (a+b)*0.5-Vector2(cut.point)
			if a.distance_to(b) < float(cut.span)*0.5 or absf(middle.dot(cut.normal)) > 0.75 or absf(middle.dot(Vector2(cut.normal).orthogonal())) > float(cut.span)*0.3: continue
			if not RoadEdges._on_join_cut(a,b,shape.cuts) and not (shape.swept and RoadEdges._on_join_cap(a,b,shape.cuts)): count += 1
	return count

func run() -> void:
	root.size = Vector2i(1280,720)
	preload("res://track/road_mesh_disk_cache.gd").directory = ""
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	print("AJORATA_CONTENT_HASH ",track.content_hash)
	check(track.content_hash == "e4c11a875b135001b1c648155cc8782d59c1922d6c1a8078d8ffa9b9368e6174","retained Ajorata canonical identity")
	var original: Dictionary = doc.duplicate(true)
	var contacts: Array = track.kerbs.triangles.duplicate(true)
	var cells: PackedInt32Array = track.cells.duplicate()
	var old := GDScript.new()
	old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/ajorata-seam-2026-10-08/before/game/track/visual_road_join.gd").replace("\r\n","\n").replace("class_name VisualRoadJoin\n","")
	check(old.reload() == OK,"original helper compiles for seam reproduction")
	var previous: RefCounted = old.new()
	var original_cut: Dictionary = RoadEdges._join_cuts(doc.pieces,9)[1]
	check(lost_caps(previous.call("build",doc.pieces,9,-0.2),original_cut) > 0,"same lane probe reproduces the original unrecognized internal cap")
	for reversed: bool in [false,true]:
		for angle: float in [0.0,43.0,167.0]:
			var pieces: Array = doc.pieces.duplicate(true)
			for piece: Dictionary in pieces:
				var position: Vector2 = Vector2(piece.position[0],piece.position[1]).rotated(deg_to_rad(angle))
				piece.position = [position.x,position.y]; piece.heading = fposmod(piece.heading+angle,360.0)
			var index: int = 9
			if reversed: pieces.reverse(); index = pieces.size()-1-index
			var shape: Dictionary = VisualRoadJoin.build(pieces,index,-0.2)
			var cut: Dictionary = RoadEdges._join_cuts(pieces,index)[1]
			check(lost_caps(shape,cut) == 0,"rotated/reordered narrow join retains cap recognition")
	var visual := NativeTrackVisual.new(); visual.cache_road_meshes = false
	visual.theme_id = "pine"; visual.colors = TrackTheme.palette("pine")
	root.add_child(visual); await visual._build_creator_roads(track)
	var topology: Dictionary = RoadPieces.prepare_endpoints(doc.pieces)
	var targets: Array[Vector2] = [Vector2(14.2981,16.86583)]
	for index: int in range(doc.pieces.size()):
		var shape: Dictionary = VisualRoadJoin.build(doc.pieces,index,-0.2,topology)
		for cut: Dictionary in RoadEdges._join_cuts(doc.pieces,index,topology):
			var partner: Array = RoadPieces._matches(topology,index,int(cut.endpoint))[0]
			if int(partner[0]) < index: continue
			var markings: int = cap_triangles(visual,cut)
			var apron: int = cap_triangles(visual,cut,"gravel")
			print("AJORATA_SEAM piece=",index," partner=",partner[0]," at=",cut.point," span=",cut.span," markings=",markings," apron=",apron)
			check(markings == 0,"no cross-lane marking at actual joined mouth %d/%d" % [index,partner[0]])
			check(apron == 0,"no sandy cross-lane apron at actual joined mouth %d/%d" % [index,partner[0]])
	check(doc == original and track.kerbs.triangles == contacts and track.cells == cells,"renderer preserves authored map and exact physical kerbs/surfaces")
	visual.free()
	if DisplayServer.get_name() == "headless":
		print("AJORATA_SEAM_TESTS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0); return
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false); game.paused = true; game.countdown_ticks = 0; game.race_cues.hide()
	var phase: String = OS.get_environment("BMT_AJORATA_PHASE")
	if phase.is_empty(): phase = "after"
	var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/ajorata-seam-2026-10-08/"+phase)
	DirAccess.make_dir_recursive_absolute(evidence)
	for target: Vector2 in targets:
		game.sim.state.position = target; game.sim.state.heading = PI*0.5
		game.previous_position = target; game.previous_heading = game.sim.state.heading
		game.camera.follow(target,Vector2.ZERO,game.sim.state.heading,0.0,true)
		for frame: int in range(8): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(evidence.path_join("seam-%d-%d.png" % [target.x,target.y])) == OK,"capture actual Ajorata junction")
	root.size = Vector2i(960,540)
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join("seam-compact.png")) == OK,"capture compact junction")
	game.queue_free(); await process_frame; await process_frame
	await create_timer(0.25).timeout
	print("AJORATA_SEAM_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
