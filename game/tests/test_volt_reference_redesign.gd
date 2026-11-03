extends SceneTree
## Actual unbatched full/simple model: closed fascia, fitted glass and gameplay parts.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func point_at_uv(node: MeshInstance3D, uv: Vector2) -> Vector3:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var best := INF
	var result := Vector3.INF
	for i: int in range(positions.size()):
		var distance: float = uvs[i].distance_squared_to(uv)
		if distance < best:
			best = distance
			result = node.transform * positions[i]
	return result

func edge(node: MeshInstance3D, axis: int, value: float) -> Array[Dictionary]:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var result: Array[Dictionary] = []
	for i: int in range(positions.size()):
		if absf(uvs[i][axis]-value) < 0.00001:
			result.append({"t":uvs[i][1-axis],"p":node.transform * positions[i]})
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.t < b.t)
	return result

func edge_gap(first: Array[Dictionary],second: Array[Dictionary]) -> float:
	var largest := 0.0
	if first.is_empty() or second.size() < 2: return INF
	for sample: Dictionary in first:
		var p: Vector3 = sample.p
		var nearest := INF
		for i: int in range(second.size()-1):
			var a: Vector3 = second[i].p
			var b: Vector3 = second[i+1].p
			nearest = minf(nearest,p.distance_to(Geometry3D.get_closest_point_to_segment(p,a,b)))
		largest = maxf(largest,nearest)
	return largest

func intersects_front(mesh: MeshInstance3D, x: float, y: float) -> bool:
	var points: PackedVector3Array = mesh.mesh.get_faces()
	var start := Vector3(x,y,-3.5)
	var finish := Vector3(x,y,-1.3)
	for i: int in range(0,points.size(),3):
		var a: Vector3 = mesh.transform * points[i]
		var b: Vector3 = mesh.transform * points[i+1]
		var c: Vector3 = mesh.transform * points[i+2]
		if x < minf(a.x,minf(b.x,c.x))-0.00001 or x > maxf(a.x,maxf(b.x,c.x))+0.00001: continue
		if y < minf(a.y,minf(b.y,c.y))-0.00001 or y > maxf(a.y,maxf(b.y,c.y))+0.00001: continue
		if Geometry3D.segment_intersects_triangle(start,finish,a,b,c) != null: return true
	return false

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--before-body=") or arg.begins_with("--before-cabin="):
			var body: bool = arg.begins_with("--before-body=")
			var source: String = FileAccess.get_file_as_string(arg.trim_prefix("--before-body=" if body else "--before-cabin="))
			assert(not source.is_empty())
			var script: GDScript = load("res://vehicle/electric_reference_body.gd" if body else "res://vehicle/electric_reference_cabin.gd")
			script.source_code = source
			assert(script.reload() == OK)
	M.use_baked = "--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	var counts: Array[int] = []
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var label := " simple="+str(simple)
		var total := 0
		var finite := true
		for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh == null:
				finite = false
				continue
			total += mesh.mesh.get_faces().size()/3
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]: finite = finite and p.is_finite()
				if arrays[Mesh.ARRAY_NORMAL] != null:
					for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: finite = finite and n.is_finite() and n.length_squared() > 0.5
				if arrays[Mesh.ARRAY_TEX_UV] != null:
					for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]: finite = finite and uv.is_finite()
		counts.append(total)
		check(finite,"mesh positions, normals and UVs are finite"+label)
		var hood: MeshInstance3D = car.body.get_node_or_null("ReferenceHood")
		var front: MeshInstance3D = car.body.get_node_or_null("ReferenceFrontUpper")
		var windscreen: MeshInstance3D = car.body.get_node_or_null("ReferenceCanopyGlass")
		check(hood != null and front != null and windscreen != null,"hood, front and windscreen exist"+label)
		if hood != null and windscreen != null:
			var cowl: Vector3 = point_at_uv(hood,Vector2(0.5,1.0))
			var glass_foot: Vector3 = point_at_uv(windscreen,Vector2(0.5,0.0))
			check(cowl.distance_to(glass_foot) < 0.005,"actual windscreen meets hood: "+str(cowl.distance_to(glass_foot))+label)
			var cowl_gap: float = edge_gap(edge(windscreen,1,0.0),edge(hood,1,1.0))
			check(cowl_gap < 0.006,"windscreen meets hood across its width: "+str(cowl_gap)+label)
			var cowl_side: Vector3 = point_at_uv(windscreen,Vector2(0.0,0.0))
			check(absf(cowl.z+0.982) < 0.006 and absf(cowl_side.z+1.02) < 0.006,"curved windscreen base meets designed center and side positions"+label)
			var rear: MeshInstance3D = car.body.get_node_or_null("ReferenceRear")
			var rear_pivot: Node3D = car.get_node_or_null("RearLeftWheel")
			if rear != null and rear_pivot != null and car.front_wheels.size() == 2:
				var nose_z: float = hood.mesh.get_aabb().position.z
				var tail_z: float = rear.mesh.get_aabb().end.z
				var length: float = tail_z-nose_z
				var rear_fraction: float = (tail_z-rear_pivot.position.z)/length
				var front_fraction: float = (tail_z-car.front_wheels[0].position.z)/length
				var cowl_fraction: float = (tail_z-cowl.z)/length
				var wheel_fraction: float = 0.74/length
				print("VOLT_PROFILE ",label," rear=",rear_fraction," front=",front_fraction," cowl=",cowl_fraction," wheel=",wheel_fraction)
				check(rear_fraction>0.12 and rear_fraction<0.24 and front_fraction>0.76 and front_fraction<0.90 and cowl_fraction>0.68 and cowl_fraction<0.77 and wheel_fraction>0.13 and wheel_fraction<0.21,"fastback proportions remain in reference ranges"+label)
			else:
				check(false,"profile measurements have all components"+label)
		if front != null:
			check(front.material_override == car.paint_materials.body,"closed fascia uses the body paint"+label)
			# The current nose is made of several fitted panels and recessed
			# cooling/air-curtain backs, rather than one full-height upper mesh.
			var fascia: Array[MeshInstance3D] = [front]
			for prefix: String in ["SportLowerBumper","SportBumper","SportCurtain","SportCooling"]:
				for part: MeshInstance3D in car.body.find_children(prefix+"*","MeshInstance3D",false,false): fascia.append(part)
			for x: float in [-0.45,0.0,0.45]:
				for y: float in [0.34,0.48,0.62]:
					var covered := false
					for part: MeshInstance3D in fascia: covered = covered or intersects_front(part,x,y)
					check(covered,"fitted front panels cover "+str(Vector2(x,y))+label)
		check(car.body.find_children("*AirCurtain*","MeshInstance3D",true,false).is_empty() and car.body.find_children("*Intake*","MeshInstance3D",true,false).is_empty() and car.body.find_children("*Exhaust*","MeshInstance3D",true,false).is_empty(),"no false intake or exhaust geometry"+label)
		for name_value: String in ["ReferencePanoramicRoof","ReferenceRearScreen","ReferenceRoofRail0","ReferenceRoofRail1","ReferenceFrontLightbar","ReferenceRearLightbar"]:
			check(car.body.get_node_or_null(name_value) != null,"distinct cabin or light part "+name_value+label)
		for side: String in ["-1_0","1_0"]:
			for part: String in ["ReferenceFrontSideGlass","ReferenceRearSideGlass","ReferenceRearQuarterPanel","ReferenceAPillar","ReferenceBPillar","ReferenceCPillar"]:
				check(car.body.get_node_or_null(part+side) != null,"distinct window or pillar "+part+side+label)
			check(car.body.get_node_or_null("ReferenceQuarterGlass"+side)==null,"rear quarter window removed "+side+label)
			for join: Array in [["ReferenceAPillar","ReferenceFrontSideGlass"],["ReferenceFrontSideGlass","ReferenceBPillar"],["ReferenceBPillar","ReferenceRearSideGlass"],["ReferenceRearSideGlass","ReferenceCPillar"],["ReferenceCPillar","ReferenceRearQuarterPanel"],["ReferenceRearQuarterPanel","ReferenceRearPillar"]]:
				var first: MeshInstance3D = car.body.get_node_or_null(str(join[0])+side)
				var second: MeshInstance3D = car.body.get_node_or_null(str(join[1])+side)
				if first == null or second == null:
					check(false,"window join exists "+str(join)+side+label)
				else:
					var gap: float = edge_gap(edge(first,0,1.0),edge(second,0,0.0))
					check(gap < 0.003,"actual fitted window join "+str(join)+side+" gap="+str(gap)+label)
		for join: Array in [["ReferenceCanopyGlass","ReferenceRoofCrossSeal0"],["ReferenceRoofCrossSeal0","ReferencePanoramicRoof"],["ReferencePanoramicRoof","ReferenceRoofCrossSeal1"],["ReferenceRoofCrossSeal1","ReferenceRearScreen"]]:
			var first: MeshInstance3D = car.body.get_node_or_null(join[0])
			var second: MeshInstance3D = car.body.get_node_or_null(join[1])
			if first == null or second == null:
				check(false,"canopy join exists "+str(join)+label)
			else:
				var gap: float = edge_gap(edge(first,1,1.0),edge(second,1,0.0))
				check(gap < 0.003,"actual fitted canopy join "+str(join)+" gap="+str(gap)+label)
		for section: String in ["ReferenceCanopyGlass","ReferencePanoramicRoof"]:
			var pane: MeshInstance3D = car.body.get_node_or_null(section)
			for side: int in range(2):
				var rail: MeshInstance3D = car.body.get_node_or_null("ReferenceRoofRail"+str(side))
				if pane == null or rail == null:
					check(false,"pane and roof rail exist "+section+label)
				else:
					var gap: float = edge_gap(edge(pane,0,float(side)),edge(rail,0,float(1-side)))
					check(gap < 0.003,"pane meets roof rail "+section+" side="+str(side)+" gap="+str(gap)+label)
		var rear_screen: MeshInstance3D = car.body.get_node("ReferenceRearScreen")
		for side: int in range(2):
			var surround: MeshInstance3D = car.body.get_node("ReferenceRearGlassSurround"+str(side))
			var rail: MeshInstance3D = car.body.get_node("ReferenceRoofRail"+str(side))
			check(edge_gap(edge(surround,0,float(1-side)),edge(rear_screen,0,float(side)))<0.001 and point_at_uv(surround,Vector2(0.0,0.0)).distance_to(point_at_uv(rear_screen,Vector2(float(side),0.0)))<0.001,"rear glass meets tapered side surround "+str(side)+label)
			check(edge_gap(edge(surround,0,float(side)),edge(rail,0,float(1-side)))<0.003,"rear surround meets roof rail "+str(side)+label)
		var deck: MeshInstance3D = car.body.get_node_or_null("ReferenceRearDeck")
		var backlight: MeshInstance3D = car.body.get_node_or_null("ReferenceRearScreen")
		var rear_panel: MeshInstance3D = car.body.get_node_or_null("ReferenceRear")
		if deck != null and backlight != null and rear_panel != null:
			var foot: MeshInstance3D = car.body.get_node("ReferenceRearGlassFoot")
			var rear_gap: float = edge_gap(edge(backlight,1,1.0),edge(foot,1,0.0))
			var tail_gap: float = edge_gap(edge(deck,1,1.0),edge(rear_panel,1,1.0))
			check(rear_gap < 0.001,"rear glass meets painted foot gap="+str(rear_gap)+label)
			check(edge_gap(edge(foot,1,1.0),edge(deck,1,0.0))<0.0005,"painted foot meets deck"+label)
			check(tail_gap < 0.0005,"deck meets tail gap="+str(tail_gap)+label)
			for rail_index: int in range(2):
				var rail: MeshInstance3D = car.body.get_node_or_null("ReferenceRoofRail"+str(rail_index))
				var rail_gap: float = edge_gap(edge(rail,1,1.0),edge(deck,1,0.0)) if rail != null else INF
				check(rail_gap < 0.0005,"rear rail meets deck gap="+str(rail_gap)+label)
		else:
			check(false,"rear glass, deck and tail surfaces exist"+label)
		for side_index: int in range(2):
			var suffix: String = "-1_0" if side_index == 0 else "1_0"
			var bottom: MeshInstance3D = car.body.get_node_or_null("ReferenceWindowBottom"+suffix)
			var top: MeshInstance3D = car.body.get_node_or_null("ReferenceWindowTop"+suffix)
			var flank: MeshInstance3D = car.body.get_node_or_null("ReferenceSide"+suffix)
			var rail: MeshInstance3D = car.body.get_node_or_null("ReferenceRoofRail"+str(side_index))
			var belt_gap: float = edge_gap(edge(bottom,1,0.0),edge(flank,1,1.0)) if bottom != null and flank != null else INF
			var top_gap: float = edge_gap(edge(top,1,1.0),edge(rail,0,float(side_index))) if top != null and rail != null else INF
			check(belt_gap < 0.002,"window meets side body gap="+str(belt_gap)+label)
			check(top_gap < 0.002,"window meets roof gap="+str(top_gap)+label)
		check(car.front_wheels.size() == 2 and car.rolling_wheels.size() == 4,"front steering and four rolling wheels"+label)
		for pivot: Node3D in car.front_wheels:
			var spin: Node = pivot.get_node_or_null("WheelSpin")
			check(spin != null and pivot.get_node_or_null("BrakeAssembly") != null and spin.get_node_or_null("BrakeAssembly") == null,"brake follows steering without spinning"+label)
		var state := VehicleState.new()
		var drive := DriveFrame.new()
		state.tick = 1
		state.steering = 0.5
		car.present(Vector2.ZERO,0.0,state,drive)
		state.tick = 2
		car.present(Vector2(0,1),0.0,state,drive)
		var steering_ok := true
		var rolling_ok := true
		for pivot: Node3D in car.front_wheels:
			var brake: Node3D = pivot.get_node_or_null("BrakeAssembly")
			steering_ok = steering_ok and is_equal_approx(pivot.rotation.y,-0.2) and brake != null and is_zero_approx(brake.rotation.x)
		for rotor: Node3D in car.rolling_wheels:
			rolling_ok = rolling_ok and absf(rotor.rotation.x) > 0.01
		check(steering_ok and rolling_ok,"driving steers calipers and rolls all four wheels"+label)
		var blades: Array[Node] = car.find_children("RefBladeFace*","MeshInstance3D",true,false)
		var returns: Array[Node] = car.find_children("RefBladeEdge*","MeshInstance3D",true,false)
		check(blades.size() == 20 and returns.size() == 40,"five dimensional aero blades per wheel"+label)
		var saved: Dictionary = VehicleLivery.defaults("electric")
		saved.colors.body = "638d86"
		saved.pattern = "apex_twin"
		car.apply_livery(saved)
		check(car.paint_materials.body.albedo_color.is_equal_approx(Color("638d86")),"saved body colour applies"+label)
		var finish: ShaderMaterial = hood.get_active_material(0) as ShaderMaterial if hood != null else null
		check(car.livery.pattern == "apex_twin" and finish != null and finish.get_shader_parameter("pattern_enabled") and finish.get_shader_parameter("livery_mask") != null,"saved pattern reaches painted hood"+label)
		car.set_night_headlights(true)
		check(car.headlights != null and car.headlights.visible and car.headlights.find_child("ReferenceNightLightbar",true,false) != null,"night light uses the new front"+label)
		car.rear_braking = true
		car._update_rear_lights()
		check(car.brake_material.emission_energy_multiplier > 2.0,"brake lamps respond"+label)
		car.free()
	check(counts.size() == 2 and counts[1] < counts[0] and counts[0] <= 120000 and counts[1] <= 45000,"detailed and simple meshes stay within established budgets")
	if M.use_baked:
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(M.ASSET_ROOT.path_join("manifest.json")))
		var current: bool = manifest is Dictionary and manifest.has("sources")
		if current:
			for file: String in ["electric_car_model.gd","electric_reference_mesh.gd","electric_reference_body.gd","electric_reference_cabin.gd","electric_reference_details.gd"]:
				current = current and manifest.sources.get(file,"") == FileAccess.get_sha256("res://vehicle/"+file)
		var loaded := true
		for key: String in M.meshes:
			var path: String = M.ASSET_ROOT.path_join(key.sha256_text().left(24)+".res")
			loaded = loaded and ResourceLoader.exists(path) and ResourceLoader.load(path) == M.meshes[key]
		check(current and loaded,"all prepared meshes exist, were actually loaded, and match current source manifest")
	print("VOLT_REFERENCE_REDESIGN: ",checks," checks, ",failures," failures; triangles ",counts," prepared=",M.use_baked)
	quit(1 if failures else 0)
