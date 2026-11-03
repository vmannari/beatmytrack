extends SceneTree
## Measure the actual hatch saddles against the original cabin mesh, with both
## procedural and prepared kit data. No part is judged by its name alone.
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", label)

func interval(mesh: TriangleMesh, at: Vector3) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for side: float in [-1, 1]:
		var hit: Dictionary = mesh.intersect_ray(at + Vector3(0, 0, side * 3.0), Vector3(0, 0, -side))
		if hit.is_empty(): continue
		var z: float = (hit.position as Vector3).z
		low = minf(low, z)
		high = maxf(high, z)
	return Vector2(low, high)

func run() -> void:
	var source: bool = "--source" in OS.get_cmdline_user_args()
	if source: CompactKits.use_baked = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	CompactKits.meshes.clear()
	for simple: bool in [false, true]:
		var stock := CarVisual.new()
		stock.editable_kits = true
		stock.simple_model = simple
		stock.batch_parts = false
		root.add_child(stock)
		var shell: Array[TriangleMesh] = []
		var detail: String = "_simple" if simple else ""
		for name: String in ["cabin_rear", "cabin_rear_corner_left", "cabin_rear_corner_right"]:
			var original: ArrayMesh = CompactCoachwork.meshes.get(name + detail)
			if original != null: shell.append(original.generate_triangle_mesh())
		check(not shell.is_empty(), "original rear cabin surface present " + str(simple))
		for kind: String in ["touring", "splitwing"]:
			var car := CarVisual.new()
			car.editable_kits = true
			car.simple_model = simple
			car.batch_parts = false
			car.customisation = VehicleCustomisation.defaults()
			car.customisation.aero = kind
			root.add_child(car)
			var profile: Dictionary = CompactAero.PROFILES[kind]
			check(profile.mount == "hatch", kind + " uses a sloping hatch mount")
			for side: float in [-1, 1]:
				var mount: Vector3 = CompactAero.mount_point(kind, side)
				check(mount.y > 1.08 and mount.y < 1.43, kind + " saddle is on the sloped rear surface")
				var prefix: String = "aero6/" + kind + "/" + str(side) + "/"
				var suffix: String = "/simple" if simple else ""
				var pad: ArrayMesh = CompactKits.meshes.get(prefix + "seal" + suffix)
				check(pad != null, kind + " saddle mesh exists " + str(side) + "/" + str(simple))
				if pad == null: continue
				var pad_mesh: TriangleMesh = pad.generate_triangle_mesh()
				var min_embed: float = INF
				var tested: int = 0
				for dx: float in [-0.015, 0.0, 0.015]:
					for dy: float in [-0.020, 0.0, 0.020]:
						var at := Vector3(mount.x + dx, mount.y + dy, mount.z)
						var base_z: float = -INF
						for surface: TriangleMesh in shell:
							var base: Vector2 = interval(surface, at)
							if base.is_finite(): base_z = maxf(base_z, base.y)
						var saddle: Vector2 = interval(pad_mesh, at)
						check(base_z > -INF and saddle.is_finite(), kind + " actual hatch and saddle ray hits")
						if base_z == -INF or not saddle.is_finite(): continue
						var embed: float = base_z - saddle.x
						min_embed = minf(min_embed, embed)
						tested += 1
						check(embed >= -0.001, kind + " saddle reaches actual cabin surface")
						check(saddle.y >= base_z + 0.001, kind + " saddle extends outside actual cabin")
				rows.append({"kind":kind,"simple":simple,"side":side,"sample_count":tested,"min_embed_m":min_embed})
			car.queue_free()
			await process_frame
		stock.queue_free()
		await process_frame
	print("RALLY_SPOILER_MOUNTS: ", checks, " checks, ", failures, " failures; source=", source, " ", JSON.stringify(rows))
	quit(1 if failures else 0)
