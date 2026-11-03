extends "res://tests/test_volt_reference_redesign.gd"
## RGC01-03: measure the actual visible full/simple backlight and panel joins.
const BASE := "res://../docs/evidence/volt-curved-rear-window-2026-10-31/task-base/game/vehicle/"
var output := "res://../docs/evidence/volt-curved-rear-window-2026-10-31/curve-measurements.json"

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	var control: bool = "--control" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if control:
		# Reload cabin first: the revised cabin refers to the new shared foot.
		for file: String in ["electric_reference_cabin.gd","electric_reference_body.gd"]:
			var source: GDScript = load("res://vehicle/"+file)
			source.source_code = FileAccess.get_file_as_string(BASE+file)
			assert(source.reload()==OK)
	M.use_baked = "--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	var report: Dictionary = {"control":control,"prepared":M.use_baked,"models":[],"sources":{}}
	for file: String in ["electric_reference_body.gd","electric_reference_cabin.gd"]:
		report.sources[file] = FileAccess.get_sha256((BASE if control else "res://vehicle/")+file)
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var label := " simple="+str(simple)
		var screen: MeshInstance3D = car.body.get_node("ReferenceRearScreen")
		var deck: MeshInstance3D = car.body.get_node("ReferenceRearDeck")
		var rear: MeshInstance3D = car.body.get_node("ReferenceRear")
		var centre: Vector3 = point_at_uv(screen,Vector2(0.5,1.0))
		var left: Vector3 = point_at_uv(screen,Vector2(0.0,1.0))
		var right: Vector3 = point_at_uv(screen,Vector2(1.0,1.0))
		var bow: float = centre.z-(left.z+right.z)*0.5
		var crown: float = centre.y-(left.y+right.y)*0.5
		check(bow>0.08 and bow<0.20,"RGC01 lower edge bows toward rear like the marked arc"+label)
		check(crown>0.012 and crown<0.030,"RGC02 glass has a gentle transverse crown"+label)
		check(absf(left.y-right.y)<0.00001 and absf(left.z-right.z)<0.00001 and absf(left.x+right.x)<0.00001,"symmetric backlight corners"+label)
		var curve_error := 0.0
		var progression := true
		var previous := centre.z
		for i: int in range(13):
			var u: float = float(i)/12.0
			var point: Vector3 = point_at_uv(screen,Vector2(u,1.0))
			var across: float = point.x/right.x
			curve_error = maxf(curve_error,absf(point.z-(centre.z-bow*across*across)))
			if i>=6:
				progression = progression and point.z<=previous+0.00001
				previous = point.z
		check(curve_error<0.00005 and progression,"single smooth quadratic arc across actual glass vertices"+label)
		var foot: MeshInstance3D = car.body.get_node("ReferenceRearGlassFoot")
		var join_gap: float = edge_gap(edge(screen,1,1.0),edge(foot,1,0.0))
		check(join_gap<0.001,"glass edge meets painted foot without a hole"+label)
		check(edge_gap(edge(foot,1,1.0),edge(deck,1,0.0))<0.0005,"painted foot meets rear deck"+label)
		for side: int in range(2):
			var surround: MeshInstance3D = car.body.get_node("ReferenceRearGlassSurround"+str(side))
			check(edge_gap(edge(surround,0,float(1-side)),edge(screen,0,float(side)))<0.001 and point_at_uv(surround,Vector2(0.0,0.0)).distance_to(point_at_uv(screen,Vector2(float(side),0.0)))<0.001,"curved glass edge meets painted surround "+str(side)+label)
			var start: Vector3 = point_at_uv(screen,Vector2(float(side),0.0))
			var middle: Vector3 = point_at_uv(screen,Vector2(float(side),0.5))
			var finish: Vector3 = point_at_uv(screen,Vector2(float(side),1.0))
			check(absf(finish.x)<absf(middle.x) and absf(finish.x)<absf(start.x)+0.08,"rear glass narrows toward its end "+str(side)+label)
		for rail_name: String in ["ReferenceRoofRail0","ReferenceRoofRail1"]:
			var rail: MeshInstance3D = car.body.get_node(rail_name)
			check(edge_gap(edge(rail,1,1.0),edge(deck,1,0.0))<0.0005,"painted rail meets deck "+rail_name+label)
		check(edge_gap(edge(deck,1,1.0),edge(rear,1,1.0))<0.0005,"deck still meets rear cap"+label)
		var minimum_depth := INF
		for i: int in range(61):
			var u: float = float(i)/60.0
			minimum_depth = minf(minimum_depth,point_at_uv(deck,Vector2(u,1.0)).z-point_at_uv(deck,Vector2(u,0.0)).z)
		check(minimum_depth>0.12,"painted deck retains positive depth across its whole width"+label)
		# These parts remain unchanged; the roof and lower doors were later reshaped.
		for part: String in ["ReferenceHood","ReferenceCanopyGlass","ReferenceRear"]:
			var node: MeshInstance3D = car.body.get_node(part)
			# Godot sanitizes dots in node names; authored cache keys retain them.
			var key: String = part.replace("_", ".")+("_simple" if simple else "")
			var previous_mesh: ArrayMesh = load("res://assets/vehicles/electric_subtle_fenders_v1/"+key.sha256_text().left(24)+".res")
			check(var_to_bytes(node.mesh.surface_get_arrays(0))==var_to_bytes(previous_mesh.surface_get_arrays(0)),"RGC03 retained accepted geometry "+part+label)
		var old_key: String = "ReferenceRearScreen"+("_simple" if simple else "")
		var old_screen: ArrayMesh = load("res://assets/vehicles/electric_subtle_fenders_v1/"+old_key.sha256_text().left(24)+".res")
		var old_node := MeshInstance3D.new()
		old_node.mesh = old_screen
		var start_gap: float = edge_gap(edge(screen,1,0.0),edge(old_node,1,0.0))
		check(point_at_uv(screen,Vector2(0.5,0.0)).z-point_at_uv(old_node,Vector2(0.5,0.0)).z>0.20,"backlight starts farther rearward at the requested roof boundary"+label)
		var roof_seal: MeshInstance3D = car.body.get_node("ReferenceRoofCrossSeal1")
		check(edge_gap(edge(roof_seal,1,1.0),edge(screen,1,0.0))<0.003,"rear screen meets relocated roof seal"+label)
		var hatch: MeshInstance3D = car.body.get_node_or_null("ReferenceTrunkShutLine")
		check(hatch != null,"rear hatch opening has a shut line"+label)
		if hatch != null:
			var cabin = preload("res://vehicle/electric_reference_cabin.gd")
			var body_builder = preload("res://vehicle/electric_reference_body.gd")
			for sample: Array in [[0.0,cabin.top_point(0.02,0.760)],[0.5,body_builder.cap_point(true,0.50,0.32)],[1.0,cabin.top_point(0.98,0.760)]]:
				var actual: Vector3 = point_at_uv(hatch,Vector2(sample[0],0.0))
				check(actual.distance_to(sample[1])<0.009,"hatch seam reaches roof sides and lower rear face "+str(sample[0])+label)
			for index: int in [10,12]:
				for side: int in range(2):
					var t: float=float(index)/56.0
					var actual: Vector3=point_at_uv(hatch,Vector2(t if side==0 else 1.0-t,0.0))
					check(absf(absf(actual.x)-0.768)<0.003,"hatch seam follows a steady deck edge "+str(index)+"/"+str(side)+label)
			for index: int in [14,16]:
				var p: float=float(index-13)/4.0
				for side: int in range(2):
					var t: float=float(index)/56.0
					var actual: Vector3=point_at_uv(hatch,Vector2(t if side==0 else 1.0-t,0.0))
					var target: float=lerpf(0.768,0.70,smoothstep(0.0,1.0,p))
					check(absf(absf(actual.x)-target)<0.003,"hatch seam continues smoothly down the side "+str(index)+"/"+str(side)+label)
		old_node.free()
		report.models.append({"simple":simple,"rearward_bow":bow,"crown":crown,"curve_error":curve_error,"glass_deck_gap":join_gap,"minimum_deck_depth":minimum_depth,"roof_boundary_displacement":start_gap,"roof_seal_gap":edge_gap(edge(roof_seal,1,1.0),edge(screen,1,0.0))})
		car.free()
	report.merge({"checks":checks,"failures":failures})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("VOLT_REAR_WINDOW_CURVE: ",checks," checks, ",failures," failures; ",JSON.stringify(report.models))
	quit(1 if failures else 0)
