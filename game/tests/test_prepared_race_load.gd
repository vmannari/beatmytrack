extends SceneTree
const Cloud = preload("res://backend/cloud_tracks.gd")
const Tracks = preload("res://backend/prepared_track_cache.gd")
const Worlds = preload("res://track/prepared_world_cache.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",label)

func signature(node: Node) -> Array:
	var data: Array = [node.get_class()]
	if node is Node3D: data.append(node.transform)
	if node is GeometryInstance3D: data.append([node.layers,node.cast_shadow,node.material_override])
	if node is MeshInstance3D: data.append(node.mesh)
	if node is MultiMeshInstance3D:
		data.append([node.multimesh.mesh,node.multimesh.buffer,node.multimesh.instance_count])
	if node is OmniLight3D: data.append([node.light_color,node.light_energy,node.omni_range,node.light_cull_mask])
	data.append(node.get_groups())
	for child: Node in node.get_children(): data.append(signature(child))
	return data

func run() -> void:
	var folder: String = ProjectSettings.globalize_path("res://../build/prepared-race-tests")
	DirAccess.make_dir_recursive_absolute(folder)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	Tracks.clear()
	Worlds.entries.clear()
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata.json"))
	var body: String = JSON.stringify(doc)
	var path: String = folder.path_join("document.json")
	write(path,body)
	var entry: Dictionary = {"cache_path":path,"content_hash":body.sha256_text(),"id":"fixture","name":"Fixture","version_id":"version-1","track_id":"track-1","creator":"Fixture"}
	var cold: NativeTrack = Cloud.compile_entry(entry)
	var warm: NativeTrack = Cloud.compile_entry(entry)
	check(cold != warm and Tracks._capture(cold) == Tracks._capture(warm),"cached compilation creates an exact independent track")
	check(cold.kerbs != warm.kerbs and Tracks._capture(cold.kerbs) == Tracks._capture(warm.kerbs),"kerb contact data is exact and independently owned")
	warm.cells[0] = -99
	warm.metadata.creator_document.name = "Changed"
	warm.kerbs.triangles.clear()
	var restored: NativeTrack = Cloud.compile_entry(entry)
	check(restored.cells == cold.cells and restored.metadata == cold.metadata and restored.kerbs.triangles == cold.kerbs.triangles,"race/editor mutations cannot alter the prepared snapshot")
	entry.version_id = "version-2"
	entry.id = "another-alias"
	check(Cloud.compile_entry(entry).metadata.cloud_version == "version-2" and Cloud.compile_entry(entry).identity == "another-alias","cache reuse retains current pinned version and identity")
	write(path,"corrupt")
	check(Cloud.compile_entry(entry) == null,"warm cache cannot hide a corrupt document")
	DirAccess.remove_absolute(path)
	check(Cloud.compile_entry(entry) == null,"warm cache cannot resurrect a removed document")
	write(path,body)
	var thread := Thread.new()
	thread.start(Cloud.compile_entry.bind(entry))
	var concurrent: NativeTrack = Cloud.compile_entry(entry)
	check(thread.wait_to_finish().cells == concurrent.cells,"background browsing and race start can reuse the same cache")
	check(Tracks.restore([path,body.sha256_text(),"different-compiler"]) == null,"compiler revision fences prepared geometry")
	for index: int in range(7): Tracks.remember(["bounded",index],cold)
	var track_bytes: int = 0
	for value: Dictionary in Tracks._entries: track_bytes += int(value.bytes)
	check(Tracks._entries.size() == Tracks.MAX_ENTRIES and track_bytes <= Tracks.MAX_BYTES,"compiled snapshots obey both memory and entry limits")
	check(Tracks.restore(["bounded",0]) == null and Tracks.restore(["bounded",6]) != null,"compiled snapshot eviction retains the most recent tracks")
	var all_world_bytes: int = 0
	for theme: String in ["pine","desert","winter","storm","night_city"]:
		doc.theme = theme
		doc.objects.append({"kind":"flowers","position":[10.0,20.0],"rotation":0.0})
		doc.objects.append({"kind":"tyre_stack","position":[20.0,20.0],"rotation":0.0})
		if theme == "night_city": doc.objects.append({"kind":"light","position":[25.0,20.0],"rotation":0.0})
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track != null,theme+" fixture compiles")
		if track == null: continue
		Tracks.remember([theme],track)
		var prepared: NativeTrack = Tracks.restore([theme])
		check(Tracks._capture(track) == Tracks._capture(prepared) and Tracks._capture(track.snow_banks) == Tracks._capture(prepared.snow_banks),theme+" compiled and snow contact geometry is exact")
		var normal_sim := VehicleSimulation.new(VehicleCatalog.config("compact"))
		var prepared_sim := VehicleSimulation.new(VehicleCatalog.config("compact"))
		normal_sim.reset(track.spawn,track.spawn_heading)
		prepared_sim.reset(prepared.spawn,prepared.spawn_heading)
		for tick: int in range(480):
			var input := DriveFrame.sample(sin(tick*0.03)*0.7,1.0,0.0)
			normal_sim.step(input,track)
			prepared_sim.step(input,prepared)
		check(Tracks._capture(normal_sim.state) == Tracks._capture(prepared_sim.state),theme+" prepared geometry preserves exact canonical driving")
		var original := NativeTrackVisual.new()
		original.cache_race_world = true
		root.add_child(original)
		original.build(track,BridgePresentation.new(track))
		check(not Worlds.entries.is_empty() and Worlds.entries[-1].key[0] == track.content_hash,theme+" completed world is admitted")
		if not Worlds.entries.is_empty(): all_world_bytes += int(Worlds.entries[-1].bytes)
		var expected: Array = signature(original).slice(1)
		var expected_props: Array[Transform3D] = []
		for prop: Node3D in original.light_instances: expected_props.append(prop.transform)
		var state := VehicleState.new()
		state.loose_tyres = [[40.0,40.0,0.0,0.0,2.0]]
		original.update_tyres(state,track.tyre_origins)
		for prop: Node3D in original.light_instances: prop.position += Vector3(8,0,8)
		var visual := NativeTrackVisual.new()
		visual.cache_race_world = true
		root.add_child(visual)
		visual.build(track,BridgePresentation.new(track))
		check(signature(visual).slice(1) == expected,theme+" restored meshes/materials/lighting/groups and transforms exactly match")
		check(visual.light_instances.size() == original.light_instances.size(),theme+" movable props are rebound to the new scene")
		for index: int in range(visual.light_instances.size()): check(visual.light_instances[index].transform == expected_props[index],theme+" prop starts at authored transform")
		check(visual.tyre_instances != original.tyre_instances and visual.tyre_instances.multimesh != original.tyre_instances.multimesh,theme+" loose tyres own fresh mutable buffers")
		for name: String in original.get_meta_list(): check(visual.get_meta(name) == original.get_meta(name),theme+" metadata "+name)
		var bytes: int = 0
		for value: Dictionary in Worlds.entries: bytes += int(value.bytes)
		check(Worlds.entries.size() <= Worlds.MAX_ENTRIES and bytes <= Worlds.MAX_BYTES,"scenery memory remains bounded")
		original.free()
		visual.free()
	print("PREPARED_WORLD_BUDGET all_five_bytes=",all_world_bytes," retained=",Worlds.entries.size()," budget=",Worlds.MAX_BYTES)
	check(Worlds.entries.size() == 5 if all_world_bytes <= Worlds.MAX_BYTES else Worlds.entries.size() < 5,"five prepared worlds remain together when they fit; larger fields evict within the byte budget")
	var unused := NativeTrackVisual.new()
	check(not Worlds.restore(["changed-visual-version"],unused),"visual revision changes cannot reuse an old world")
	unused.free()
	Worlds.entries.clear()
	Tracks.clear()
	print("PREPARED_RACE_TESTS checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func write(path: String, body: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(body)
	file.close()
