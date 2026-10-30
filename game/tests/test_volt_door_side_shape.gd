extends SceneTree
## Actual side meshes: check the doors do not collapse inward and stay fitted.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func triangles(node: MeshInstance3D) -> Array[Dictionary]:
	var points: PackedVector3Array = node.mesh.get_faces()
	var result: Array[Dictionary] = []
	for i: int in range(0,points.size(),3):
		var a: Vector3 = node.transform*points[i]
		var b: Vector3 = node.transform*points[i+1]
		var c: Vector3 = node.transform*points[i+2]
		result.append({"a":a,"b":b,"c":c,"min_y":minf(a.y,minf(b.y,c.y)),"max_y":maxf(a.y,maxf(b.y,c.y)),"min_z":minf(a.z,minf(b.z,c.z)),"max_z":maxf(a.z,maxf(b.z,c.z))})
	return result

func side_x(faces: Array[Dictionary],side: float,z: float,y: float) -> float:
	var start := Vector3(side*1.7,y,z)
	var finish := Vector3(0,y,z)
	var best := -INF
	for face: Dictionary in faces:
		if y < face.min_y-0.00001 or y > face.max_y+0.00001 or z < face.min_z-0.00001 or z > face.max_z+0.00001:
			continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,finish,face.a,face.b,face.c)
		if hit != null: best = maxf(best,side*(hit as Vector3).x)
	return best

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-source="):
			var source_path: String = argument.trim_prefix("--baseline-source=")
			var source: String = FileAccess.get_file_as_string(source_path)
			assert(not source.is_empty())
			var body_script: GDScript = load("res://vehicle/electric_reference_body.gd")
			body_script.source_code = source
			assert(body_script.reload() == OK)
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
		var label: String = "simple="+str(simple)
		var side_faces: Dictionary = {}
		for side: float in [-1.0,1.0]:
			var mesh: MeshInstance3D = car.body.get_node_or_null("ReferenceSide"+str(side).replace(".","_"))
			check(mesh != null,"side surface exists "+str(side)+" "+label)
			if mesh == null: continue
			var faces: Array[Dictionary] = triangles(mesh)
			side_faces[side] = faces
			var biggest_inward := 0.0
			for z: float in [-0.55,0.0,0.55]:
				var lo: float = side_x(faces,side,z,0.36)
				var hi: float = side_x(faces,side,z,0.88)
				check(is_finite(lo) and is_finite(hi),"full door height intersects side mesh at "+str(z)+" "+label)
				if not is_finite(lo) or not is_finite(hi): continue
				for y: float in [0.45,0.55,0.65,0.75]:
					var x: float = side_x(faces,side,z,y)
					check(is_finite(x),"middle door is continuously covered at "+str(Vector2(z,y))+" "+label)
					if is_finite(x):
						var chord: float = lerpf(lo,hi,(y-0.36)/0.52)
						biggest_inward = maxf(biggest_inward,chord-x)
			print("VOLT_DOOR_PROFILE ",label," side=",side," max_inward=",biggest_inward)
			check(biggest_inward < 0.025,"door has no deep concave pinch "+str(side)+" "+label)
			var handles: Array[Node] = car.body.find_children("RefHandleOutline"+str(side).replace(".","_")+"*","MeshInstance3D",false,false)
			check(handles.size()==2,"two door handles present "+str(side)+" "+label)
			for handle: MeshInstance3D in handles:
				var verts: PackedVector3Array = handle.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var max_offset := 0.0
				var hits := 0
				for i: int in range(0,verts.size(),maxi(1,verts.size()/12)):
					var p: Vector3 = handle.transform*verts[i]
					var surface: float = side_x(faces,side,p.z,p.y)
					if not is_finite(surface): continue
					max_offset = maxf(max_offset,absf(side*p.x-surface))
					hits += 1
				check(hits >= 8 and max_offset < 0.008,"handle remains fitted to door "+str(handle.name)+" offset="+str(max_offset)+" "+label)
		var arches: Array[Node] = car.body.find_children("ReferenceArch*","MeshInstance3D",false,false)
		check(arches.size()==4,"all four wheel arches exist "+label)
		for arch: MeshInstance3D in arches:
			var arrays: Array = arch.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var min_radius := INF
			var mid: Vector3 = arch.transform*arch.mesh.get_aabb().get_center()
			var axle: float = -1.398 if mid.z < 0.0 else 1.398
			var side: float = -1.0 if mid.x < 0.0 else 1.0
			for i: int in range(verts.size()):
				if uvs[i].y > 0.0001: continue
				var p: Vector3 = arch.transform*verts[i]
				min_radius = minf(min_radius,Vector2(p.z-axle,p.y-0.37).length())
			check(min_radius > 0.39,"wheel arch clears rolling tyre "+str(arch.name)+" radius="+str(min_radius)+" "+label)
			var max_gap := 0.0
			var hit_count := 0
			for target: float in [0.16,0.30,0.50,0.70,0.84]:
				var nearest := INF
				var p := Vector3.ZERO
				for i: int in range(verts.size()):
					if uvs[i].y > 0.0001: continue
					var d: float = absf(uvs[i].x-target)
					if d < nearest:
						nearest = d
						p = arch.transform*verts[i]
				var surface: float = side_x(side_faces[side],side,p.z,p.y+0.002)
				if is_finite(surface):
					max_gap = maxf(max_gap,absf(side*p.x-surface))
					hit_count += 1
			check(hit_count >= 4 and max_gap < 0.012,"arch and side surfaces remain fitted "+str(arch.name)+" hits="+str(hit_count)+" gap="+str(max_gap)+" "+label)
		var saved: Dictionary = VehicleLivery.defaults("electric")
		saved.colors.body = "638d86"
		car.apply_livery(saved)
		check(car.paint_materials.body.albedo_color.is_equal_approx(Color("638d86")),"saved body colour remains usable "+label)
		car.free()
	print("VOLT_DOOR_SIDE_SHAPE: ",checks," checks, ",failures," failures; prepared=",M.use_baked)
	quit(1 if failures else 0)
