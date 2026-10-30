extends SceneTree
## Actual outer-hood sections cover the wing region missed by centre-only checks.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String = "res://../docs/evidence/electric-hood-fairing-2026-10-26/native"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func cross_section(car: CarVisual, z: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name) != "ClamshellHood" and not str(mesh.name).begins_with("HoodSurround"): continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for index: int in range(0,faces.size(),3):
			for edge: int in range(3):
				var a: Vector3 = faces[index+edge]
				var b: Vector3 = faces[index+(edge+1)%3]
				var point := Vector3.ZERO
				if absf(a.z-z)<0.000001: point = a
				elif (a.z-z)*(b.z-z)<0: point = a.lerp(b,(z-a.z)/(b.z-a.z))
				else: continue
				if point.x>=0.45: points.append(Vector2(point.x,point.y))
	points.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x<b.x)
	var unique: Array[Vector2] = []
	for point: Vector2 in points:
		if unique.is_empty() or point.x-unique[-1].x>0.0001: unique.append(point)
	return unique

func settle() -> void:
	for frame: int in range(7): await process_frame
	await RenderingServer.frame_post_draw

func wing_join(car: CarVisual) -> Dictionary:
	var maximum_angle: float = 0
	var maximum_gap: float = 0
	var count: int = 0
	var worst: Dictionary = {}
	for side: float in [-1.0,1.0]:
		var vertices: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for mesh: MeshInstance3D in car.body.find_children("SculptedSide*","MeshInstance3D",true,false):
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
				if point.x*side<0 or point.z<COACH.FRONT_JOIN-0.001 or point.z> -0.94: continue
				if absf(point.y-COACH.upper(point.z))>0.0001: continue
				vertices.append(point)
				normals.append(arrays[Mesh.ARRAY_NORMAL][index])
		for mesh: MeshInstance3D in car.body.find_children("HoodSurround*","MeshInstance3D",true,false):
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
				if point.x*side<0 or point.z< -1.85 or point.z> -1.15: continue
				if (arrays[Mesh.ARRAY_TEX_UV][index] as Vector2).y<0.99999: continue
				if absf(absf(point.x)-COACH.width(COACH.upper(point.z),point.z))>0.0001: continue
				var below: int = -1
				var above: int = -1
				for candidate: int in range(vertices.size()):
					if vertices[candidate].z<=point.z+0.000001 and (below<0 or vertices[candidate].z>vertices[below].z): below=candidate
					if vertices[candidate].z>=point.z-0.000001 and (above<0 or vertices[candidate].z<vertices[above].z): above=candidate
				if below<0 or above<0: continue
				var t: float = 0 if below == above else (point.z-vertices[below].z)/(vertices[above].z-vertices[below].z)
				var normal: Vector3 = normals[below].lerp(normals[above],t).normalized()
				var skin: Vector3 = vertices[below].lerp(vertices[above],t)
				var angle: float = rad_to_deg(normal.angle_to(arrays[Mesh.ARRAY_NORMAL][index]))
				if angle>maximum_angle:
					maximum_angle = angle
					worst = {"point":str(point),"skin_normal":str(normal),"hood_normal":str(arrays[Mesh.ARRAY_NORMAL][index])}
				maximum_gap = maxf(maximum_gap,point.distance_to(skin))
				count += 1
	return {"samples":count,"maximum_angle":maximum_angle,"maximum_gap":maximum_gap,"worst":worst}

func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	if before:
		var author: GDScript = COACH
		var baseline: String = "res://../docs/evidence/electric-hood-fairing-2026-10-26/before"
		author.source_code = FileAccess.get_file_as_string(baseline+"/game/vehicle/electric_coachwork.gd").replace("res://assets/vehicles/electric_coachwork_v8",baseline+"/electric_coachwork_v8")
		assert(author.reload() == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var label: String = "simple" if simple else "full"
		var joins: Dictionary = wing_join(car)
		metrics[label+"_wing_join"] = joins
		check(joins.samples>=20 and joins.maximum_angle<6,"actual bonnet/wing normals agree across the full outer join "+label)
		check(joins.samples>=20 and joins.maximum_gap<0.001,"actual bonnet and wing meet within one millimetre "+label)
		for z: float in [-1.85,-1.65,-1.45,-1.20]:
			var points: Array[Vector2] = cross_section(car,z)
			var lowest: float = INF
			var rise: float = 0
			var values: Array = []
			for point: Vector2 in points:
				lowest = minf(lowest,point.y)
				rise = maxf(rise,point.y-lowest)
				values.append([point.x,point.y])
			# Equal 20 mm transverse runs measure the actual wing turn. Positive
			# monotonicity alone missed the nearly 50-degree crease in v8.
			var steepest: float = 0
			var turns: Array[float] = []
			var x: float = points[0].x
			while x+0.020<=points[-1].x:
				var a: float = interpolate(points,x)
				var b: float = interpolate(points,x+0.020)
				var angle: float = rad_to_deg(atan2(b-a,0.020))
				steepest = maxf(steepest,absf(angle))
				turns.append(angle)
				x += 0.020
			metrics[label+"_cross_"+str(z)] = {"maximum_outward_rise":rise,"maximum_transverse_angle":steepest,"angles":turns,"points":values}
			check(points.size()>15,"actual wing section is populated "+label+" "+str(z))
			check(rise<0.002,"outer bonnet flows down without a pinched valley or raised wing ridge "+label+" "+str(z))
			check(steepest<30,"outer shoulder turns gradually within 30 degrees "+label+" "+str(z))
		car.free()
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,1000)
		var viewport := SubViewport.new()
		viewport.size = root.size
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		for simple: bool in [false,true]:
			var label: String = "simple" if simple else "full"
			var world := Node3D.new()
			viewport.add_child(world)
			var car := CarVisual.new()
			car.vehicle_id = "electric"
			car.simple_model = simple
			car.livery = VehicleLivery.defaults("electric")
			world.add_child(car)
			ShowroomStudio.build(world,car)
			var camera := Camera3D.new()
			camera.current = true
			camera.fov = 32
			world.add_child(camera)
			var shots: Array = [
				["owner-angle",Vector3(2.2,3.2,-3.5),Vector3(0.15,0.85,-1.25)],
				["wing-detail",Vector3(1.9,2.2,-2.5),Vector3(0.56,0.88,-1.35)],
				["front",Vector3(0,1.8,-4.8),Vector3(0,0.70,-0.7)],
				["top",Vector3(0,5,-1.35),Vector3(0,0.8,-1.30)],
				["side",Vector3(4.9,1.6,-1.2),Vector3(0,0.74,-1.25)]]
			for shot: Array in shots:
				camera.position = shot[1]
				camera.look_at(shot[2])
				await settle()
				check(viewport.get_texture().get_image().save_png(output.path_join(label+"-"+str(shot[0])+".png")) == OK,"native green hood "+label+" "+str(shot[0]))
			world.free()
		viewport.free()
		var showroom := CarShowroom.new()
		showroom.vehicle_id = "electric"
		showroom.garage_mode = true
		showroom.read_only = true
		showroom.size = Vector2(root.size)
		root.add_child(showroom)
		await settle()
		showroom.yaw = 0
		showroom._orbit()
		var deck := Vector3(0,GarageEnvironment.DECK_HEIGHT,0)
		showroom.camera.position = Vector3(2.2,3.2,-3.5)+deck
		showroom.camera.look_at(Vector3(0.15,0.85,-1.25)+deck)
		showroom._update_roof()
		showroom.invalidate_render()
		await settle()
		check(showroom.showroom_viewport.get_texture().get_image().save_png(output.path_join("garage-owner-angle.png")) == OK,"actual Garage environment at the owner's hood angle")
		showroom.queue_free()
		await process_frame
	var report := FileAccess.open(output+"/hood-fairing.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_HOOD_FAIRING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func interpolate(points: Array[Vector2], x: float) -> float:
	for index: int in range(points.size()-1):
		if points[index+1].x>=x:
			return lerpf(points[index].y,points[index+1].y,(x-points[index].x)/(points[index+1].x-points[index].x))
	return points[-1].y
