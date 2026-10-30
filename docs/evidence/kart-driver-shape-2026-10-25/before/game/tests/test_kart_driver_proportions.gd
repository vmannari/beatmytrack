extends SceneTree
## Measure actual prepared cloth centre lines, independent of the authoring helpers.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-driver-proportions-2026-10-25/proportions"
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func centres(part: MeshInstance3D, columns: int) -> PackedVector3Array:
	var vertices: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var result := PackedVector3Array()
	for row: int in range(vertices.size()/(columns+1)):
		var center := Vector3.ZERO
		# Omit the duplicate seam vertex so the average stays on the cloth axis.
		for col: int in range(columns): center += vertices[row*(columns+1)+col]
		result.append(part.transform*(center/columns))
	return result

func at_height(points: PackedVector3Array, y: float) -> Vector3:
	for index: int in range(points.size()-1):
		if points[index].y <= y and points[index+1].y >= y:
			return points[index].lerp(points[index+1],inverse_lerp(points[index].y,points[index+1].y,y))
	return Vector3.INF

func path_length(points: PackedVector3Array) -> float:
	var length: float = 0
	for index: int in range(points.size()-1): length += points[index].distance_to(points[index+1])
	return length

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	if "--unbaked" in OS.get_cmdline_user_args(): preload("res://vehicle/kart_geometry.gd").use_baked = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var label: String = "simple" if simple else "full"
		var torso: MeshInstance3D = car.find_child("TailoredRaceSuit*",true,false)
		var spine: PackedVector3Array = centres(torso,16 if simple else 32)
		var hip: Vector3 = at_height(spine,0.345)
		var shoulder: Vector3 = at_height(spine,0.635)
		var torso_length: float = hip.distance_to(shoulder)
		check(torso_length >= 0.39 and torso_length <= 0.46,label+" seated torso has a substantial hip-to-shoulder span")
		var legs: Array[Dictionary] = []
		for part: MeshInstance3D in car.find_children("ContinuousTrouserLeg*","MeshInstance3D",true,false):
			var path: PackedVector3Array = centres(part,12 if simple else 24)
			var length: float = path_length(path)
			var knee: Vector3 = path[path.size()/2]
			var thigh: Vector3 = knee-path[0]
			var shin: Vector3 = path[-1]-knee
			var bend: float = rad_to_deg(thigh.angle_to(shin))
			var ratio: float = length/torso_length
			check(ratio >= 1.45 and ratio <= 1.90,label+" leg length is balanced against the seated torso")
			check(length >= 0.66 and length <= 0.76,label+" actual trouser centre line is shorter")
			check(thigh.length()/shin.length() >= 0.80 and thigh.length()/shin.length() <= 1.15,label+" thigh and shin have balanced lengths")
			check(bend >= 18 and bend <= 45,label+" knees bend naturally instead of stretching toward the pedals")
			check(absf(path[-1].z+0.75) < 0.001 and absf(path[-1].y-0.225) < 0.001,label+" ankles retain the pedal/boot location")
			legs.append({"length":length,"torso_ratio":ratio,"knee_bend_degrees":bend,"thigh":thigh.length(),"shin":shin.length()})
		check(legs.size() == 2 and absf(float(legs[0].length)-float(legs[1].length)) < 0.0001,label+" legs retain symmetric proportions")
		measurements[label] = {"hip":hip,"shoulder":shoulder,"torso_length":torso_length,"legs":legs}
		car.free()
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("KART_DRIVER_PROPORTIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
