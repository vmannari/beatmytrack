extends SceneTree

const PREPARATION = preload("res://race/world_render_preparation.gd")
var checks: int = 0
var failures: int = 0

class Stage extends Node3D:
	var camera: Camera3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	stage.camera = Camera3D.new()
	stage.add_child(stage.camera)
	var preparation = PREPARATION.new()
	# Keep the single-program retry/order contract, alongside the new bounded
	# multi-program and cross-view native fixture.
	preparation.programs_per_draw = 1
	stage.add_child(preparation)
	PREPARATION.warmed.clear()
	var groups: Array = [[],[],[]]
	# Interleave three render programs. Two need more than one bounded batch
	# when the draw reports failure; their last members must be shown first.
	for index: int in range(30):
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.layers = 1 << (index % 3)
		mesh.extra_cull_margin = float(index) / 10.0
		stage.add_child(mesh)
		groups[index % 3].append(mesh)
	preparation.hold(stage)
	var visits: Array = []
	var draw: Callable = func() -> bool:
		var visible: Array = []
		for group: Array in groups:
			var indices: Array = []
			for i: int in range(group.size()):
				if group[i].visible: indices.append(i)
			visible.append(indices)
		visits.append(visible)
		await process_frame
		return visits.size() != 1
	check(await preparation.prepare(draw,func() -> bool: return true),"preparation completes")
	check(visits.size() == 4,"failed first draw retries and other programs each draw once")
	check(visits[0] == [[2,3,4,5,6,7,8,9],[],[]],"first program draws last eight in reverse-scan order")
	check(visits[1] == [[0,1,2,3,4,5,6,7,8,9],[],[]],"failed draw retries remaining geometry")
	check(visits[2] == [[0,1,2,3,4,5,6,7,8,9],[2,3,4,5,6,7,8,9],[]],"first-seen program order survives interleaving")
	check(preparation.pending.is_empty() and PREPARATION.warmed.size() == 3,"all buckets complete and successful programs warm")
	for index: int in range(30):
		var node: MeshInstance3D = groups[index % 3][index / 3]
		check(node.visible and is_equal_approx(node.extra_cull_margin,float(index) / 10.0),"visibility and cull margin restored")
	PREPARATION.warmed.clear()
	preparation.hold(stage)
	var calls: Array = []
	var cancel_draw: Callable = func() -> bool:
		calls.append(true)
		await process_frame
		return true
	check(not await preparation.prepare(cancel_draw,func() -> bool: return calls.is_empty()),"cancellation after draw stops preparation")
	check(not preparation.pending.is_empty(),"unsubmitted nodes remain held for teardown")
	preparation.queue_free()
	await process_frame
	for group: Array in groups:
		check(group.all(func(node: MeshInstance3D) -> bool: return node.visible),"teardown reveals cancelled program")
	stage.queue_free()
	await process_frame
	print("WORLD_RENDER_BUCKETS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
