extends SceneTree
## Measure door seams, glazing boundaries and the short intervening joins.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func uv_point(node: MeshInstance3D, wanted: Vector2) -> Vector3:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var nearest := INF
	var point := Vector3.INF
	for i: int in verts.size():
		var distance: float = uvs[i].distance_squared_to(wanted)
		if distance < nearest:
			nearest = distance
			point = node.transform * verts[i]
	return point

func ribbon_center(node: MeshInstance3D, u: float) -> Vector3:
	return (uv_point(node,Vector2(u,0.0))+uv_point(node,Vector2(u,0.5)))*0.5

func seam_at_height(node: MeshInstance3D, y: float) -> Vector3:
	var previous: Vector3 = ribbon_center(node,0.0)
	for i: int in range(1,33):
		var current: Vector3 = ribbon_center(node,float(i)/32.0)
		if current.y <= y and previous.y >= y:
			var delta: float = previous.y-current.y
			return previous.lerp(current,(previous.y-y)/delta if delta>0.000001 else 0.0)
		previous = current
	return Vector3.INF

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	M.use_baked = "--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for side: String in ["-1_0","1_0"]:
			for index: int in range(3):
				var suffix := " simple="+str(simple)+" side="+side+" seam="+str(index)
				var seam: MeshInstance3D = car.body.get_node_or_null("ReferenceDoorSeam"+side+str(index))
				var pillar: MeshInstance3D = car.body.get_node_or_null(["ReferenceAPillar","ReferenceBPillar","ReferenceCPillar"][index]+side)
				var link: MeshInstance3D = car.body.get_node_or_null("ReferenceWindowDoorJoin"+side+str(index))
				check(seam != null and pillar != null,"door seam and corresponding pillar exist"+suffix)
				if seam == null or pillar == null: continue
				var door_top: Vector3 = ribbon_center(seam,0.0)
				var pillar_foot: Vector3 = uv_point(pillar,Vector2(1.0,0.0)) if index == 0 else (uv_point(pillar,Vector2(0.0,0.0))+uv_point(pillar,Vector2(1.0,0.0)))*0.5
				var longitudinal_gap: float = absf(door_top.z-pillar_foot.z)
				print("DOOR_WINDOW_ALIGNMENT",suffix," z_gap=",longitudinal_gap," door=",door_top," window=",pillar_foot)
				check(longitudinal_gap < 0.004,"seam meets its window boundary"+suffix)
				check(link != null,"belt join exists"+suffix)
				if link != null:
					print("DOOR_WINDOW_JOIN",suffix," lower=",ribbon_center(link,0.0)," upper=",ribbon_center(link,1.0))
					check(ribbon_center(link,0.0).distance_to(door_top)<0.006,"belt join meets the door"+suffix)
					check(ribbon_center(link,1.0).distance_to(pillar_foot)<0.006,"belt join meets the pillar"+suffix)
			var handles: Array[Node] = car.body.find_children("RefHandleOutline"+side+"*","MeshInstance3D",false,false)
			check(handles.size()==2,"two door handles present side="+side)
			for node: Node in handles:
				var handle: MeshInstance3D = node as MeshInstance3D
				var box: AABB = handle.mesh.get_aabb()
				var center: Vector3 = handle.transform*box.get_center()
				var trailing: int = 2 if center.z>0.0 else 1
				var seam: MeshInstance3D = car.body.get_node("ReferenceDoorSeam"+side+str(trailing))
				var at_height: Vector3 = seam_at_height(seam,center.y)
				var gap: float = at_height.z-(box.position.z+box.size.z)
				print("DOOR_WINDOW_HANDLE side=",side," simple=",simple," center=",center," gap=",gap)
				check(is_finite(gap) and gap>0.025 and gap<0.15,"handle stays near its door's trailing edge")
		car.free()
	print("VOLT_DOOR_WINDOW_ALIGNMENT: ",checks," checks, ",failures," failures prepared=",M.use_baked)
	quit(1 if failures else 0)
