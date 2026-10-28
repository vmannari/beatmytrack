extends SceneTree
## Inspect actual cloth sections and material, independent of the authoring profile.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-driver-shape-2026-10-25/shape"
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func section(part: MeshInstance3D, columns: int, rows: int, fraction: float) -> Vector2:
	var points: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var row: int = roundi(rows*fraction)
	var center := Vector3.ZERO
	for col: int in range(columns): center += points[row*(columns+1)+col]/columns
	var radius := Vector2(INF,0)
	for col: int in range(columns):
		var distance: float = center.distance_to(points[row*(columns+1)+col])
		radius.x = minf(radius.x,distance)
		radius.y = maxf(radius.y,distance)
	return radius

func torso_width(mesh: TriangleMesh, y: float, z: float) -> float:
	var a: Dictionary = mesh.intersect_ray(Vector3(-0.5,y,z),Vector3.RIGHT)
	var b: Dictionary = mesh.intersect_ray(Vector3(0.5,y,z),Vector3.LEFT)
	return Vector3(a.position).distance_to(b.position) if not a.is_empty() and not b.is_empty() else 0.0

func cloth_backing(car: CarVisual) -> Dictionary:
	var cloth: Array[TriangleMesh] = []
	var overlays: Array[MeshInstance3D] = []
	for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if str(part.name).begins_with("TailoredRaceSuit") or str(part.name).begins_with("UpperSleeveContinuous") or str(part.name).begins_with("ContinuousTrouserLeg"):
			cloth.append(part.mesh.generate_triangle_mesh())
		if str(part.name).begins_with("SuitChestPanel") or str(part.name).begins_with("SuitShoulderYoke") or str(part.name).begins_with("TrouserKneePanel") or str(part.name).begins_with("SleeveCuff"):
			overlays.append(part)
	var samples: int = 0
	var minimum: float = INF
	var maximum: float = -INF
	var problems: Dictionary = {}
	for part: MeshInstance3D in overlays:
		var arrays: Array = part.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index: int in range(0,indices.size(),9):
			var point := Vector3.ZERO
			var normal := Vector3.ZERO
			for corner: int in range(3):
				point += points[indices[index+corner]]/3
				normal += normals[indices[index+corner]]
			normal = normal.normalized()
			var distance: float = INF
			for mesh: TriangleMesh in cloth:
				var hit: Dictionary = mesh.intersect_ray(point+normal*0.02,-normal)
				if not hit.is_empty(): distance = minf(distance,(point+normal*0.02-Vector3(hit.position)).dot(normal)-0.02)
			samples += 1
			minimum = minf(minimum,distance)
			maximum = maxf(maximum,distance)
			if not is_finite(distance) or distance < -0.0005 or distance > 0.006: problems[str(part.name)] = int(problems.get(str(part.name),0))+1
	return {"samples":samples,"minimum":minimum,"maximum":maximum,"problems":problems}

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	if "--unbaked" in OS.get_cmdline_user_args() or "--old-shape-source" in OS.get_cmdline_user_args(): preload("res://vehicle/kart_geometry.gd").use_baked = false
	if "--old-shape-source" in OS.get_cmdline_user_args():
		var source: GDScript = load("res://vehicle/kart_driver.gd")
		source.source_code = FileAccess.get_file_as_string("res://../docs/evidence/kart-driver-shape-2026-10-25/before/game/vehicle/kart_driver.gd")
		assert(source.reload() == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var label: String = "simple" if simple else "full"
		var torso: MeshInstance3D = car.find_child("TailoredRaceSuit*",true,false)
		var mesh: TriangleMesh = torso.mesh.generate_triangle_mesh()
		var waist: float = torso_width(mesh,0.430,0.10)
		var chest: float = torso_width(mesh,0.540,0.22)
		check(waist >= 0.265 and waist <= 0.305,label+" defined waist remains substantial")
		check(chest >= 0.335 and chest/waist >= 1.18,label+" ribcage is visibly broader than waist")
		var material: StandardMaterial3D = torso.material_override
		check(material.roughness >= 0.98 and material.metallic_specular <= 0.06,label+" opaque matte cloth finish")
		check(car.find_children("SuitChestPanel*","MeshInstance3D",true,false).size() == 2,label+" paired fitted chest panels")
		check(car.find_children("TrouserKneePanel*","MeshInstance3D",true,false).size() == 2,label+" paired knee cloth panels")
		var sleeves: Array = []
		for part: MeshInstance3D in car.find_children("UpperSleeveContinuous*","MeshInstance3D",true,false):
			var columns: int = 12 if simple else 24
			var rows: int = 16 if simple else 32
			var upper: Vector2 = section(part,columns,rows,0.25)
			var elbow: Vector2 = section(part,columns,rows,0.50)
			var forearm: Vector2 = section(part,columns,rows,0.75)
			var wrist: Vector2 = section(part,columns,rows,1.0)
			check(elbow.y/upper.y < 0.82,label+" sleeve has a distinct elbow below upper arm")
			check(forearm.y/elbow.y > 1.05,label+" forearm has its own volume")
			check(forearm.y/wrist.y > 1.30,label+" forearm tapers into wrist")
			check(forearm.y/forearm.x > 1.07,label+" forearm section is shaped instead of circular")
			sleeves.append({"upper":upper,"elbow":elbow,"forearm":forearm,"wrist":wrist})
		var legs: Array = []
		for part: MeshInstance3D in car.find_children("ContinuousTrouserLeg*","MeshInstance3D",true,false):
			var columns: int = 12 if simple else 24
			var rows: int = 14 if simple else 28
			var thigh: Vector2 = section(part,columns,rows,0.25)
			var calf: Vector2 = section(part,columns,rows,0.75)
			var ankle: Vector2 = section(part,columns,rows,1.0)
			check(thigh.y/calf.y > 1.25,label+" thigh and calf have distinct volumes")
			check(calf.y/ankle.y > 1.28,label+" calf tapers into ankle")
			legs.append({"thigh":thigh,"calf":calf,"ankle":ankle})
		check(sleeves.size() == 2 and legs.size() == 2,label+" both sides inspected")
		var backing: Dictionary = cloth_backing(car)
		check(int(backing.samples) >= (60 if simple else 200) and backing.problems.is_empty(),label+" panel/cuff faces stay on actual cloth "+JSON.stringify(backing.problems))
		measurements[label] = {"waist_width":waist,"chest_width":chest,"sleeves":sleeves,"legs":legs,"panel_backing":backing}
		car.free()
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("KART_DRIVER_SHAPE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
