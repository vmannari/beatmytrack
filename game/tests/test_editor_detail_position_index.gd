extends SceneTree
## Compare overview member lookup to the original exhaustive search.
const Detail = preload("res://editor/editor_detail.gd")

func _initialize() -> void:
	var objects: Array = []
	var poses: Array = []
	# Include repeated coordinates, negative cells, and near-cell boundaries.
	for i: int in range(4093):
		objects.append({"position":[(i%64)*0.037-1.184,(i/64)*0.041-1.312]})
	for i: int in range(1024):
		var p: Array = objects[(i*13)%objects.size()].position
		poses.append(Transform3D(Basis.IDENTITY,Vector3(p[0]+0.0049,0,-p[1]+0.0049)))
	objects.append({"position":[-0.0001,0.01]})
	objects.append({"position":[-0.0001,0.01]})
	objects.append({"position":[0.01,0.01]})
	poses.append(Transform3D(Basis.IDENTITY,Vector3(0.0,0,-0.01)))
	poses.append(poses[0])
	var exhaustive_us: Array[int] = []
	var indexed_us: Array[int] = []
	var expected: Array[int] = []
	var actual: Array[int] = []
	var matches: bool = true
	# Alternate execution order; index construction is included in each run.
	for iteration: int in range(3):
		if iteration%2 == 0:
			var before: int = Time.get_ticks_usec()
			expected = _exhaustive(objects,poses)
			exhaustive_us.append(Time.get_ticks_usec()-before)
			before = Time.get_ticks_usec()
			actual = Detail._pose_indices(objects,poses,Detail._index_positions(objects))
			indexed_us.append(Time.get_ticks_usec()-before)
		else:
			var before: int = Time.get_ticks_usec()
			actual = Detail._pose_indices(objects,poses,Detail._index_positions(objects))
			indexed_us.append(Time.get_ticks_usec()-before)
			before = Time.get_ticks_usec()
			expected = _exhaustive(objects,poses)
			exhaustive_us.append(Time.get_ticks_usec()-before)
		matches = matches and actual == expected
	# Test distant unmatched poses and both sides of cell/radius boundaries.
	var edge_objects: Array = [{"position":[-0.01001,0.0]},{"position":[-0.00999,0.0]},{"position":[0.0,0.0]},{"position":[0.00999,0.0]},{"position":[0.01001,0.0]},{"position":[0.0,0.0]}]
	var edge_poses: Array = [Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3(-0.01,0,0)),Transform3D(Basis.IDENTITY,Vector3(50,0,50)),Transform3D.IDENTITY]
	matches = matches and Detail._pose_indices(edge_objects,edge_poses,Detail._index_positions(edge_objects)) == _exhaustive(edge_objects,edge_poses)
	matches = matches and Detail._pose_indices([],edge_poses,{}).is_empty()
	var rng := RandomNumberGenerator.new()
	rng.seed = 828391
	var random_objects: Array = []
	var random_poses: Array = []
	for i: int in range(300): random_objects.append({"position":[rng.randf_range(-0.15,0.15),rng.randf_range(-0.15,0.15)]})
	for i: int in range(200):
		var p: Array = random_objects[rng.randi_range(0,random_objects.size()-1)].position
		random_poses.append(Transform3D(Basis.IDENTITY,Vector3(p[0]+rng.randf_range(-0.011,0.011),0,-p[1]+rng.randf_range(-0.011,0.011))))
	matches = matches and Detail._pose_indices(random_objects,random_poses,Detail._index_positions(random_objects)) == _exhaustive(random_objects,random_poses)
	print("EDITOR_DETAIL_POSITION_INDEX: matches=%s exhaustive_us=%s indexed_us=%s objects=%d poses=%d" % [matches,exhaustive_us,indexed_us,objects.size(),poses.size()])
	quit(0 if matches else 1)

func _exhaustive(objects: Array, poses: Array) -> Array[int]:
	var result: Array[int] = []
	for pose: Transform3D in poses:
		for index: int in range(objects.size()):
			var position := Vector2(objects[index].position[0],objects[index].position[1])
			if position.distance_squared_to(Vector2(pose.origin.x,-pose.origin.z)) < 0.0001 and not result.has(index): result.append(index)
	return result
