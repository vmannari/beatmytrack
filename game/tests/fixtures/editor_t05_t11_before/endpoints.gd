extends RefCounted
static func prepare_endpoints(pieces: Array) -> Dictionary:
	var poses: Array[Dictionary] = []
	var buckets: Dictionary = {}
	for index: int in range(pieces.size()):
		for endpoint: int in range(2):
			var pose: Dictionary = RoadPieces._pose(pieces[index],endpoint)
			var bucket := Vector2i(floori(pose.position.x/RoadPieces.JOIN_DISTANCE),floori(pose.position.y/RoadPieces.JOIN_DISTANCE))
			if not buckets.has(bucket): buckets[bucket] = []
			buckets[bucket].append(poses.size())
			poses.append(pose)
	var partners: Array = []
	for id: int in range(poses.size()):
		var position: Vector2 = poses[id].position
		var bucket := Vector2i(floori(position.x/RoadPieces.JOIN_DISTANCE),floori(position.y/RoadPieces.JOIN_DISTANCE))
		var candidates: Array = []
		for x: int in range(-1,2):
			for y: int in range(-1,2): candidates.append_array(buckets.get(bucket+Vector2i(x,y),[]))
		candidates.sort()
		var matches: Array = []
		for other: int in candidates:
			if other/2 == id/2: continue
			if position.distance_to(poses[other].position) <= RoadPieces.JOIN_DISTANCE: matches.append([other/2,other%2])
		partners.append(matches)
	return {"poses":poses,"partners":partners}
