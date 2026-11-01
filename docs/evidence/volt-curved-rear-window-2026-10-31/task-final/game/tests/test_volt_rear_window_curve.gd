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
		check(bow>0.15 and bow<0.22,"RGC01 lower edge bows toward rear like the marked arc"+label)
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
		var join_gap: float = edge_gap(edge(screen,1,1.0),edge(deck,1,0.0))
		check(join_gap<0.0005,"RGC02 glass edge meets painted deck without a hole"+label)
		for rail_name: String in ["ReferenceRoofRail0","ReferenceRoofRail1"]:
			var rail: MeshInstance3D = car.body.get_node(rail_name)
			check(edge_gap(edge(rail,1,1.0),edge(deck,1,0.0))<0.0005,"painted rail meets deck "+rail_name+label)
		check(edge_gap(edge(deck,1,1.0),edge(rear,1,1.0))<0.0005,"deck still meets rear cap"+label)
		var minimum_depth := INF
		for i: int in range(61):
			var u: float = float(i)/60.0
			minimum_depth = minf(minimum_depth,point_at_uv(deck,Vector2(u,1.0)).z-point_at_uv(deck,Vector2(u,0.0)).z)
		check(minimum_depth>0.12,"painted deck retains positive depth across its whole width"+label)
		# The deck lip follows the revised panel. The actual tail cap, front,
		# roof and flanks retain their accepted buffers exactly.
		for part: String in ["ReferenceHood","ReferenceCanopyGlass","ReferencePanoramicRoof","ReferenceSide-1_0","ReferenceSide1_0","ReferenceRear"]:
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
		check(start_gap<0.00001,"backlight start at roof seam retained"+label)
		old_node.free()
		report.models.append({"simple":simple,"rearward_bow":bow,"crown":crown,"curve_error":curve_error,"glass_deck_gap":join_gap,"minimum_deck_depth":minimum_depth,"roof_seam_gap":start_gap})
		car.free()
	report.merge({"checks":checks,"failures":failures})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("VOLT_REAR_WINDOW_CURVE: ",checks," checks, ",failures," failures; ",JSON.stringify(report.models))
	quit(1 if failures else 0)
