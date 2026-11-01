extends "res://tests/test_volt_reference_redesign.gd"
## VWF01-VWF03: real mesh stance, projecting fenders and closed wheelhouses.
const B = preload("res://vehicle/electric_reference_body.gd")
var output := "res://../docs/evidence/volt-fenders-2026-10-31/measurements.json"

func tire_in(wheel: Node3D) -> MeshInstance3D:
	for mesh: MeshInstance3D in wheel.find_children("*","MeshInstance3D",true,false):
		var material: ShaderMaterial = mesh.material_override as ShaderMaterial
		if material != null and material.shader.resource_path.ends_with("compact_tire.gdshader"): return mesh
	return null

func intersects(meshes: Array[MeshInstance3D],start: Vector3,finish: Vector3) -> bool:
	for mesh: MeshInstance3D in meshes:
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(start,finish,mesh.transform*faces[i],mesh.transform*faces[i+1],mesh.transform*faces[i+2]) != null: return true
	return false

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--baseline-body="):
			var script: GDScript = load("res://vehicle/electric_reference_body.gd")
			script.source_code = FileAccess.get_file_as_string(arg.trim_prefix("--baseline-body="))
			assert(script.reload()==OK)
	if "--control" in OS.get_cmdline_user_args():
		for file: String in ["electric_reference_body.gd","electric_reference_details.gd"]:
			var script: GDScript = load("res://vehicle/"+file)
			script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/volt-fenders-2026-10-31/task-base/game/vehicle/"+file)
			assert(script.reload()==OK)
	M.use_baked = "--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	var report: Dictionary = {"models":[],"control":"--control" in OS.get_cmdline_user_args(),"prepared":M.use_baked}
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var label := " simple="+str(simple)
		var count := 0
		var finite := true
		for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			count += mesh.mesh.get_faces().size()/3
			for surface: int in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]: finite = finite and p.is_finite()
				if arrays[Mesh.ARRAY_NORMAL] != null:
					for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: finite = finite and n.is_finite() and absf(n.length_squared()-1.0)<0.01
		check(finite,"finite geometry and unit normals"+label)
		check(count <= (45000 if simple else 120000),"established triangle budget"+label)
		var model: Dictionary = {"simple":simple,"triangles":count,"wheelhouses":[],"wheel_clearance":[]}
		for side: float in [-1.0,1.0]:
			for axle: float in [-B.AXLE,B.AXLE]:
				var suffix: String = (str(side)+str(axle)).replace(".","_")
				var arch: MeshInstance3D = car.body.get_node("ReferenceArch"+suffix)
				var at_lip: Vector3 = point_at_uv(arch,Vector2(0.5,1.0))
				var flare: float = absf(at_lip.x)-B.side_width(at_lip.z,at_lip.y)
				# Owner correction: a subtle electric-car shoulder replaces the
				# former 55 mm flare. Keep a formed edge without a prominent rim.
				check(flare>0.006 and flare<0.018,"fender blends subtly into body "+suffix+label)
				var packet: Array[MeshInstance3D] = [arch]
				for prefix: String in ["ReferenceWheelWell","VoltFenderReturn","VoltWheelhouseBack","VoltWheelhouseEnd"]:
					for mesh: MeshInstance3D in car.body.find_children(prefix+suffix+"*","MeshInstance3D",false,false): packet.append(mesh)
				var back: MeshInstance3D = car.body.get_node_or_null("VoltWheelhouseBack"+suffix)
				check(back != null,"opaque inboard wheelhouse wall "+suffix+label)
				if back != null:
					var normals: PackedVector3Array = back.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
					var facing := true
					for n: Vector3 in normals: facing = facing and side*n.x>0.99
					check(facing,"inner wall faces visible wheel cavity "+suffix+label)
				var blocked := 0
				var rays := 0
				for dz: float in [-0.34,-0.17,0.0,0.17,0.34]:
					var roof: float = 0.24+0.545*sqrt(1.0-pow(dz/0.43,2))
					for y: float in [0.32,lerpf(0.32,roof,0.5),roof-0.006]:
						rays += 1
						if intersects(packet,Vector3(side*1.5,y,axle+dz),Vector3(0,y,axle+dz)): blocked += 1
				check(blocked==rays,"no view across car through wheel bay "+suffix+" "+str(blocked)+"/"+str(rays)+label)
				if back != null:
					var roof_mesh: MeshInstance3D = car.body.get_node("ReferenceWheelWell"+suffix)
					check(edge_gap(edge(roof_mesh,1,1.0),edge(back,1,1.0))<0.00001,"liner roof closes to back wall "+suffix+label)
				model.wheelhouses.append({"side":side,"axle":axle,"flare":flare,"blocked_rays":blocked,"rays":rays})
		var wheels: Array[Node3D] = []
		for rotor: Node3D in car.rolling_wheels: wheels.append(rotor.get_parent() as Node3D)
		for wheel: Node3D in wheels:
			var front: bool = wheel.position.z<0
			var side: float = signf(wheel.position.x)
			check(absf(absf(wheel.position.x)-(0.791 if front else 0.841))<0.00001,"front inset and retained rear stance "+str(wheel.name)+label)
			var tire: MeshInstance3D = tire_in(wheel)
			check(tire != null,"actual tire mesh "+str(wheel.name)+label)
			if tire == null: continue
			var spin: Node3D = wheel.get_node("WheelSpin")
			var vertices: PackedVector3Array = tire.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var min_inner := INF
			var max_roof := 0.0
			for steer: float in [-0.4,-0.2,0.0,0.2,0.4] if front else [0.0]:
				wheel.rotation.y = steer
				for roll: float in [0.0,PI/5.0,2.0*PI/5.0]:
					spin.rotation.x = roll
					for point: Vector3 in vertices:
						var p: Vector3 = car.to_local(tire.to_global(point))
						min_inner = minf(min_inner,side*p.x-(0.48 if front else 0.57))
						if p.y>=0.24:
							max_roof = maxf(max_roof,pow((p.z-(-B.AXLE if front else B.AXLE))/0.421,2)+pow((p.y-0.24)/0.536,2))
			check(min_inner>0.025,"tire clears inboard wall through full steering and roll "+str(wheel.name)+label)
			check(max_roof<0.97,"tire clears curved liner through full steering and roll "+str(wheel.name)+label)
			model.wheel_clearance.append({"wheel":str(wheel.name),"inboard_gap":min_inner,"liner_ellipse_max":max_roof})
			wheel.rotation.y = 0
			spin.rotation.x = 0
		# These meshes must remain byte-for-byte the accepted sports silhouette.
		for name_value: String in ["ReferenceHood","ReferenceCanopyGlass","ReferencePanoramicRoof","ReferenceRearScreen"]:
			var node: MeshInstance3D = car.body.get_node(name_value)
			var key: String = name_value+("_simple" if simple else "")
			var previous: ArrayMesh = load("res://assets/vehicles/electric_sport_fastback_v1/"+key.sha256_text().left(24)+".res")
			check(var_to_bytes(node.mesh.surface_get_arrays(0))==var_to_bytes(previous.surface_get_arrays(0)),"accepted hood and cabin retained "+name_value+label)
		var tray: Array[MeshInstance3D] = []
		var tray_floor := INF
		for mesh: MeshInstance3D in car.body.find_children("VoltUndertray*","MeshInstance3D",false,false):
			tray.append(mesh)
			tray_floor = minf(tray_floor,mesh.mesh.get_aabb().position.y)
		check(is_finite(tray_floor) and tray_floor>=0.252,"undertray seats inside lower bumper rather than floating below it"+label)
		for z: float in [-2.0,-1.0,0.0,1.0,2.0]:
			check(intersects(tray,Vector3(0,0.4,z),Vector3(0,0.1,z)) and intersects(tray,Vector3(1.2,0.26,z),Vector3(0,0.26,z)),"undertray closes chassis vertically and laterally z="+str(z)+label)
		report.models.append(model)
		car.free()
	report.merge({"checks":checks,"failures":failures})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("VOLT_FENDERS: ",checks," checks, ",failures," failures; ",JSON.stringify(report.models))
	quit(1 if failures else 0)
