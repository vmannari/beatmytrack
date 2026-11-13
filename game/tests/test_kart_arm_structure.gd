extends SceneTree
## KAR01/KAR02: actual native shafts, elbow/cuff volume and unchanged controls.
const OUT: String = "res://../docs/evidence/kart-driver-arm-structure-2026-11-12"
const PATH: String = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
var checks: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("ARM_STRUCTURE_FAIL ",label)

func ring(points: PackedVector3Array, offset: int, row: int) -> Vector3:
	var sum := Vector3.ZERO
	for index: int in range(16): sum += points[offset+row*17+index]
	return sum/16

func deviation(point: Vector3, a: Vector3, b: Vector3) -> float:
	return (point-a).cross(b-a).length()/a.distance_to(b)

func run() -> void:
	var before: ArrayMesh = load(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var after: ArrayMesh = load(PATH)
	var mesh: ArrayMesh = before if "--before" in OS.get_cmdline_user_args() else after
	check(after.get_faces().size() == before.get_faces().size(),"same driver triangle budget")
	check(after.get_blend_shape_count() == before.get_blend_shape_count(),"same six steering targets")
	var static_count: int = int(mesh.get_meta("kart_suit_static_vertices"))
	for surface: int in range(mesh.get_surface_count()):
		var material: Material = mesh.surface_get_material(surface)
		var arrays: Array = mesh.surface_get_arrays(surface)
		var old_arrays: Array = before.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if material.resource_name != "RT_DriverSuit":
			check(arrays == old_arrays,"unchanged helmet/gloves/trim/hardware "+material.resource_name)
			check(mesh.surface_get_blend_shape_arrays(surface) == before.surface_get_blend_shape_arrays(surface),"unchanged non-sleeve steering targets "+material.resource_name)
			continue
		var stable: bool = true
		for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:
			for index: int in range(static_count): stable = stable and arrays[attribute][index] == old_arrays[attribute][index]
		check(stable,"torso, legs, soles and centre seam remain byte-exact decoded attributes")
		var poses: Array[PackedVector3Array] = [points]
		for shape: Array in mesh.surface_get_blend_shape_arrays(surface): poses.append(shape[Mesh.ARRAY_VERTEX])
		for pose: int in range(poses.size()):
			for side: int in range(2):
				var vertices: PackedVector3Array = poses[pose]
				var offset: int = static_count+side*21*17
				var upper_a: Vector3 = ring(vertices,offset,1)
				var upper_b: Vector3 = ring(vertices,offset,8)
				var lower_a: Vector3 = ring(vertices,offset,12)
				var lower_b: Vector3 = ring(vertices,offset,19)
				var upper_bow: float = 0
				var lower_bow: float = 0
				for row: int in range(2,8): upper_bow = maxf(upper_bow,deviation(ring(vertices,offset,row),upper_a,upper_b))
				for row: int in range(13,19): lower_bow = maxf(lower_bow,deviation(ring(vertices,offset,row),lower_a,lower_b))
				check(upper_bow < 0.001 and lower_bow < 0.001,"upper arm and forearm each retain a straight anatomical shaft")
				var angle: float = rad_to_deg((upper_b-upper_a).angle_to(lower_b-lower_a))
				check(angle > 20 and angle < 120,"bend is concentrated at a believable elbow angle")
				var radii: Array[float] = []
				for row: int in [3,10,13,19]:
					var center: Vector3 = ring(vertices,offset,row)
					var sum: float = 0
					for index: int in range(16): sum += center.distance_to(vertices[offset+row*17+index])
					radii.append(sum/16)
				check(radii[3] < radii[2]*0.8 and radii[1] < radii[0]*0.9,"wrist tapers and elbow has a distinct fitted section")
				measurements.append({"pose":pose,"side":side,"upper_bow_mm":upper_bow*1000,"forearm_bow_mm":lower_bow*1000,"elbow_degrees":angle,"section_radii":radii})
	FileAccess.open(OUT+("/structure-before.json" if "--before" in OS.get_cmdline_user_args() else "/structure-after.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	print("KART_ARM_STRUCTURE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
