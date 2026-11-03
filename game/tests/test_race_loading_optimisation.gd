extends SceneTree
const WORLDS = preload("res://track/prepared_world_cache.gd")
const MEMORY = preload("res://editor/editor_memory.gd")
const EFFECTS = preload("res://vehicle/effect_render_preparation.gd")
const POOL = preload("res://vehicle/effect_preparation_pool.gd")
const SELECTED = preload("res://race/selected_track_preparation.gd")
var checks: int = 0
var failures: int = 0

class Session extends RefCounted:
	var primed: Dictionary = {}

class MemoryOwner extends Node:
	var canvas: Node
	var editor_preview_thread: Thread
	var editor_world: Node
	var editor_compiled_cache: Array = []
	var editor_raster_cache: Dictionary = {}
	var history: Array = []
	var redo_history: Array = []
	var editor_gesture_history: Array = []
	var editor_gesture_redo: Array = []
	var editor_session := Session.new()
	const EDITOR_COMPILED_BUDGET: int = 48*1024*1024

class PressureVisual extends NativeTrackVisual:
	var checkpoints: int = 0
	func _yield_build() -> bool:
		checkpoints += 1
		if checkpoints == 2: preload("res://track/prepared_world_cache.gd").trim_cache()
		return true

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL ",label)

func triangle() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func cache_accounting() -> void:
	WORLDS.entries.clear()
	NativeTrackVisual.trim_editor_cache()
	var mesh: ArrayMesh = triangle()
	var visual := NativeTrackVisual.new()
	root.add_child(visual)
	var part := MeshInstance3D.new(); part.mesh = mesh; visual.add_child(part)
	var track := NativeTrack.new()
	track.metadata = {"theme":"pine"}
	WORLDS.remember(["fixture"],visual,track)
	var roads: Array = [{"meshes":[{"mesh":mesh},{"mesh":mesh}]}]
	check(WORLDS.shared_road_bytes(roads) == 288,"identical road buffer counted once despite multiple references")
	check(WORLDS.shared_road_bytes([{"meshes":[{"mesh":triangle()}]}]) == 0,"equal arrays in a distinct resource are not shared")
	var restored := NativeTrackVisual.new(); root.add_child(restored)
	check(WORLDS.restore(["fixture"],restored),"accounted world restores")
	check(restored.get_child(0).mesh == mesh,"accounted buffer is actually shared by the cached scene")
	check(restored.get_child(0) != part,"scene nodes remain independent")
	var owner := MemoryOwner.new(); root.add_child(owner)
	var pool := POOL.new(); pool.name = EFFECTS.POOL_NAME; owner.add_child(pool)
	for index: int in range(4):
		var particles := GPUParticles3D.new()
		particles.set_meta("preparation_key",str(index))
		pool.measure(particles); pool.put(particles,true)
	NativeTrackVisual._road_mesh_cache = [{"meshes":[{"mesh":mesh}],"bytes":288,"geometry_key":"fixture"}]
	preload("res://editor/road_preparation.gd").account_gpu(NativeTrackVisual._road_mesh_cache)
	var before: Dictionary = MEMORY.retained(owner)
	check(before.shared_road_bytes == 288,"App residency subtracts exactly the shared mesh cost")
	WORLDS.entries[0].bytes += MEMORY.RETAINED_BUDGET-int(before.retained_bytes)+100000
	check(MEMORY.retained(owner).retained_bytes > MEMORY.RETAINED_BUDGET,"budget fixture actually requires arbitration")
	var manager := MEMORY.new()
	manager.tick(owner)
	check(WORLDS.entries.size() == 1,"idle proxy eviction preserves useful completed scenery")
	check(pool.entries.size() < 4 and pool.retaining,"ordinary budget trim releases proxies without pressure suppression")
	check(MEMORY.retained(owner).retained_bytes <= MEMORY.RETAINED_BUDGET,"shared retention stays inside unchanged total budget")
	manager.pressure_requested = true; manager.next_sample = 0
	manager.tick(owner)
	check(WORLDS.entries.is_empty() and pool.bytes == 0 and not pool.retaining,"real pressure clears worlds/proxies and suppresses new leases")
	check(WORLDS.shared_road_bytes(roads) == 0,"evicted worlds cannot contribute phantom sharing")
	owner.free(); restored.free(); visual.free()
	NativeTrackVisual.trim_editor_cache()
	var pressured := PressureVisual.new(); root.add_child(pressured)
	part = MeshInstance3D.new(); part.mesh = mesh; pressured.add_child(part)
	await WORLDS.remember_cooperative(["pressure"],pressured,track)
	check(WORLDS.entries.is_empty(),"pressure during cooperative snapshot cannot republish optional scenery")
	check(pressured.get_child_count() == 1,"cancelled snapshot staging is released without removing active geometry")
	pressured.free()

func selected_cpu() -> void:
	var folder := "user://selected-cpu-"+TrackLibrary.unique_id()
	preload("res://track/road_mesh_disk_cache.gd").directory = folder.path_join("roads")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/spline_circuit.json"))
	var expected: NativeTrack = TrackCompiler.compile(document)
	var session := TrackSession.new(); session._configure(expected)
	var track: NativeTrack = TrackCompiler.compile(document)
	check(track._race_gates.is_empty(),"selected CPU fixture starts with cold checkpoint layout")
	var result: Dictionary = SELECTED.run(func() -> bool: return false,track,{}, {})
	check(result.get("track") == track,"selected preparation retains exact track identity")
	check(track._race_gates == expected._race_gates,"early gate preparation is byte-for-byte equal to the original layout")
	check(track._race_gates.get("rules_key","") == RaceRules.KEY,"early layout uses current race rules")
	check(not result.has("bridge"),"optional selected preparation retains no extra presenter/track owner")
	preload("res://track/road_mesh_disk_cache.gd").discard_arrays(result.get("receipt",{}))
	check(SELECTED.run(func() -> bool: return true,track,{},{}).is_empty(),"cancelled selected job publishes no packet")

func run() -> void:
	await cache_accounting()
	selected_cpu()
	print("RACE_LOADING_OPTIMISATION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
