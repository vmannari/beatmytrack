extends SceneTree
## Whole-car form/construction gates, measured independently of native screenshots.
const COACH = preload("res://vehicle/electric_coachwork.gd")
const MODEL = preload("res://vehicle/electric_car_model.gd")
var output: String = "res://../docs/evidence/electric-design-pass-2026-10-26/regression"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func triangle_count(node: Node) -> int:
	var count: int = node.mesh.get_faces().size()/3 if node is MeshInstance3D and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY else 0
	for child: Node in node.get_children(): count += triangle_count(child)
	return count

func join_error(a: MeshInstance3D, edge_a: Callable, b: MeshInstance3D, edge_b: Callable) -> Dictionary:
	var first: Array = a.mesh.surface_get_arrays(0)
	var second: Array = b.mesh.surface_get_arrays(0)
	var distance: float = 0
	var angle: float = 0
	var samples: int = 0
	for i: int in range(first[Mesh.ARRAY_VERTEX].size()):
		if not edge_a.call(first[Mesh.ARRAY_TEX_UV][i]): continue
		var closest: float = INF
		var normal := Vector3.ZERO
		for j: int in range(second[Mesh.ARRAY_VERTEX].size()):
			if not edge_b.call(second[Mesh.ARRAY_TEX_UV][j]): continue
			var gap: float = (first[Mesh.ARRAY_VERTEX][i] as Vector3).distance_to(second[Mesh.ARRAY_VERTEX][j])
			if gap < closest:
				closest = gap
				normal = second[Mesh.ARRAY_NORMAL][j]
		distance = maxf(distance,closest)
		angle = maxf(angle,rad_to_deg((first[Mesh.ARRAY_NORMAL][i] as Vector3).angle_to(normal)))
		samples += 1
	return {"gap":distance,"angle":angle,"samples":samples}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	if "--before" in OS.get_cmdline_user_args():
		output = "res://../docs/evidence/electric-design-pass-2026-10-26/expanded-baseline"
		var baseline: String = "res://../docs/evidence/electric-design-pass-2026-10-26/before/game/vehicle/"
		var author: GDScript = COACH
		author.source_code = FileAccess.get_file_as_string(baseline+"electric_coachwork.gd")
		assert(author.reload() == OK)
		var assembly: GDScript = MODEL
		assembly.source_code = FileAccess.get_file_as_string(baseline+"electric_car_model.gd")
		assert(assembly.reload() == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		if "--before" not in OS.get_cmdline_user_args():
			check(COACH.reveal_queries.is_empty(),"prepared runtime builds no panel intersection structures")
		var label: String = "simple" if simple else "full"
		var count: int = triangle_count(car)
		var wheel_count: int = 0
		for wheel: Node3D in car.rolling_wheels: wheel_count += triangle_count(wheel)
		metrics[label+"_triangles"] = count
		metrics[label+"_wheel_triangles"] = wheel_count
		check(count<170000,"retained full triangle ceiling, "+label)
		check(wheel_count<40000 and float(wheel_count)/count<0.28,"wheel allocation leaves room for coachwork, "+label)
		check(car.front_wheels.size()==2 and car.rolling_wheels.size()==4,"retained wheel articulation, "+label)
		var finite: bool = true
		for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: finite = finite and vertex.is_finite()
			finite = finite and arrays[Mesh.ARRAY_NORMAL]!=null
			if arrays[Mesh.ARRAY_NORMAL]!=null:
				for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: finite = finite and normal.is_finite() and normal.length_squared()>0.9
		check(finite,"finite prepared surfaces and unit normals, "+label)
		var roof: MeshInstance3D = car.body.get_node("CrownedRoof")
		for rear: bool in [false,true]:
			var border: MeshInstance3D = car.body.get_node("ScreenPaintFrame"+str(rear)+"2")
			var join: Dictionary = join_error(roof,func(uv: Vector2) -> bool: return absf(uv.y-(1.0 if rear else 0.0))<0.0001,
				border,func(uv: Vector2) -> bool: return uv.y<0.0001)
			metrics[label+"_roof_screen_"+str(rear)] = join
			check(join.samples>10 and join.gap<0.00005,"prepared roof/screen boundary closes exactly, "+label+str(rear))
			check(join.angle<3.5,"prepared roof/screen normals flow continuously, "+label+str(rear))
		for side: float in [-1.0,1.0]:
			var cabin: MeshInstance3D = car.body.find_children("CabinSide"+("-1" if side<0 else "1")+"*","MeshInstance3D",true,false)[0]
			var join: Dictionary = join_error(cabin,func(uv: Vector2) -> bool: return uv.y>0.9999,
				roof,func(uv: Vector2) -> bool: return absf(uv.x-(0.0 if side<0 else 1.0))<0.0001)
			metrics[label+"_roof_side_"+str(side)] = join
			check(join.samples>10 and join.gap<0.00005,"prepared roof/side boundary closes exactly, "+label+str(side))
			check(join.angle<3.5,"prepared roof rolls into side canopy, "+label+str(side))
		var brow_low: float = INF
		var brow_high: float = -INF
		for index: int in range(65):
			var p: Vector3 = COACH.hood_point(index/64.0,0)
			brow_low = minf(brow_low,p.y)
			brow_high = maxf(brow_high,p.y)
		metrics[label+"_brow_height_range"] = brow_high-brow_low
		check(brow_high-brow_low<0.035,"restrained nose crown without raised outer trough, "+label)
		var back: MeshInstance3D = car.body.get_node("RearDeck")
		for side: float in [-1.0,1.0]:
			var quarter: MeshInstance3D = car.body.find_children("SculptedSide"+("-1" if side<0 else "1")+"*","MeshInstance3D",true,false)[0]
			var quarter_arrays: Array = quarter.mesh.surface_get_arrays(0)
			var upper_stations: Dictionary = {}
			for index: int in range(quarter_arrays[Mesh.ARRAY_VERTEX].size()):
				var point: Vector3 = quarter_arrays[Mesh.ARRAY_VERTEX][index]
				if absf(point.y-COACH.upper(point.z))<0.00001: upper_stations[quarter_arrays[Mesh.ARRAY_TEX_UV][index]] = true
			var join: Dictionary = join_error(back,func(uv: Vector2) -> bool: return absf(uv.x-(0.0 if side<0 else 1.0))<0.0001,
				quarter,func(uv: Vector2) -> bool: return upper_stations.has(uv))
			metrics[label+"_deck_quarter_"+str(side)] = join
			check(join.samples>3 and join.gap<0.00005,"deck/quarter has shared prepared stations, "+label+str(side))
			check(join.angle<3.5,"deck/quarter has a continuous prepared normal frame, "+label+str(side))
		var seam_gap: float = 0
		for tail: MeshInstance3D in car.body.find_children("TailSkin5*","MeshInstance3D",true,false):
			var join: Dictionary = join_error(tail,func(uv: Vector2) -> bool: return uv.y>0.9999,
				back,func(uv: Vector2) -> bool: return uv.y>0.9999)
			seam_gap = maxf(seam_gap,join.gap)
		metrics[label+"_deck_tail_gap"] = seam_gap
		check(seam_gap<0.00005,"deck/tail use identical prepared edge vertices, "+label)
		check(car.body.get_node_or_null("EndUndertrayFront")!=null and car.body.get_node_or_null("EndUndertrayRear")!=null,"both bumper undersides have fitted closures, "+label)
		check(car.body.find_children("ProjectorLens*","MeshInstance3D",true,false).size()==12,"paired optical modules in continuous front signature, "+label)
		check(car.body.find_children("ChargeDoorReveal*","MeshInstance3D",true,false).size()==1,"rounded fitted charging door reveal, "+label)
		check(car.body.find_children("MirrorShell*","MeshInstance3D",true,false).size()==2 and car.body.find_children("MirrorGlass*","MeshInstance3D",true,false).size()==2,"complete fitted mirror housings, "+label)
		for wheel: Vector3 in car.wheel_rest_positions:
			check(absf(absf(wheel.x)*HandlingConfig.BODY_SCALE-0.74)<0.000001 and absf(absf(wheel.z)*HandlingConfig.BODY_SCALE-1.23)<0.000001,"retained physical wheel centres, "+label)
		car.free()
	var file := FileAccess.open(output.path_join("design-pass.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_DESIGN_PASS: %d checks, %d failures, %s" % [checks,failures,JSON.stringify(metrics)])
	quit(1 if failures else 0)
