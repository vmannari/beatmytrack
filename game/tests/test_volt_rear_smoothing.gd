extends SceneTree
## VRS01: one continuous rear-deck skin; VRS02: closed full/simple tail join.
const B = preload("res://vehicle/electric_reference_body.gd")
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", description)

func heights(faces: PackedVector3Array, x: float, z: float) -> Array[float]:
	var result: Array[float] = []
	for i: int in range(0, faces.size(), 3):
		var a := Vector2(faces[i].x, faces[i].z)
		var b := Vector2(faces[i+1].x, faces[i+1].z)
		var c := Vector2(faces[i+2].x, faces[i+2].z)
		var p := Vector2(x,z)
		var d: float = (b-a).cross(c-a)
		if absf(d) < 0.00000001: continue
		var u: float = (p-a).cross(c-a)/d
		var v: float = (b-a).cross(p-a)/d
		if u >= -0.000001 and v >= -0.000001 and u+v <= 1.000001:
			var y: float = faces[i].y*(1.0-u-v)+faces[i+1].y*u+faces[i+2].y*v
			var duplicate := false
			for prior: float in result:
				if absf(y-prior)<0.000001: duplicate=true
			if not duplicate: result.append(y)
	return result

func run() -> void:
	if "--control" in OS.get_cmdline_user_args():
		var script: GDScript = load("res://vehicle/electric_reference_body.gd")
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/volt-rear-smoothing-2026-11-08/task-start/game/vehicle/electric_reference_body.gd")
		assert(script.reload()==OK)
	preload("res://ui/garage_car_cache.gd").enabled=false
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	M.use_baked="--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var deck: MeshInstance3D=car.body.get_node("ReferenceRearDeck")
		var rear: MeshInstance3D=car.body.get_node("ReferenceRear")
		var lip: MeshInstance3D=car.body.get_node_or_null("SportDeckLip")
		check(lip==null,"trailing lip belongs to the deck skin simple="+str(simple))
		var skin: PackedVector3Array=deck.mesh.get_faces()
		if lip!=null: skin.append_array(lip.mesh.get_faces())
		# Vertical probes through the actual triangle buffers reject the former
		# second sheet, including the shallow strip where the grids intersected.
		for column: int in range(9):
			for row: int in range(3):
				var p: Vector3=B.deck_point(0.14+column*0.09,0.971+row*0.009)
				check(heights(skin,p.x,p.z).size()==1,"single deck layer %s/%s simple=%s" % [column,row,simple])
		var arrays: Array=deck.mesh.surface_get_arrays(0)
		var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		for i: int in range(positions.size()):
			check(positions[i].is_finite() and normals[i].is_finite() and absf(normals[i].length()-1.0)<0.0001,"finite deck position/unit normal")
			if is_equal_approx(uv[i].y,1.0):
				var p: Vector3=B.cap_point(true,uv[i].x,1.0)
				check(positions[i].distance_to(p)<0.000002,"deck closes to tail at actual edge station")
		var rear_arrays: Array=rear.mesh.surface_get_arrays(0)
		var rear_uv: PackedVector2Array=rear_arrays[Mesh.ARRAY_TEX_UV]
		var rear_positions: PackedVector3Array=rear_arrays[Mesh.ARRAY_VERTEX]
		var rear_normals: PackedVector3Array=rear_arrays[Mesh.ARRAY_NORMAL]
		var maximum_normal_encoding_error := 0.0
		for i: int in range(rear_uv.size()):
			if is_equal_approx(rear_uv[i].y,1.0):
				check(rear_positions[i].distance_to(B.deck_point(rear_uv[i].x,1.0))<0.000002,"tail closes to deck at actual edge station")
				var found := false
				for j: int in range(uv.size()):
					if uv[j].distance_to(Vector2(rear_uv[i].x,1.0))<0.000001:
						found = rear_normals[i]==normals[j]
						break
				check(found,"exact shared deck/tail normals in GPU buffers")
				maximum_normal_encoding_error=maxf(maximum_normal_encoding_error,rear_normals[i].distance_to(M.normal_at(B.deck_point,rear_uv[i].x,1.0,Vector3.UP)))
		print("Rear edge packed-normal error simple=",simple,": ",maximum_normal_encoding_error)
		var rear_faces: PackedVector3Array=rear.mesh.get_faces()
		for label: String in ["ReferenceRearLampHousing","ReferenceRearLightbar"]:
			var lamp: MeshInstance3D=car.body.get_node(label)
			var lamp_faces: PackedVector3Array=lamp.mesh.get_faces()
			for i: int in range(0,lamp_faces.size(),21):
				var p: Vector3=(lamp_faces[i]+lamp_faces[i+1]+lamp_faces[i+2])/3.0
				var underlying: Array[float]=heights(rear_faces,p.x,p.z)
				check(not underlying.is_empty(),"lamp seats over actual tail triangles")
				if not underlying.is_empty():
					check(p.y>underlying.max()+0.0001,"lamp skin clears actual tail triangles "+label+" simple="+str(simple))
		for i: int in range(61):
			var u: float=float(i)/60.0
			var p: Vector3=B.deck_point(u,1.0)
			var mirror: Vector3=B.deck_point(1.0-u,1.0)
			check((Vector3(-p.x,p.y,p.z)-mirror).length()<0.000002,"symmetric formed lip")
		car.free()
	print("VOLT_REAR_SMOOTHING: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
