extends SceneTree
const _NATIVE_TRACK = preload("res://track/native_track.gd")
const COACH = preload("res://vehicle/electric_coachwork.gd")
const OUTPUT: String = "res://../docs/evidence/electric-model-fixes-2026-10-25"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func key(point: Vector3) -> String:
	return "%d:%d:%d" % [roundi(point.x*10000),roundi(point.y*10000),roundi(point.z*10000)]

func faces(car: CarVisual, region: String, side: float = 0) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		var name_value: String = str(mesh.name)
		var selected: bool = false
		if region == "rear":
			for prefix: String in ["TailSkin","PlatePocket","RearOpticalPocket","PlateInsert","RearLightBar","RearLightReturn"]:
				selected = selected or name_value.begins_with(prefix)
		else:
			selected = (name_value.begins_with("SculptedSide") and mesh.mesh.get_aabb().get_center().x*side>0) or (str(mesh.get_parent().name).contains("RecessedDoorGap") and mesh.position.x*side>0)
		if not selected: continue
		var transform_value: Transform3D = car.body.global_transform.affine_inverse()*mesh.global_transform
		for point: Vector3 in mesh.mesh.get_faces(): result.append(transform_value*point)
	return result

func hit(triangles: PackedVector3Array, origin: Vector3, direction: Vector3) -> Dictionary:
	var distance: float = INF
	var closest := Vector3.ZERO
	for index: int in range(0,triangles.size(),3):
		var point: Variant = Geometry3D.ray_intersects_triangle(origin,direction,triangles[index],triangles[index+1],triangles[index+2])
		if point != null and origin.distance_squared_to(point) < distance:
			distance = origin.distance_squared_to(point)
			closest = point
	return {"hit":is_finite(distance),"point":closest}

func boundary_normals(car: CarVisual) -> Dictionary:
	var side_normals: Dictionary = {}
	for mesh: MeshInstance3D in car.body.find_children("SculptedSide*","MeshInstance3D",true,false):
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
			var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			if absf(point.z+2.13)<0.0001 or absf(point.z-2.09)<0.0001:
				side_normals[key(point)] = arrays[Mesh.ARRAY_NORMAL][index]
	var matched: int = 0
	var total: int = 0
	var angle: float = 0
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if not (str(mesh.name).begins_with("FormedFront") or str(mesh.name).begins_with("TailSkin")): continue
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
			var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			if absf(point.z+2.13)>0.0001 and absf(point.z-2.09)>0.0001: continue
			total += 1
			if side_normals.has(key(point)):
				matched += 1
				angle = maxf(angle,rad_to_deg((arrays[Mesh.ARRAY_NORMAL][index] as Vector3).angle_to(side_normals[key(point)])))
	return {"matched":matched,"total":total,"maximum_angle":angle}

func run() -> void:
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var label: String = "simple" if simple else "full"
		var boundary: Dictionary = boundary_normals(car)
		metrics[label+"_boundaries"] = boundary
		check(boundary.total > 100 and boundary.matched == boundary.total,"every baked end/side edge vertex shares a position, "+label)
		check(boundary.maximum_angle < 2,"baked end/side normals agree within two degrees, "+label)
		var rear: PackedVector3Array = faces(car,"rear")
		var samples: Array = [[Vector2(0,0.59),0.052],[Vector2(0.24,0.59),0.060],[Vector2(-0.24,0.59),0.060],[Vector2(0.30,0.59),0.0],[Vector2(0,0.849),0.026],[Vector2(0.80,0.849),0.044],[Vector2(0.84,0.849),0.0]]
		for sample: Array in samples:
			var point: Vector2 = sample[0]
			var actual: Dictionary = hit(rear,Vector3(point.x,point.y,3),Vector3.FORWARD)
			var depth: float = COACH.rear_z(point.x,point.y)-actual.point.z
			metrics[label+"_rear_"+str(point)] = depth
			check(actual.hit and absf(depth-float(sample[1])) < 0.004,"actual mesh ray reaches the inset rear surface, "+label+" "+str(point))
		for side: float in [-1.0,1.0]:
			var skin: PackedVector3Array = faces(car,"side",side)
			for z: float in [0.27,0.40,0.65,0.90]:
				var actual: Dictionary = hit(skin,Vector3(side*2,0.43,z),Vector3(-side,0,0))
				var depth: float = COACH.skin_width(0.43,z)-actual.point.x*side
				metrics[label+"_door_"+str(side)+"/"+str(z)] = depth
				check(actual.hit and depth > 0.0025 and depth < 0.006,"rear lower door gap is continuously recessed through the formerly missing span, "+label+" "+str(side)+"/"+str(z))
		car.free()
	print("ELECTRIC_SURFACE_METRICS ",JSON.stringify(metrics))
	var report := FileAccess.open(OUTPUT+"/surface-finish.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_SURFACE_FINISH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
