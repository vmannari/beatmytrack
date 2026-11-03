extends "res://tests/test_volt_reference_redesign.gd"
## VSR01-VSR04: inspect actual full/simple buffers, not only authoring functions.
## The old closed-lower-bumper fixture remains intact; the new cooling aperture
## is verified for a recessed back and connected returns instead.
var output := "res://../docs/evidence/volt-sport-redesign-2026-10-31/measurements.json"

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if "--control" in OS.get_cmdline_user_args():
		for file: String in ["electric_car_model.gd","electric_reference_body.gd","electric_reference_cabin.gd","electric_reference_details.gd"]:
			var script: GDScript = load("res://vehicle/"+file)
			script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/volt-sport-redesign-2026-10-31/task-base/game/vehicle/"+file)
			assert(script.reload() == OK)
	M.use_baked = "--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	var control: bool = "--control" in OS.get_cmdline_user_args()
	var report: Dictionary = {"models":[],"prepared":M.use_baked,"control":control,"sources":{}}
	for file: String in ["electric_car_model.gd","electric_reference_mesh.gd","electric_reference_body.gd","electric_reference_cabin.gd","electric_reference_details.gd"]:
		var directory := "res://../docs/evidence/volt-sport-redesign-2026-10-31/task-base/game/vehicle/" if control and file!="electric_reference_mesh.gd" else "res://vehicle/"
		report.sources[file] = FileAccess.get_sha256(directory+file)
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		car.livery = VehicleLivery.defaults("electric")
		root.add_child(car)
		while not car.model_ready: await process_frame
		var label := " simple="+str(simple)
		var hood: MeshInstance3D = car.body.get_node("ReferenceHood")
		var screen: MeshInstance3D = car.body.get_node("ReferenceCanopyGlass")
		var foot: Vector3 = point_at_uv(screen,Vector2(0.5,0.0))
		var nose: Vector3 = point_at_uv(hood,Vector2(0.5,0.0))
		var cowl: Vector3 = point_at_uv(hood,Vector2(0.5,1.0))
		var hood_angle: float = rad_to_deg(atan2(cowl.y-nose.y,cowl.z-nose.z))
		var roof_max := 0.0
		var triangles := 0
		var valid := true
		for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			triangles += mesh.mesh.get_faces().size()/3
			for surface: int in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]: valid = valid and p.is_finite()
				if arrays[Mesh.ARRAY_NORMAL] != null:
					for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: valid = valid and n.is_finite() and absf(n.length_squared()-1.0)<0.01
			if mesh.name in ["ReferenceCanopyGlass","ReferencePanoramicRoof","ReferenceRearScreen"]:
				roof_max = maxf(roof_max,mesh.mesh.get_aabb().end.y)
		check(valid,"all positions and unit normals are finite"+label)
		check(triangles <= (45000 if simple else 120000),"retained triangle budget"+label)
		check(foot.y < 0.86 and foot.y > 0.81,"windscreen base is substantially lowered"+label)
		check(roof_max < 1.20 and roof_max > 1.12,"low sports roof silhouette"+label)
		check(hood_angle > 4.0 and hood_angle < 8.0,"shallow nose-to-cowl angle"+label)
		check(foot.distance_to(cowl)<0.003,"windscreen remains fitted to new cowl"+label)
		var monotonic := true
		var previous := nose
		for i: int in range(1,25):
			var p: Vector3 = point_at_uv(hood,Vector2(0.5,float(i)/24.0))
			monotonic = monotonic and p.y >= previous.y-0.0001 and p.y <= cowl.y+0.001
			previous = p
		check(monotonic,"hood centre has one rise without a rear hump"+label)
		var back: MeshInstance3D = car.body.get_node_or_null("SportCoolingBack")
		check(back != null,"lower bumper has a real recessed cooling back"+label)
		if back != null:
			var depth: float = point_at_uv(back,Vector2(0.5,0.5)).z-preload("res://vehicle/electric_reference_body.gd").cap_point(false,0.5,0.175).z
			check(depth > 0.035 and depth < 0.042,"cooling back has physical depth"+label)
			for index: int in range(4):
				var wall: MeshInstance3D = car.body.get_node_or_null("SportCoolingReturn"+str(index))
				check(wall != null,"cooling aperture return "+str(index)+label)
		for side: float in [-1.0,1.0]:
			var suffix: String = str(side).replace(".","_")
			var curtain: MeshInstance3D = car.body.get_node_or_null("SportCurtain"+suffix+"Back")
			check(curtain != null,"formed outer bumper recess "+str(side)+label)
			if curtain != null:
				for index: int in range(4):
					var wall: MeshInstance3D = car.body.get_node("SportCurtain"+suffix+"Return"+str(index))
					var axis: int = 1 if index%2==0 else 0
					var boundary: float = 0.0 if index==0 or index==3 else 1.0
					check(edge_gap(edge(wall,1,1.0),edge(curtain,axis,boundary))<0.002,"outer recess back meets return "+str(side)+"/"+str(index)+label)
		var front_paint: Array[MeshInstance3D] = []
		for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",false,false):
			if mesh.name=="ReferenceFrontUpper" or str(mesh.name).begins_with("SportBumper"): front_paint.append(mesh)
		for x: float in [-0.45,0.0,0.45]:
			for y: float in [0.48,0.50,0.62]:
				var covered := false
				for mesh: MeshInstance3D in front_paint:
					if intersects_front(mesh,x,y): covered = true;break
				check(covered,"upper electric nose remains solid "+str(Vector2(x,y))+label)
		for side: String in ["-1_0","1_0"]:
			var flank: MeshInstance3D = car.body.get_node("ReferenceSide"+side)
			var belt: MeshInstance3D = car.body.get_node("ReferenceWindowBottom"+side)
			check(edge_gap(edge(belt,1,0.0),edge(flank,1,1.0))<0.002,"lower cabin joins flank "+side+label)
			var strip_valid := true
			for column: int in range(161):
				var low: Vector3 = point_at_uv(flank,Vector2(float(column)/160,0))
				var high: Vector3 = point_at_uv(flank,Vector2(float(column)/160,1))
				strip_valid = strip_valid and high.y-low.y>0.006
			check(strip_valid,"front fender remains above wheel aperture "+side+label)
		var deck: MeshInstance3D = car.body.get_node("ReferenceRearDeck")
		var rear: MeshInstance3D = car.body.get_node("ReferenceRear")
		var rear_glass: MeshInstance3D = car.body.get_node("ReferenceRearScreen")
		var rear_foot: MeshInstance3D = car.body.get_node("ReferenceRearGlassFoot")
		check(edge_gap(edge(rear_glass,1,1.0),edge(rear_foot,1,0.0))<0.001,"rear glass meets its painted foot"+label)
		check(edge_gap(edge(rear_foot,1,1.0),edge(deck,1,0.0))<0.0005,"painted glass foot meets deck"+label)
		check(edge_gap(edge(deck,1,1.0),edge(rear,1,1.0))<0.0005,"deck stays joined to tail"+label)
		for part: String in ["SportBonnetShutLine","SportDeckLip","SportRearValance"]:
			check(car.body.get_node_or_null(part)!=null,"finished body detail "+part+label)
		check(car.body.find_children("SportProjector*","MeshInstance3D",false,false).size()==6,"six fitted projector optics"+label)
		check(car.find_children("SportMachinedSpoke*","MeshInstance3D",true,false).size()==20,"twenty machined wheel edges"+label)
		check(car.front_wheels.size()==2 and car.rolling_wheels.size()==4,"steering and rolling pivots retained"+label)
		for axle: Node3D in car.front_wheels:
			# Owner follow-up: front visual wheels inset 50 mm per side.
			check(absf(absf(axle.position.x)-0.791)<0.00001 and absf(axle.position.y-0.37)<0.00001 and absf(axle.position.z+1.398)<0.00001,"front wheel inset retains original height and axle"+label)
		var custom: Dictionary = VehicleLivery.defaults("electric")
		custom.colors.body = "203b50"
		custom.pattern = "apex_twin"
		car.apply_livery(custom)
		check(car.paint_materials.body.albedo_color.is_equal_approx(Color("203b50")),"saved paint colour reaches body"+label)
		var finish: ShaderMaterial = hood.get_active_material(0) as ShaderMaterial
		check(finish != null and finish.get_shader_parameter("pattern_enabled"),"saved pattern reaches new hood"+label)
		car.set_night_headlights(true)
		check(car.headlights.visible and car.headlights.find_child("ReferenceNightLightbar",true,false)!=null,"night lighting uses current nose"+label)
		report.models.append({"simple":simple,"triangles":triangles,"cowl_y":foot.y,"roof_y":roof_max,"hood_angle_degrees":hood_angle,"wheelbase_world":2.796*HandlingConfig.BODY_SCALE})
		car.free()
	if M.use_baked:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(M.ASSET_ROOT.path_join("manifest.json")))
		for file: String in report.sources:
			check(manifest.sources.get(file,"")==report.sources[file],"current prepared source "+file)
		var count: int = M.meshes.size()
		var prepared: Dictionary = M.meshes.duplicate()
		M.meshes.clear()
		M.use_baked = false
		for simple: bool in [false,true]:
			var car := CarVisual.new()
			car.vehicle_id = "electric"
			car.simple_model = simple
			car.batch_parts = false
			car.cache_rest_pose = false
			root.add_child(car)
			while not car.model_ready: await process_frame
			car.set_night_headlights(true)
			car.free()
		var exact: bool = M.meshes.size()==count
		for key: String in M.meshes:
			if not prepared.has(key):
				exact = false
				continue
			var a: ArrayMesh = M.meshes[key]
			var b: ArrayMesh = prepared[key]
			exact = exact and b.resource_path.begins_with(M.ASSET_ROOT)
			for surface: int in a.get_surface_count():
				exact = exact and var_to_bytes(a.surface_get_arrays(surface))==var_to_bytes(b.surface_get_arrays(surface))
		check(exact,"every prepared surface array equals same-process procedural geometry")
		report["exact_prepared_meshes"] = count
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	report.merge({"checks":checks,"failures":failures})
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("VOLT_SPORT_REDESIGN: ",checks," checks, ",failures," failures; ",JSON.stringify(report.models))
	quit(1 if failures else 0)
