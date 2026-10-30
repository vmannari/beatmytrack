extends SceneTree
## Test the actual seam in physical plan view, including the formerly flared tips.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String = "res://../docs/evidence/electric-clean-bonnet-2026-10-26/native"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func outline(car: CarVisual, edge: int) -> Array[Vector3]:
	var mesh: MeshInstance3D = car.body.get_node("HoodReturn"+str(edge)+"false")
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var points: Array[Vector3] = []
	for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
		var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][index]
		# The end fillets turn onto the transverse seams. The entire remaining
		# side, including the marked nose region, must flow without an S hook.
		if uv.y<0.00001 and uv.x>=0.06 and uv.x<=0.94:
			var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			points.append(Vector3(absf(point.x),point.y,point.z))
	points.sort_custom(func(a: Vector3,b: Vector3) -> bool: return a.z<b.z)
	return points

func settle() -> void:
	for frame: int in range(7): await process_frame
	await RenderingServer.frame_post_draw

func corner(car: CarVisual, edge: int, end: float, outer: float) -> Vector3:
	var mesh: MeshInstance3D = car.body.get_node("HoodSurround"+str(edge))
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var closest: float = INF
	var point := Vector3(INF,INF,INF)
	for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
		var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][index]
		# Collapsed fan edges can omit a redundant endpoint UV. Its nearest
		# remaining boundary vertex occupies the same actual corner position.
		if absf(uv.y-outer)<0.000001 and absf(uv.x-end)<closest:
			closest = absf(uv.x-end)
			point = arrays[Mesh.ARRAY_VERTEX][index]
	return point

func surface_probe(car: CarVisual, x: float, z: float) -> Dictionary:
	var result: Dictionary = {}
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name) != "ClamshellHood" and not str(mesh.name).begins_with("Hood"): continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		var height_value: float = -INF
		for index: int in range(0,faces.size(),3):
			var point: Variant = Geometry3D.ray_intersects_triangle(Vector3(x,2,z),Vector3.DOWN,faces[index],faces[index+1],faces[index+2])
			if point != null: height_value = maxf(height_value,point.y)
		if is_finite(height_value): result[str(mesh.name)] = height_value
	return result

func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	if before:
		var baseline: String = "res://../docs/evidence/electric-clean-bonnet-2026-10-26/before"
		var author: GDScript = COACH
		author.source_code = FileAccess.get_file_as_string(baseline+"/game/vehicle/electric_coachwork.gd").replace("res://assets/vehicles/electric_coachwork_v9",baseline+"/electric_coachwork_v9")
		assert(author.reload() == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var label: String = "simple" if simple else "full"
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		metrics[label+"_left_surface_probe"] = surface_probe(car,-0.66,-1.85)
		metrics[label+"_right_surface_probe"] = surface_probe(car,0.66,-1.85)
		var maximum_corner_gap: float = 0
		for edge: int in range(4):
			for outer: float in [0.0,1.0]:
				var gap: float = corner(car,edge,1,outer).distance_to(corner(car,(edge+1)%4,0,outer))
				maximum_corner_gap = maxf(maximum_corner_gap,gap)
				check(is_finite(gap) and gap<0.000001,"actual surrounding panels close at every corner "+label+" "+str(edge)+"/"+str(outer))
		metrics[label+"_maximum_corner_gap"] = maximum_corner_gap
		var outlines: Array = []
		for edge: int in [1,3]:
			var points: Array[Vector3] = outline(car,edge)
			var peak: float = -INF
			var flare: float = 0
			var minimum_angle: float = INF
			var maximum_angle: float = -INF
			var values: Array = []
			for index: int in range(points.size()):
				var point: Vector3 = points[index]
				peak = maxf(peak,point.x)
				flare = maxf(flare,peak-point.x)
				values.append([point.x,point.y,point.z])
				if index>0:
					var delta: Vector3 = point-points[index-1]
					if delta.z>0.001:
						var angle: float = rad_to_deg(atan2(delta.x,delta.z))
						minimum_angle = minf(minimum_angle,angle)
						maximum_angle = maxf(maximum_angle,angle)
			metrics[label+"_edge_"+str(edge)] = {"samples":points.size(),"nose_flare_metres":flare,"minimum_plan_angle":minimum_angle,"maximum_plan_angle":maximum_angle,"points":values}
			check(points.size()>=12,"actual complete side seam is populated "+label+" "+str(edge))
			check(flare<0.001,"bonnet does not widen again at the nose "+label+" "+str(edge))
			check(minimum_angle> -1 and maximum_angle<25,"side seam flows inward without a reverse hook "+label+" "+str(edge))
			check(maximum_angle-minimum_angle<12,"clean, gradual side outline "+label+" "+str(edge))
			outlines.append(points)
		var symmetry: float = 0
		if outlines[0].size() == outlines[1].size():
			for index: int in range(outlines[0].size()): symmetry = maxf(symmetry,outlines[0][index].distance_to(outlines[1][index]))
		else: symmetry = INF
		metrics[label+"_symmetry"] = symmetry
		check(symmetry<0.00001,"both physical bonnet outlines mirror exactly "+label)
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
				["marked-angle",Vector3(0,3.2,-4.8),Vector3(0,0.80,-1.0)],
				["top",Vector3(0,4.9,-1.5),Vector3(0,0.8,-1.45)],
				["reference-angle",Vector3(3.1,2.0,-4.7),Vector3(0,0.75,-0.9)],
				["nose-detail",Vector3(1.65,2.0,-3.3),Vector3(0.40,0.85,-1.75)]]
			for shot: Array in shots:
				camera.position = shot[1]
				camera.look_at(shot[2])
				await settle()
				check(viewport.get_texture().get_image().save_png(output.path_join(label+"-"+str(shot[0])+".png")) == OK,"native bonnet outline "+label+" "+str(shot[0]))
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
		showroom.camera.position = Vector3(0,3.2,-4.8)+deck
		showroom.camera.look_at(Vector3(0,0.80,-1.0)+deck)
		showroom._update_roof()
		showroom.invalidate_render()
		await settle()
		check(showroom.showroom_viewport.get_texture().get_image().save_png(output.path_join("garage-marked-angle.png")) == OK,"actual Garage at the marked front angle")
		showroom.queue_free()
		await process_frame
	var report := FileAccess.open(output+"/clean-bonnet.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_CLEAN_BONNET: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
