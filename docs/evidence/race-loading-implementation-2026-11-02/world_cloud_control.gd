extends SceneTree
const Cloud = preload("res://backend/cloud_tracks.gd")
const Tracks = preload("res://backend/prepared_track_cache.gd")
const Worlds = preload("res://../docs/evidence/race-loading-implementation-2026-11-02/before/game/track/prepared_world_cache.gd")
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
	print("UNCHANGED_CLOUD_CONTROL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func write(path: String, body: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(body)
	file.close()
