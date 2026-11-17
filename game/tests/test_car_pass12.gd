extends "res://tests/test_car_model_revert.gd"
const CP_OUT: String="res://../docs/evidence/car-pass12-2026-11-16"
const WORK: String="res://../build/car-pass12-2026-11-16"
const Source=preload("res://tests/support/car_pass12_source.gd")
const Detail=preload("res://vehicle/car_detail_reduction.gd")
var plan: Dictionary={}
var observations: Array=[]
var current_mode: String=""
var observed: Array=[]
var frame_savings: Dictionary={}
func fan_triangles(node: Node3D) -> int:
	var total: int=0
	for part: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		if part.is_visible_in_tree() and part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:total+=part.mesh.get_faces().size()/3
	return total
func observe(car: CarVisual,holders: Variant) -> void:
	if current_mode=="full":return
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders:
			var prefix: String=str(car.get_path_to(holder))+"/"
			for path: String in frame_savings.keys():
				if path.begins_with(prefix):frame_savings.erase(path)
			parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or str(part.name)=="TomkartDriver":continue
		var path: String=str(car.get_path_to(part))
		var original: String=part.mesh.get_meta("car_pass12_source","")
		if plan.parts.has(original):frame_savings[path]=int(plan.parts[original].before)-int(plan.parts[original].after)
		else:observed.append(car.vehicle_id+"_"+Detail.mesh_key(part.mesh))
	if car.vehicle_id=="electric" and holders==null:
		var hood: MeshInstance3D=car.find_child("ReferenceHood",true,false)
		var line: MeshInstance3D=car.find_child("SportBonnetShutLine",true,false)
		check(hood!=null and line!=null,"actual Volt hood/line available")
		if hood!=null and line!=null:
			var tree: TriangleMesh=hood.mesh.generate_triangle_mesh()
			for p: Vector3 in line.mesh.get_faces():
				var hit: Dictionary=tree.intersect_ray(p+Vector3.UP*.1,Vector3.DOWN)
				check(not hit.is_empty(),"Volt bonnet line retains complete backing")
				if not hit.is_empty():check(p.y-hit.position.y>=.00035 and p.y-hit.position.y<=.0015,"Volt bonnet line remains flush/exposed")
func _initialize() -> void:verify.call_deferred()
func verify() -> void:
	plan=JSON.parse_string(FileAccess.get_file_as_string(CP_OUT.path_join("selected-plan.json")))
	observations=JSON.parse_string(FileAccess.get_file_as_string(CP_OUT.path_join("survey.json")))
	var baseline: Array=JSON.parse_string(FileAccess.get_file_as_string(CP_OUT.path_join("before.json"))).rows
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared;preload("res://ui/garage_car_cache.gd").enabled=false
	Source.observer=observe
	var measured: Array=[]
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		for mode: String in ["stock","fitted","full"]:
			current_mode=mode
			var before: Dictionary={}
			for row: Dictionary in baseline:
				if row.vehicle==id and row.mode==mode:before=row
			var expected: int=int(before.inventory.triangles)
			observed=[];frame_savings={}
			if prepared:
				for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(CP_OUT.path_join("source-models.json"))).rows:
					if row.vehicle==id and row.mode==mode:expected=int(row.expected_triangles)
			var car: CarVisual=CarVisual.new() if prepared else Source.new()
			car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var hits: int=Base.hits;var kit_hits: int=Kits.hits;root.add_child(car)
			while not car.model_ready:await process_frame
			if not prepared and mode!="full":
				if id=="hovercraft" and mode=="fitted":
					# Fan replacement predates kit-frame ownership. Its callback has no
					# holders, so measure the actual final fan assembly independently.
					for path: String in frame_savings.keys():
						if "/FanRotor/" in path:frame_savings.erase(path)
					var old: Node3D=load(WORK.path_join(id+"-fitted-before.scn")).instantiate();root.add_child(old)
					var old_fan: Node3D=old.find_child("FanRotor",true,false)
					var new_fan: Node3D=car.find_child("FanRotor",true,false)
					check(old_fan!=null and new_fan!=null,"actual old/new Hover fan assembly")
					frame_savings["final fan assembly"]=fan_triangles(old_fan)-fan_triangles(new_fan);old.free()
				for amount: int in frame_savings.values():expected-=amount
				if id=="kart":expected-=int(plan.driver.before)-int(plan.driver.after)
				var original: Array=[]
				for row: Dictionary in observations:
					if row.vehicle==id and row.mode==mode and not plan.parts.has(row.key) and row.name!="TomkartDriver":original.append(row.key)
				original.sort();observed.sort();check(original==observed,"every unselected observed source GPU member exact "+id+mode)
			var stats: Dictionary=inventory(car,false)
			if not prepared and mode=="fitted" and id=="hovercraft":FileAccess.open(CP_OUT.path_join("hover-savings.json"),FileAccess.WRITE).store_string(JSON.stringify(frame_savings,"  "))
			check(stats.triangles==expected,"exact measured reduction "+id+mode+" expected "+str(expected)+" actual "+str(stats.triangles))
			if mode=="stock":
				for row: Dictionary in plan.rows:
					if row.vehicle==id:check(int(stats.triangles)==int(row.after) and float(row.reduction_percent)>=10.0 and float(row.reduction_percent)<=15.0,"independent declared stock target "+id)
			if prepared:
				check(Base.hits==hits+1,"actual prepared base "+id+mode)
				if mode=="fitted":check(Kits.hits==kit_hits+4,"actual four fitted modules "+id)
			elif mode=="full":
				var old: Node3D=load(WORK.path_join(id+"-full-before.scn")).instantiate();root.add_child(old)
				check(signature(old)==signature(car),"full master GPU/articulation remains exact "+id);old.free()
			measured.append({"vehicle":id,"mode":mode,"inventory":stats,"expected_triangles":expected})
			print("CP2_MODEL ",id," ",mode," ",stats.triangles);car.free();await process_frame
	FileAccess.open(CP_OUT.path_join("prepared-models.json" if prepared else "source-models.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":measured},"  "))
	print("CP2_MODELS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
