extends SceneTree
## Check actual sleeve meshes against the crate interior through the full flip.
const Station = preload("res://ui/garage_record_station.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var room := Node3D.new()
	root.add_child(room)
	Station.build(room)
	var shelf: Node3D = room.find_child("GarageRecordSleeves",true,false)
	var failures := 0
	var checks := 0
	var count: int = shelf.get_child_count()
	for step: int in range((count-1)*100+1):
		Station.present_browse(shelf,step/100.0)
		for sleeve: Node3D in shelf.get_children():
			for child: Node in sleeve.get_children():
				if not child is MeshInstance3D: continue
				var bounds: AABB = child.mesh.get_aabb()
				for corner: int in range(8):
					var point: Vector3 = sleeve.transform * (child.transform * bounds.get_endpoint(corner))
					checks += 1
					if point.x < 0.239 or point.x > 0.621 or point.y < 0.9525 or absf(point.z) >= 0.194:
						failures += 1
						if failures < 5: print("FAIL ",sleeve.name," step ",step," corner ",point)
	print("Record box clearance: ",checks," checks, ",failures," failures")
	room.free()
	quit(1 if failures else 0)
