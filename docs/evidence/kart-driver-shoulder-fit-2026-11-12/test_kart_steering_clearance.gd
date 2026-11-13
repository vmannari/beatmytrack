extends SceneTree
## Actual morphed hands/sleeves against every real hood and side-pod shell.
const DRIVER: ArrayMesh = preload("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
const OUT: String = "res://../docs/evidence/kart-driver-shoulder-fit-2026-11-12"
var checks: int = 0
var failures: int = 0
var results: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()

func crossing(faces: PackedVector3Array, tree: TriangleMesh, transform: Transform3D, bounds: AABB) -> Vector3:
	var inverse: Transform3D = transform.affine_inverse()
	for triangle: int in range(0,faces.size(),3):
		var a: Vector3 = faces[triangle]
		var b: Vector3 = faces[triangle+1]
		var c: Vector3 = faces[triangle+2]
		if not bounds.intersects(AABB(a,Vector3.ZERO).expand(b).expand(c).grow(0.00001)): continue
		for edge: Array in [[a,b],[b,c],[c,a]]:
			var origin: Vector3 = inverse*edge[0]
			var delta: Vector3 = inverse*edge[1]-origin
			if delta.length_squared() < 1e-14: continue
			var hit: Dictionary = tree.intersect_ray(origin,delta.normalized())
			if not hit.is_empty() and origin.distance_to(hit.position) <= delta.length()+0.000001: return transform*hit.position
	return Vector3(INF,INF,INF)

func pose(input: float) -> ArrayMesh:
	var result := ArrayMesh.new()
	var dummy := MeshInstance3D.new()
	dummy.mesh = DRIVER
	preload("res://vehicle/kart_steering.gd").present(null,dummy,input)
	var total: float = 0
	for shape: int in range(6): total += dummy.get_blend_shape_value(shape)
	for surface: int in range(DRIVER.get_surface_count()):
		var arrays: Array = DRIVER.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var shapes: Array[Array] = DRIVER.surface_get_blend_shape_arrays(surface)
		for index: int in range(vertices.size()):
			vertices[index] *= 1-total
			for shape: int in range(6): vertices[index] += shapes[shape][Mesh.ARRAY_VERTEX][index]*dummy.get_blend_shape_value(shape)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	dummy.free()
	return result

func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var poses: Dictionary = {}
	for input: float in [-1.0,-0.5,0.0,0.5,1.0]: poses[input] = pose(input)
	for simple: bool in [false,true]:
		for category: String in ["hood","body"]:
			for option: Array in VehicleCustomisation.options(category,"kart"):
				var car := CarVisual.new()
				car.vehicle_id = "kart"
				car.simple_model = simple
				car.batch_parts = false
				car.customisation = VehicleCustomisation.defaults()
				car.customisation[category] = option[0]
				root.add_child(car)
				while not car.model_ready: await process_frame
				for shell: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
					var label: String = str(shell.name)
					if not (label.begins_with("NassauFairing") if category == "hood" else label.begins_with("FormedSidePod")): continue
					var transform: Transform3D = car.body.global_transform.affine_inverse()*shell.global_transform
					var tree: TriangleMesh = shell.mesh.generate_triangle_mesh()
					var shell_faces: PackedVector3Array = shell.mesh.get_faces()
					for index: int in range(shell_faces.size()): shell_faces[index] = transform*shell_faces[index]
					for input: float in poses:
						var mesh: ArrayMesh = poses[input]
						var first: Vector3 = crossing(mesh.get_faces(),tree,transform,transform*shell.mesh.get_aabb())
						var second: Vector3 = crossing(shell_faces,mesh.generate_triangle_mesh(),Transform3D.IDENTITY,mesh.get_aabb())
						checks += 1
						if first.is_finite() or second.is_finite(): failures += 1; printerr("STEERING_CLEARANCE_FAIL ",simple," ",category," ",option[0]," input=",input," ",first," ",second)
						results.append({"simple":simple,"category":category,"option":option[0],"input":input,"driver_crossing":str(first),"shell_crossing":str(second)})
				car.free()
	FileAccess.open(OUT+"/steering-clearance.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":results},"\t"))
	print("KART_STEERING_CLEARANCE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
