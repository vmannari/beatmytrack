extends SceneTree
## Real durable-save/input checks plus paired original/instanced authored renders.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String
var metrics: Array[Dictionary] = []

class CountingStore extends TrackLibrary:
	var wip_writes: int = 0
	var original_writes: int = 0
	var fail_wip: bool = false
	var fail_original: bool = false
	func save_wip(doc: Dictionary) -> Error:
		wip_writes += 1
		if fail_wip: last_error = "Injected WIP failure"; return ERR_FILE_CANT_WRITE
		return super.save_wip(doc)
	func save_document(doc: Dictionary) -> Error:
		original_writes += 1
		if fail_original: last_error = "Injected original failure"; return ERR_FILE_CANT_WRITE
		return super.save_document(doc)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func metric(label: String, began: int) -> void:
	var entry: Dictionary = {"operation":label,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0}
	metrics.append(entry)
	print("EDITOR_INCREMENTAL_METRIC ",JSON.stringify(entry))

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"editor finishes latest preparation")
	for node: Node in app.find_children("*","Window",true,false):
		if node is Window: node.hide(); node.queue_free()
	await process_frame

func circuit() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "incremental_objects"
	doc.name = "Incremental object review"
	var position := Vector2(-47,-36)
	var heading: float = 0.0
	for side: int in range(2):
		for index: int in range(47):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,6)
			piece.length = 2.0
			doc.pieces.append(piece)
			position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,6)
		turn.radius = 36.0; doc.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn)
		position = pose.position; heading = pose.heading
	doc = RoadPieces.route_from_pieces(doc).document
	for index: int in range(24): doc.objects.append({"kind":"container","position":[-42.0+(index%12)*7.0,-26.0+(index/12)*7.0],"rotation":float(index%4)*90.0})
	return doc

func props_fixture(theme_id: String) -> NativeTrack:
	var objects: Array = []
	for family: Array in CreatorCatalog.ASSETS:
		for kind: String in family[3]:
			var index: int = objects.size()
			var object: Dictionary = {"kind":kind,"position":[-48.0+(index%10)*10.0,-25.0+(index/10)*13.0],"rotation":float((index*37)%360)}
			if kind not in ["tyre_stack","tyre_wall"]: object.scale = 0.75 if index%2 else 1.25
			if kind in ObjectRuns.CONTINUOUS: object.length = 3.25
			if kind == "container": object.color = "c05a38"
			if kind == "speed_bump": object.span = 8.25
			objects.append(object)
	# Shared endpoints, intersections and coincident paint variants exercise
	# the original normal generation and opaque ordering between objects.
	objects.append_array([
		{"kind":"barrier","position":[-15.0,25.0],"rotation":0.0,"length":6.0},
		{"kind":"barrier","position":[-9.0,25.0],"rotation":0.0,"length":6.0},
		{"kind":"container","position":[15.0,25.0],"rotation":0.0,"color":"ad894f"},
		{"kind":"container","position":[15.0,25.0],"rotation":0.0,"color":"c05a38"},
		{"kind":"guardrail","position":[38.0,25.0],"rotation":0.0,"length":6.0},
		{"kind":"guardrail","position":[38.0,25.0],"rotation":90.0,"length":6.0}
	])
	var track := NativeTrack.new()
	track.metadata = {"theme":theme_id,"creator_document":{"objects":objects},"scenery_objects":[]}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	return track

func triangles(node: Node3D, parent_pose: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var result: Dictionary = {}
	if node.is_in_group("contact_lighting"): return result
	var pose: Transform3D = parent_pose*node.transform
	var mesh: Mesh
	var transforms: Array[Transform3D] = []
	if node is MeshInstance3D and node.visible:
		mesh = node.mesh; transforms.append(pose)
	elif node is MultiMeshInstance3D and node.visible:
		mesh = node.multimesh.mesh
		for index: int in range(node.multimesh.instance_count): transforms.append(pose*node.multimesh.get_instance_transform(index))
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var pigments: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for transform: Transform3D in transforms:
				for offset: int in range(0,count,3):
					var corners: Array = []
					for corner: int in range(3):
						var index: int = indices[offset+corner] if not indices.is_empty() else offset+corner
						var p: Vector3 = transform*vertices[index]
						var n: Vector3 = (transform.basis*normals[index]).normalized()
						var pigment: Color = pigments[index] if not pigments.is_empty() else Color.WHITE
						corners.append({"p":p,"n":n,"color":pigment,"key":str(p.snapped(Vector3.ONE*0.001))+"/"+str(pigment)})
					corners.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.key < b.key)
					var keys: Array[String] = []
					for corner: Dictionary in corners: keys.append(corner.key)
					var key: String = "|".join(keys)
					if not result.has(key): result[key] = []
					result[key].append(corners)
	for child: Node in node.get_children():
		if not child is Node3D or not child.visible: continue
		var sub: Dictionary = triangles(child,pose)
		for key: String in sub:
			if not result.has(key): result[key] = []
			result[key].append_array(sub[key])
	return result

func same_triangles(before: Dictionary, after: Dictionary) -> bool:
	if before.size() != after.size(): return false
	var maximum_position: float = 0.0
	var maximum_normal: float = 0.0
	for key: String in before:
		if not after.has(key) or before[key].size() != after[key].size(): return false
		var candidates: Array = after[key].duplicate()
		for triangle: Array in before[key]:
			var match_index: int = -1
			for index: int in range(candidates.size()):
				var matches: bool = true
				for corner: int in range(3):
					var p: float = Vector3(triangle[corner].p).distance_to(candidates[index][corner].p)
					var n: float = Vector3(triangle[corner].n).distance_to(candidates[index][corner].n)
					matches = matches and p == 0.0 and n == 0.0 and triangle[corner].color == candidates[index][corner].color
					maximum_position = maxf(maximum_position,p); maximum_normal = maxf(maximum_normal,n)
				if matches: match_index = index; break
			if match_index < 0: return false
			candidates.remove_at(match_index)
	print("EDITOR_TRIANGLE_TOLERANCE maximum_position_m=",maximum_position," maximum_normal_distance=",maximum_normal)
	return true

func compare_props(theme_id: String) -> void:
	var track: NativeTrack = props_fixture(theme_id)
	var old := NativeTrackVisual.new(); old.theme_id = theme_id; old.colors = TrackTheme.palette(theme_id)
	var fresh := NativeTrackVisual.new(); fresh.theme_id = theme_id; fresh.colors = old.colors
	var viewport := SubViewport.new(); viewport.size = Vector2i(1280,720); viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new(); viewport.add_child(stage)
	stage.add_child(old); stage.add_child(fresh)
	await old._build_placed_objects(track)
	await fresh.refresh_editor_objects(track,false)
	var original_triangles: Dictionary = triangles(old)
	var updated_triangles: Dictionary = triangles(fresh)
	check(same_triangles(original_triangles,updated_triangles),theme_id+" triangle multiplicity, pigments, positions and normals are exact")
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 75
	stage.add_child(camera); camera.look_at_from_position(Vector3(0,88,-78),Vector3(0,0,-1)); camera.current = true
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-58,-35,0); light.shadow_enabled = true
	stage.add_child(light)
	var ambient := WorldEnvironment.new(); ambient.environment = Environment.new()
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; ambient.environment.ambient_light_energy = 0.45
	ambient.environment.background_mode = Environment.BG_COLOR; ambient.environment.background_color = Color("45535a")
	stage.add_child(ambient)
	if DisplayServer.get_name() != "headless":
		fresh.hide(); old.show()
		for frame: int in range(6): await RenderingServer.frame_post_draw
		var before: Image = viewport.get_texture().get_image()
		old.hide(); fresh.show()
		for frame: int in range(6): await RenderingServer.frame_post_draw
		var after: Image = viewport.get_texture().get_image()
		before.save_png(evidence+"/"+theme_id+"-original.png"); after.save_png(evidence+"/"+theme_id+"-incremental.png")
		var a: PackedByteArray = before.get_data(); var b: PackedByteArray = after.get_data()
		var maximum: int = 0; var changed: int = 0
		for index: int in range(a.size()):
			var delta: int = absi(int(a[index])-int(b[index]))
			maximum = maxi(maximum,delta)
			if delta > 0: changed += 1
		print("EDITOR_INCREMENTAL_PIXELS ",theme_id," changed_channels=",changed," maximum=",maximum)
		check(maximum == 0,theme_id+" paired authored pixels preserve original shading exactly")
	# Forced yield followed by a newer immediate edit must publish only the newest data.
	var obsolete: NativeTrack = props_fixture(theme_id)
	obsolete.metadata.creator_document.objects[0].position[0] += 4.0
	var latest: NativeTrack = props_fixture(theme_id)
	latest.metadata.creator_document.objects.append({"kind":"tyre_stack","position":[3.0,4.0],"rotation":0.0})
	latest.tyre_origins = LooseTyres.positions(latest.metadata.creator_document)
	fresh.refresh_editor_objects(obsolete,false,true)
	fresh.refresh_editor_objects(latest,false,false)
	for frame: int in range(3): await process_frame
	check(fresh.editor_objects.tyre_instances.multimesh.instance_count == latest.tyre_origins.size(),theme_id+" late refresh retains latest tyre population")
	check(fresh.editor_objects._editor_authored_batches.sources == latest.metadata.creator_document.objects,theme_id+" superseded refresh cannot replace current authored sources")
	viewport.queue_free(); await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://").path_join("../build/editor-incremental-2026-10-13").simplify_path().path_join(RenderingServer.get_current_rendering_method()+"-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(evidence)
	for biome: String in ["pine","desert","winter","night_city"]: await compare_props(biome)
	var storage := CountingStore.new(evidence+"/storage")
	app = load("res://core/app.tscn").instantiate()
	app.library = storage; app.records = LocalRecords.new(evidence+"/storage/records.json")
	app.cloud_root_override = evidence+"/storage/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = circuit()
	app.call("_show_screen","create")
	await settle()
	check(app.call("_save_track_now"),"first explicit Save commits both durable versions")
	await settle()
	var original_count: int = storage.original_writes
	var wip_count: int = storage.wip_writes
	var preview: NativeTrack = app.canvas.native_preview
	var objects: NativeTrackVisual = app.editor_world.visual.editor_objects
	var before_nodes: Array[Node] = objects.get_children()
	var before_meshes: Dictionary = {}
	for node: Node in before_nodes:
		if node is MeshInstance3D: before_meshes[node.get_instance_id()] = node.mesh
	var began: int = Time.get_ticks_usec()
	check(app.call("_save_track_now"),"unchanged Save succeeds")
	metric("unchanged_save",began)
	check(storage.original_writes == original_count and storage.wip_writes == wip_count,"unchanged Save writes neither original nor WIP")
	check(app.editor_preview_thread == null and app.canvas.native_preview == preview,"unchanged Save retains prepared collision and starts no compiler")
	check(objects.get_children() == before_nodes,"unchanged Save keeps every authored node")
	await settle()
	app.canvas.mode = "place"; app.canvas.stamp_kind = "tyre_stack"
	began = Time.get_ticks_usec(); app.canvas._place(app.canvas.to_screen(Vector2(0,5))); metric("tyre_with_24_containers",began)
	check(before_nodes.all(func(node: Node) -> bool: return node.get_parent() == objects),"adding a tyre keeps existing container and shadow groups")
	check(before_nodes.all(func(node: Node) -> bool: return not node is MeshInstance3D or before_meshes[node.get_instance_id()] == node.mesh),"adding a tyre uploads no replacement container mesh")
	check(objects.tyre_instances.multimesh.instance_count == 1,"new tyre is displayed immediately")
	check(storage.wip_writes == wip_count+1,"placement durably writes changed WIP once")
	check(app.call("_save_track_now"),"Save commits latest document while preview is pending")
	await settle()
	check(storage.load_document(app.document.id) == JSON.parse_string(JSON.stringify(app.document)),"saved original contains exact latest authoring data")
	var independent: NativeTrack = TrackCompiler.compile(app.document)
	check(app.canvas.native_preview.cells == independent.cells and app.canvas.native_preview.content_hash == independent.content_hash,"incremental presentation preserves exact canonical compile")
	app.call("_undo"); await settle()
	check(app.document.objects.size() == 24 and app.editor_world.visual.editor_objects.tyre_instances == null,"Undo removes the immediate tyre")
	app.call("_redo"); await settle()
	check(app.document.objects.size() == 25 and app.editor_world.visual.editor_objects.tyre_instances.multimesh.instance_count == 1,"Redo restores exactly one tyre")
	app.document.objects[0].position[0] += 1.0
	began = Time.get_ticks_usec(); app.call("_save_draft",true); metric("move_container",began)
	check(before_nodes.all(func(node: Node) -> bool: return node.get_parent() == objects),"moving a container keeps its shared mesh and untouched groups")
	await settle()
	storage.fail_wip = true; app.document.name = "WIP retry required"
	check(app.call("_save_draft",true) == ERR_FILE_CANT_WRITE and app.editor_save_error != OK,"changed WIP failures remain actionable")
	storage.fail_wip = false
	check(app.call("_save_draft",true) == OK,"WIP retry executes a real successful write")
	await settle()
	storage.fail_original = true
	check(not app.call("_save_track_now") and app.editor_retry_original,"changed original failures remain actionable")
	await settle()
	storage.fail_original = false
	check(app.call("_save_track_now") and not app.editor_retry_original,"original retry executes its real write")
	await settle()
	DirAccess.remove_absolute(storage.directory+"/wip/"+str(app.document.id)+".json")
	wip_count = storage.wip_writes
	check(app.call("_save_draft",true) == OK and storage.wip_writes == wip_count+1,"missing WIP primary is recreated despite unchanged in-memory document")
	DirAccess.remove_absolute(storage.directory+"/"+str(app.document.id)+".json")
	original_count = storage.original_writes
	check(app.call("_save_track_now") and storage.original_writes == original_count+1,"missing original primary is repaired through the atomic save path")
	await settle()
	var altered := FileAccess.open(storage.directory+"/"+str(app.document.id)+".json",FileAccess.WRITE)
	altered.store_string("{invalid_track}"); altered.close()
	original_count = storage.original_writes
	check(app.call("_save_track_now") and storage.original_writes == original_count+1,"external primary corruption invalidates the durable receipt and is repaired")
	await settle()
	check(storage.load_document(app.document.id) == JSON.parse_string(JSON.stringify(app.document)),"repair retains the exact current document and recoverable backup")
	app.queue_free(); await process_frame
	var output := FileAccess.open(evidence+"/results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method()},"\t")); output.close()
	print("EDITOR_INCREMENTAL_TESTS: %d checks, %d failures; evidence=%s" % [checks,failures,evidence])
	quit(1 if failures else 0)
