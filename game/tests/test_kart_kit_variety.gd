extends SceneTree
## Actual mesh depth samples quantify visible shape differences and tyre clearance.
const G = preload("res://vehicle/kart_geometry.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-variety-2026-10-29/shape"
var measurements: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func part_meshes(car: CarVisual, category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for frame: Node3D in car.kit_frames[category]:
		for mesh: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
			result.append({"node":mesh,"rays":mesh.mesh.generate_triangle_mesh(),"to_mesh":mesh.global_transform.affine_inverse()})
	return result

func depth_map(car: CarVisual, category: String, meshes: Array[Dictionary]) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for row: int in range(20):
		for col: int in range(32):
			var u: float = (col+0.5)/32
			var v: float = (row+0.5)/20
			var origin: Vector3
			var direction: Vector3
			match category:
				"hood": origin = Vector3(lerpf(-0.78,0.78,u),2,lerpf(-1.50,-0.32,v)); direction = Vector3.DOWN
				"body": origin = Vector3(lerpf(-0.75,0.75,u),2,lerpf(-0.62,0.52,v)); direction = Vector3.DOWN
				"aero": origin = Vector3(lerpf(-0.80,0.80,u),lerpf(0.06,0.42,v),2); direction = Vector3.FORWARD
				"rims": origin = Vector3(2,lerpf(0.05,0.39,v),lerpf(-1.06,-0.70,u)); direction = Vector3.LEFT
			origin = car.global_transform*origin
			direction = (car.global_basis*direction).normalized()
			var nearest: float = INF
			for mesh: Dictionary in meshes:
				var hit: Dictionary = mesh.rays.intersect_ray(mesh.to_mesh*origin,mesh.to_mesh.basis*direction)
				if not hit.is_empty(): nearest = minf(nearest,origin.distance_to(mesh.node.global_transform*hit.position))
			samples.append(-1 if is_inf(nearest) else nearest/HandlingConfig.BODY_SCALE)
	return samples

func difference(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var union: int = 0
	var different: int = 0
	for index: int in range(a.size()):
		if a[index]<0 and b[index]<0: continue
		union += 1
		if (a[index]<0)!=(b[index]<0) or absf(a[index]-b[index])>0.004: different += 1
	return float(different)/maxi(1,union)

func clearance(car: CarVisual, meshes: Array[Dictionary]) -> float:
	var minimum: float = INF
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for part: Dictionary in meshes:
		var mesh: MeshInstance3D = part.node
		var transform: Transform3D = inverse*mesh.global_transform
		for surface: int in range(mesh.mesh.get_surface_count()):
			for raw: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = transform*raw
				for center: Vector3 in car.wheel_rest_positions:
					for steering: float in ([-0.60,-0.30,0.0,0.30,0.60] if center.z<0 else [0.0]):
						var local: Vector3 = Basis(Vector3.UP,steering).transposed()*(point-center)
						var outside: float = maxf(absf(local.x)-0.137,Vector2(local.y,local.z).length()-0.22)
						minimum = minf(minimum,outside)
	return minimum

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.editable_kits = true
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for category: String in VehicleCustomisation.CATEGORIES:
			var previous: Dictionary = {}
			for option: Array in VehicleCustomisation.options(category,"kart"):
				car.graphics.restore_originals()
				var value: Dictionary = VehicleCustomisation.defaults()
				value[category] = option[0]
				car.change_kit_parts(value)
				var meshes: Array[Dictionary] = part_meshes(car,category)
				var current: PackedFloat32Array = depth_map(car,category,meshes)
				var distances: Dictionary = {}
				for old: String in previous:
					var amount: float = difference(current,previous[old])
					distances[old] = amount
					check(amount>=0.08,"visible shape difference >=8% "+category+"/"+str(option[0])+" vs "+old+" simple="+str(simple))
				previous[str(option[0])] = current
				var gap: float = INF if category=="rims" else clearance(car,meshes)
				if category!="rims": check(gap>=-0.001,"kit clears complete tyre steering sweep "+category+"/"+str(option[0]))
				var valid: bool = true
				for part: Dictionary in meshes:
					for surface: int in range(part.node.mesh.get_surface_count()):
						for normal: Vector3 in part.node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]: valid = valid and normal.is_finite() and normal.length_squared()>0.5
				check(valid,"finite usable kit normals")
				measurements.append({"simple":simple,"category":category,"option":option[0],"depth_difference":distances,"tyre_gap":null if is_inf(gap) else gap})
		car.free()
		await process_frame
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("KART_KIT_VARIETY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
