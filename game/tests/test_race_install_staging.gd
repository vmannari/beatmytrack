extends SceneTree
const WORLDS = preload("res://track/prepared_world_cache.gd")
var checks: int = 0
var failures: int = 0
class SlicedVisual extends NativeTrackVisual:
	func _yield_build() -> bool:
		if not _build_is_current(): return false
		await get_tree().process_frame
		return _build_is_current()
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func write(visual: NativeTrackVisual, track: NativeTrack) -> void: await WORLDS.remember_cooperative(["cancel-write"],visual,track)
func read(visual: NativeTrackVisual) -> void: await WORLDS.restore_cooperative(["complete"],visual)
func populate(visual: NativeTrackVisual) -> void:
	for index: int in range(3):
		var mesh := MeshInstance3D.new(); mesh.mesh = BoxMesh.new(); visual.add_child(mesh)
func staging(visual: NativeTrackVisual, restoring: bool) -> Node:
	for frame: int in range(20):
		await process_frame
		var lease: Node = visual.get_node_or_null("RaceInstallStaging")
		if lease != null and (visual.get_child_count()>1 if restoring else lease.staged.get_child_count()>0): return lease
	return null
func run() -> void:
	WORLDS.entries.clear()
	var track := NativeTrack.new(); track.cells.resize(1); track.metadata = {"theme":"pine"}
	var visual := SlicedVisual.new(); populate(visual); root.add_child(visual)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	write(visual,track)
	var lease: Node = await staging(visual,false)
	check(lease != null,"publication yields with a partially populated snapshot")
	if lease == null: quit(1); return
	var holder: WeakRef = weakref(lease.staged); var lease_ref: WeakRef = weakref(lease)
	visual.free()
	for frame: int in range(4): await process_frame
	check(holder.get_ref() == null and lease_ref.get_ref() == null,"owner removal frees publication snapshot and lease")
	check(WORLDS.entries.is_empty(),"canceled snapshot never publishes")
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == before,"canceled publication leaves no orphan nodes")
	var source := NativeTrackVisual.new(); populate(source); root.add_child(source)
	WORLDS.remember(["complete"],source,track)
	visual = SlicedVisual.new(); root.add_child(visual)
	read(visual)
	lease = await staging(visual,true)
	check(lease != null,"restoration yields after transferring only part of the scene")
	if lease == null: source.free(); quit(1); return
	holder = weakref(lease.staged); lease_ref = weakref(lease)
	visual.free()
	for frame: int in range(4): await process_frame
	check(holder.get_ref() == null and lease_ref.get_ref() == null,"owner removal frees remaining restore holder and lease")
	check(WORLDS.entries.size() == 1 and source.get_child_count() == 3,"canceled restore retains the original complete cache and source")
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == before,"canceled restoration leaves no orphan nodes")
	source.free(); WORLDS.entries.clear()
	print("RACE_INSTALL_STAGING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
