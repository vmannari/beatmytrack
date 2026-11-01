extends SceneTree
## Check the actual front panel and fairing mesh overlap for every nose and LOD.
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for simple: bool in [false, true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.editable_kits = true
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for option: Array in VehicleCustomisation.options("hood", "kart"):
			car.graphics.restore_originals()
			var parts: Dictionary = VehicleCustomisation.defaults()
			parts.hood = option[0]
			car.change_kit_parts(parts)
			var suffix: String = preload("res://vehicle/kart_kits.gd").suffix(str(option[0]))
			var nose: MeshInstance3D = car.body.find_child("SculptedFrontFairing"+suffix, true, false)
			var fairing: MeshInstance3D = car.body.find_child("NassauFairing"+suffix, true, false)
			for z: float in [-1.283, -1.28]:
				var top: Dictionary = nose.mesh.generate_triangle_mesh().intersect_ray(Vector3(0,1,z),Vector3.DOWN)
				var bottom: Dictionary = nose.mesh.generate_triangle_mesh().intersect_ray(Vector3(0,-1,z),Vector3.UP)
				var upper: Dictionary = fairing.mesh.generate_triangle_mesh().intersect_ray(Vector3(0,1,z),Vector3.DOWN)
				var lower: Dictionary = fairing.mesh.generate_triangle_mesh().intersect_ray(Vector3(0,-1,z),Vector3.UP)
				var ok: bool = not top.is_empty() and not bottom.is_empty() and not upper.is_empty() and not lower.is_empty()
				if ok: ok = lower.position.y < top.position.y and upper.position.y > bottom.position.y
				checks += 1
				if not ok:
					failures += 1
					print("FAIL join ", option[0], " simple=",simple," z=",z," nose=",top,"/",bottom," fairing top=",upper," bottom=",lower)
		car.free()
	print("KART_NOSE_JOIN: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
