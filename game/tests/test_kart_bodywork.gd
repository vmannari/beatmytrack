extends SceneTree
## Independent checks of the actual moulded shells and their fitted trim.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-shaped-bodywork-2026-10-26/bodywork"
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func hit(part: MeshInstance3D, origin: Vector3, direction: Vector3) -> Dictionary:
	return part.mesh.generate_triangle_mesh().intersect_ray(origin,direction)

func boundary_edges(mesh: Mesh) -> int:
	var edges: Dictionary = {}
	var faces: PackedVector3Array = mesh.get_faces()
	for face: int in range(faces.size()/3):
		for corner: int in range(3):
			var a: Vector3 = faces[face*3+corner].snapped(Vector3.ONE*0.00001)
			var b: Vector3 = faces[face*3+(corner+1)%3].snapped(Vector3.ONE*0.00001)
			if a==b: continue
			var key: String = str(a)+":"+str(b) if a<b else str(b)+":"+str(a)
			edges[key] = int(edges.get(key,0))+1
	var count: int = 0
	for uses: int in edges.values():
		if uses!=2: count += 1
	return count

func crown(part: MeshInstance3D, z: float, half_span: float) -> float:
	var heights: Array[float] = []
	for step: int in range(7):
		var found: Dictionary = hit(part,Vector3(lerpf(-half_span,half_span,step/6.0),2,z),Vector3.DOWN)
		if found.is_empty(): return INF
		heights.append(found.position.y)
	return heights.max()-heights.min()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if "--unbaked" in OS.get_cmdline_user_args(): preload("res://vehicle/kart_geometry.gd").use_baked = false
	if "--before-shapes" in OS.get_cmdline_user_args():
		for file: String in ["kart_model.gd","kart_detail.gd"]:
			var script: GDScript = load("res://vehicle/"+file)
			script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/kart-shaped-bodywork-2026-10-26/before/game/vehicle/"+file)
			assert(script.reload()==OK)
		preload("res://vehicle/kart_geometry.gd").use_baked = false
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var nose: MeshInstance3D = car.find_child("SculptedFrontFairing",true,false)
		var fairing: MeshInstance3D = car.find_child("NassauFairing",true,false)
		var pod: MeshInstance3D = car.find_child("FormedSidePod",true,false)
		var tank: MeshInstance3D = car.find_child("FuelTank",true,false)
		var airbox: MeshInstance3D = car.find_child("Airbox",true,false)
		var spans: Dictionary = {"bumper":crown(nose,-1.29,0.30),"fairing":crown(fairing,-0.64,0.10),"pod":crown(pod,-0.12,0.075)}
		for label: String in spans: check(spans[label]<0.0001,"broad planar crown instead of inflated cross-section: "+label)
		var wall: Dictionary = hit(tank,Vector3(0.30,0.22,-0.28)-tank.position,Vector3.LEFT)
		var shoulder: Dictionary = hit(tank,Vector3(0.30,0.305,-0.26)-tank.position,Vector3.LEFT)
		check(not wall.is_empty() and not shoulder.is_empty(),"tank side and shoulder have actual surfaces")
		if not wall.is_empty() and not shoulder.is_empty(): check(shoulder.position.x < wall.position.x*0.78,"fuel tank shoulder narrows into the filler")
		var tank_closed: int = boundary_edges(tank.mesh)
		check(tank_closed==0,"fuel tank has a closed manufactured shell")
		var airbox_closed: int = boundary_edges(airbox.mesh)
		check(airbox_closed==0,"airbox has a closed manufactured shell")
		var airbox_span: float = crown(airbox,0,0.05)
		check(airbox_span<0.0001,"airbox has a broad flat lid")
		measurements["simple" if simple else "full"] = {"crown_height_variation_m":spans,"tank_open_edges":tank_closed,"airbox_open_edges":airbox_closed,"airbox_lid_variation_m":airbox_span}
		if DisplayServer.get_name()!="headless":
			# Inspection-only cutaway: show the actual tank otherwise hidden by the fairing.
			var world := Node3D.new()
			root.add_child(world)
			car.reparent(world)
			ShowroomStudio.build(world,car)
			for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
				part.visible = part.name in ["FuelTank","FuelCap","FuelLine"]
			var camera := Camera3D.new()
			world.add_child(camera)
			camera.current = true
			camera.fov = 30
			camera.look_at_from_position(Vector3(-0.45,0.60,-0.78)*HandlingConfig.BODY_SCALE,Vector3(0,0.25,-0.27)*HandlingConfig.BODY_SCALE)
			for frame: int in range(8): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join(("simple" if simple else "full")+"-fuel-tank-isolated.png"))==OK,"native actual-tank cutaway capture")
			world.free()
		else:
			car.free()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("KART_BODYWORK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
