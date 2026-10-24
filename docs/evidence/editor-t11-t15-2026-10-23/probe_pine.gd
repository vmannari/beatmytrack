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
	while (app.editor_commits.unsettled() or app.editor_writes.unsettled(app.library,str(app.document.get("id",""))) or app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
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

func lamp_state(lamp: OmniLight3D) -> Array:
	return [lamp.global_transform,lamp.light_color,lamp.light_energy,lamp.omni_range,lamp.omni_attenuation,lamp.shadow_enabled,lamp.light_cull_mask]

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
	if "--same-source" in OS.get_cmdline_user_args(): await fresh._build_placed_objects(track)
	else: await fresh.refresh_editor_objects(track,false)
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
	# Compare the same cosmetic time. The racing root is externally ticked;
	# editor effects normally advance themselves while the fixture waits.
	for node: Node in stage.find_children("*","Node",true,false):
		if node is NightPropEffects:
			node.externally_ticked = true; node.elapsed = 0.0; node._publish()
	# The Mobile renderer can sum otherwise identical separately-created light
	# RIDs in a different order (the identical-originals control reproduces six
	# one-channel differences). Verify the actual lights, then render both
	# geometry trees under one fixed rig; retain the zero-difference assertion.
	var original_lamps: Array = old.find_children("*","OmniLight3D",true,false)
	var fresh_lamps: Array = fresh.find_children("*","OmniLight3D",true,false)
	var original_states: Array = []; var fresh_states: Array = []
	for lamp: OmniLight3D in original_lamps: original_states.append(lamp_state(lamp))
	for lamp: OmniLight3D in fresh_lamps: fresh_states.append(lamp_state(lamp))
	original_states.sort_custom(func(a: Array,b: Array) -> bool: return var_to_str(a) < var_to_str(b))
	fresh_states.sort_custom(func(a: Array,b: Array) -> bool: return var_to_str(a) < var_to_str(b))
	check(original_states == fresh_states,theme_id+" authored light poses and values remain exact")
	for lamp: OmniLight3D in original_lamps:
		var shared: OmniLight3D = lamp.duplicate()
		stage.add_child(shared); shared.global_transform = lamp.global_transform
		lamp.hide()
	for lamp: OmniLight3D in fresh_lamps: lamp.hide()
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
			if delta > 0:
				changed += 1
				if changed < 20: print("PIXEL_CHANNEL x=",(index/4)%before.get_width()," y=",(index/4)/before.get_width()," channel=",index%4," values=",a[index],"/",b[index])
		print("EDITOR_INCREMENTAL_PIXELS ",theme_id," changed_channels=",changed," maximum=",maximum)
		check(maximum == 0,theme_id+" paired authored pixels preserve original shading exactly")
	viewport.queue_free(); await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	var mode: String = "identical-originals" if "--same-source" in OS.get_cmdline_user_args() else "paired"
	for iteration: int in range(3):
		evidence = ProjectSettings.globalize_path("res://../docs/evidence/editor-t11-t15-2026-10-23/initial/pine-control/")+mode+"-"+str(iteration)
		DirAccess.make_dir_recursive_absolute(evidence)
		await compare_props("pine")
	print("PINE_CONTROL ",mode," ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
