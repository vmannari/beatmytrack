extends SceneTree
## Alternating same-process comparison of the original and current barrel sync.
## Times the unchanged, 32-source presentation path; no rendering or physics claim.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://track/night_prop_effects.gd"
	var source := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
	var shared := "\t# All sources share the same parent; its inverse is identical for this pass.\n\tvar world_to_local: Transform3D=(get_parent() as Node3D).global_transform.affine_inverse()\n"
	var new_pose := "var pose: Transform3D=world_to_local*node.global_transform"
	var old_pose := "var pose: Transform3D=(get_parent() as Node3D).global_transform.affine_inverse()*node.global_transform"
	if source.count(shared) != 1 or source.count(new_pose) != 1:
		push_error("Benchmark reference reconstruction no longer applies")
		quit(1)
		return
	var baseline := GDScript.new()
	baseline.source_code = source.replace("class_name NightPropEffects\n", "").replace(shared, "").replace(new_pose, old_pose)
	if baseline.reload() != OK:
		push_error("Could not compile original presentation path")
		quit(1)
		return
	var parent := Node3D.new()
	root.add_child(parent)
	parent.transform = Transform3D(Basis(Vector3.UP, 0.37), Vector3(8, 2, -3))
	var original: Node = baseline.new()
	var current := NightPropEffects.new()
	parent.add_child(original)
	parent.add_child(current)
	var nodes: Array = []
	var state := VehicleState.new()
	for i: int in range(32):
		var node := Node3D.new()
		node.position = Vector3(i * 2, 0, 0)
		node.set_meta("burning_barrel_scale", 1.0)
		parent.add_child(node)
		nodes.append(node)
		var row: Array = []
		row.resize(BurningBarrel.ROW_SIZE)
		row.fill(0.0)
		state.light_props.append(row)
		var entry := {"index":i}
		original.barrel_sources.append(entry)
		current.barrel_sources.append(entry)
		var pose: Transform3D = parent.global_transform.affine_inverse() * node.global_transform
		original.barrel_poses[i] = [pose, row.slice(10)]
		current.barrel_poses[i] = [pose, row.slice(10)]
	for i: int in range(300):
		original.sync_barrels(nodes, state)
		current.sync_barrels(nodes, state)
	var before: Array = []
	var after: Array = []
	for stage: int in range(8):
		var order: Array = [original, current] if stage % 2 == 0 else [current, original]
		for target: Node in order:
			var start := Time.get_ticks_usec()
			for i: int in range(1000): target.sync_barrels(nodes, state)
			var elapsed := float(Time.get_ticks_usec()-start)/1000.0
			if target == original: before.append(elapsed)
			else: after.append(elapsed)
	print("BARREL_SYNC_US before=", before, " after=", after)
	parent.queue_free()
	quit()
