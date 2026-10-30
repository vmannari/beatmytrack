extends SceneTree
const COACH = preload("res://vehicle/electric_coachwork.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COACH.ASSET_ROOT+"/manifest.json"))
	for part: Dictionary in manifest.meshes:
		if not str(part.part).begins_with("SculptedSide"): continue
		var skin: Mesh = load(COACH.ASSET_ROOT.path_join(part.file))
		var side: float = -1.0 if str(part.part).contains("-1") else 1.0
		var query := TriangleMesh.new()
		var faces: PackedVector3Array = skin.get_faces()
		for index: int in range(faces.size()): faces[index] *= 100
		assert(query.create_from_faces(faces))
		var misses: Array = []
		for front: bool in [true,false]:
			var path: Array[Vector2] = COACH.door_outline(front)
			for edge: int in range(path.size()):
				var a: Vector2 = path[edge]
				var b: Vector2 = path[(edge+1)%path.size()]
				var perpendicular := Vector2((b-a).y,-(b-a).x).normalized()
				for step: int in range(11):
					for margin: float in [-0.001,0.0,0.001]:
						var point: Vector2 = a.lerp(b,step/10.0)+perpendicular*margin
						var outside: Dictionary = query.intersect_ray(Vector3(side*2,point.y,point.x)*100,Vector3(-side,0,0))
						if outside.is_empty():
							var inside: Dictionary = query.intersect_ray(Vector3(0,point.y,point.x)*100,Vector3(side,0,0))
							misses.append({"point":str(point),"inside_hit":not inside.is_empty()})
		print("PANEL_RAY_STUDY ",part.part," ",JSON.stringify({"misses":misses.size(),"examples":misses.slice(0,5)}))
	quit()
