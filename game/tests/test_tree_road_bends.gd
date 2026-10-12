extends SceneTree
## Actual retained owner track; presentation bends must have simple borders.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func crossings(polygon: PackedVector2Array) -> int:
	var result: int = 0
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		for j: int in range(i+2,polygon.size()):
			if i == 0 and j == polygon.size()-1: continue
			var c: Vector2 = polygon[j]
			var d: Vector2 = polygon[(j+1)%polygon.size()]
			var hit: Variant = Geometry2D.segment_intersects_segment(a,b,c,d)
			if hit is Vector2 and minf(minf(hit.distance_to(a),hit.distance_to(b)),minf(hit.distance_to(c),hit.distance_to(d))) > 0.001: result += 1
	return result

func run() -> void:
	root.size = Vector2i(1280,720)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/to_the_trees.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	print("TREE_CONTENT_HASH ",track.content_hash)
	check(track.content_hash == "1617ca276e8e3de24c70b247faebcd29299b461b22183f4e253f155df246c0bf","actual track retains compiler22 canonical content identity")
	var original: Dictionary = doc.duplicate(true)
	var physical: Array = track.kerbs.triangles.duplicate(true)
	var cells: PackedInt32Array = track.cells.duplicate()
	var topology: Dictionary = RoadPieces.prepare_endpoints(doc.pieces)
	var measured: Dictionary = RoadPieces.prepare_endpoints(doc.pieces)
	var started: int = Time.get_ticks_usec()
	for index: int in range(doc.pieces.size()):
		if doc.pieces[index].kind == "bridge": continue
		for margin: float in [0.0,-0.2]: VisualRoadJoin.build(doc.pieces,index,margin,measured)
	print("TREE_BORDER_COLD_MS ",(Time.get_ticks_usec()-started)/1000.0)
	started = Time.get_ticks_usec()
	for index: int in range(doc.pieces.size()):
		if doc.pieces[index].kind == "bridge": continue
		for margin: float in [0.0,-0.2]: VisualRoadJoin.build(doc.pieces,index,margin,measured)
	print("TREE_BORDER_WARM_MS ",(Time.get_ticks_usec()-started)/1000.0)
	for index: int in range(doc.pieces.size()):
		if doc.pieces[index].kind == "bridge": continue
		for margin: float in [0.0,-0.2]:
			var shape: Dictionary = VisualRoadJoin.build(doc.pieces,index,margin,topology)
			var count: int = 0
			for contour: PackedVector2Array in shape.contours: count += crossings(contour)
			print("TREE_BEND piece=",index," kind=",doc.pieces[index].kind," margin=",margin," crossings=",count)
			check(count == 0,"simple visual border for actual piece %d margin %.2f" % [index,margin])
			if index == 2:
				for endpoint: int in range(2):
					var match: Array = RoadPieces._matches(topology,index,endpoint)[0]
					var neighbor: Dictionary = VisualRoadJoin.build(doc.pieces,match[0],margin,topology)
					var closest := PackedFloat32Array()
					var cut: Dictionary = shape.cuts[endpoint]
					for point: Vector2 in shape.polygon:
						if absf((point-Vector2(cut.point)).dot(cut.normal)) > 0.001: continue
						var distance: float = INF
						for other: Vector2 in neighbor.polygon: distance = minf(distance,point.distance_to(other))
						closest.append(distance)
					print("TREE_JOIN endpoint=",endpoint," margin=",margin," differences=",closest)
					check(closest.size() == 2,"folded bend retains both open mouth tips")
					for distance: float in closest: check(distance < 0.0001,"folded bend and adjacent road share identical rounded tips")
	for mirror: bool in [false,true]:
		for heading: float in [0.0,43.0,197.0]:
			var piece: Dictionary = doc.pieces[2].duplicate(true)
			piece.flip = mirror; piece.heading = heading
			for margin: float in [0.0,-0.2]:
				var shape: Dictionary = VisualRoadJoin.build([piece],0,margin)
				for polygon: PackedVector2Array in shape.contours:
					check(crossings(polygon) == 0,"rotated/mirrored tight S border is simple")
					check(not Geometry2D.triangulate_polygon(polygon).is_empty(),"rotated/mirrored tight S border triangulates")
	check(doc == original,"presentation repair preserves authored road coordinates, objects and start")
	await unchanged_meshes()
	check(track.kerbs.triangles == physical and track.cells == cells,"cosmetic repair retains exact physical kerbs and surfaces")
	if DisplayServer.get_name() == "headless":
		print("TREE_ROAD_BENDS: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0); return
	preload("res://track/road_mesh_disk_cache.gd").directory = ""
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false); game.paused = true; game.countdown_ticks = 0; game.race_cues.hide()
	var phase: String = OS.get_environment("BMT_BEND_PHASE")
	if phase.is_empty(): phase = "after"
	var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/tree-road-bends-2026-10-08/"+phase)
	DirAccess.make_dir_recursive_absolute(evidence)
	for target: Vector2 in [Vector2(32,-18),Vector2(0,12),Vector2(-44,-24)]:
		game.sim.state.position = target; game.sim.state.heading = PI*0.5
		game.previous_position = target; game.previous_heading = game.sim.state.heading
		game.camera.follow(target,Vector2.ZERO,game.sim.state.heading,0.0,true)
		for frame: int in range(8): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(evidence.path_join("bend-%d-%d.png" % [target.x,target.y])) == OK,"capture actual track bend")
	root.size = Vector2i(960,540)
	game.sim.state.position = Vector2(32,-18); game.previous_position = game.sim.state.position
	game.camera.follow(Vector2(32,-18),Vector2.ZERO,game.sim.state.heading,0.0,true)
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join("bend-compact.png")) == OK,"capture compact landscape bend")
	game.queue_free(); await process_frame
	await process_frame
	check(track.kerbs.triangles == physical and track.cells == cells,"actual race renderer preserves canonical kerbs and surfaces")
	print("TREE_ROAD_BENDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func mesh_signature(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D and node.mesh != null:
		for surface: int in range(node.mesh.get_surface_count()): result.append([node.transform,node.mesh.surface_get_arrays(surface)])
	for child: Node in node.get_children(): result.append_array(mesh_signature(child))
	return result

func unchanged_meshes() -> void:
	var old_join := GDScript.new()
	old_join.source_code = FileAccess.get_file_as_string("res://../docs/evidence/tree-road-bends-2026-10-08/before/game/track/visual_road_join.gd").replace("\r\n","\n").replace("class_name VisualRoadJoin\n","")
	check(old_join.reload() == OK,"task-start join/kerb helper compiles")
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string("res://../docs/evidence/tree-road-bends-2026-10-08/before/game/track/native_track_visual.gd").replace("\r\n","\n").replace("class_name NativeTrackVisual\n","")
	check(baseline.reload() == OK,"task-start renderer compiles")
	for theme: String in ["pine","desert","winter","night_city"]:
		var doc: Dictionary = TrackDocument.create_default(); doc.theme = theme
		doc.pieces = [RoadPieces.create("straight",Vector2(-28,0)),RoadPieces.create("curve",Vector2.ZERO),RoadPieces.create("hairpin",Vector2(10,-20)),RoadPieces.create("bridge",Vector2(-20,30))]
		var native: NativeTrack = TrackCompiler.compile(doc)
		var prior: RefCounted = old_join.new()
		for index: int in range(doc.pieces.size()-1):
			for margin: float in [0.0,-0.2]:
				var expected: Dictionary = prior.call("build",doc.pieces,index,margin)
				var current: Dictionary = VisualRoadJoin.build(doc.pieces,index,margin)
				check(current.polygon == expected.polygon and current.cuts == expected.cuts,"ordinary road join retains task-start shape")
		check(await VisualRoadJoin.kerb_triangles(doc) == await prior.call("kerb_triangles",doc),"ordinary cosmetic kerbs retain task-start geometry")
		var expected: Array = []
		for previous: bool in [true,false]:
			var visual: Node3D = baseline.new() if previous else NativeTrackVisual.new()
			visual.set("cache_road_meshes",false); visual.set("theme_id",theme); visual.set("colors",TrackTheme.palette(theme))
			root.add_child(visual)
			await visual.call("_build_creator_roads",native)
			if previous: expected = mesh_signature(visual)
			else: check(mesh_signature(visual) == expected,"ordinary "+theme+" road meshes remain byte-identical")
			visual.free()
