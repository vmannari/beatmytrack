extends SceneTree
## Relief installation must retire safely when the scene is replaced mid-frame.
var checks: int = 0
var failures: int = 0
var returned: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ",message)

func apply_then_finish(relief: RefCounted, node: Node3D) -> void:
	await relief._apply_node(node,Transform3D.IDENTITY,true)
	returned += 1

func victim() -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.set_meta("desert_road_relief","desert-road-relief-1")
	var result := MeshInstance3D.new()
	result.mesh = mesh
	return result

func run() -> void:
	var script: GDScript = preload("res://track/desert_road_relief.gd")
	if "--before" in OS.get_cmdline_user_args():
		script = GDScript.new()
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/editor-review-fixes-2026-10-29/performance/desert_road_relief-before.gd.txt")
		if script.reload() != OK:
			print("FAIL: baseline source does not compile")
			quit(1)
			return
	var relief: RefCounted = script.new()
	var holder := Node3D.new()
	root.add_child(holder)
	var removed: MeshInstance3D = victim()
	holder.add_child(removed)
	apply_then_finish(relief,removed)
	removed.free()
	await process_frame
	await process_frame
	check(returned == 1,"freed mesh resumes without dereferencing a dead node")
	var parent := Node3D.new()
	parent.add_child(victim())
	parent.add_child(victim())
	holder.add_child(parent)
	apply_then_finish(relief,parent)
	parent.free()
	await process_frame
	await process_frame
	check(returned == 2,"freed ancestor cancels remaining child traversal")
	var detached := Node3D.new()
	detached.add_child(victim())
	detached.add_child(victim())
	holder.add_child(detached)
	apply_then_finish(relief,detached)
	holder.remove_child(detached)
	await process_frame
	await process_frame
	check(returned == 3,"detached ancestor cancels remaining child traversal")
	detached.free()
	var siblings := Node3D.new()
	siblings.add_child(victim())
	var removed_sibling: MeshInstance3D = victim()
	siblings.add_child(removed_sibling)
	holder.add_child(siblings)
	apply_then_finish(relief,siblings)
	removed_sibling.free()
	for frame: int in range(4): await process_frame
	check(returned == 4,"a retired sibling is skipped while the live parent completes")
	var live := Node3D.new()
	live.add_child(victim())
	live.add_child(victim())
	holder.add_child(live)
	apply_then_finish(relief,live)
	for frame: int in range(6): await process_frame
	check(returned == 5,"live ancestor completes normal traversal")
	check(live.get_child_count() == 2,"normal installation preserves both children")
	holder.free()
	print("DESERT_RELIEF_RETIREMENT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
