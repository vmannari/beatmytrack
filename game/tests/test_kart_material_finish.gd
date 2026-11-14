extends SceneTree
## VQR03: native driver material bindings preserve mesh/morph data and isolation.
const DRIVER = preload("res://vehicle/kart_driver.gd")
const STEERING = preload("res://vehicle/kart_steering.gd")
const ROOT: String = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("KART_FINISH_FAIL ",message)

func geometry(mesh: ArrayMesh) -> PackedByteArray:
	var arrays: Array = []
	for surface: int in range(mesh.get_surface_count()):
		arrays.append(mesh.surface_get_arrays(surface))
		arrays.append(mesh.surface_get_blend_shape_arrays(surface))
	return var_to_bytes(arrays)

func suit_parts(driver: MeshInstance3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = [driver]
	var fixed := driver.get_node_or_null("DriverStaticSuit") as MeshInstance3D
	if fixed != null: result.append(fixed)
	return result

func own(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		own(child,owner)

func run() -> void:
	var hashes: Dictionary = {}
	var original: Dictionary = {}
	for file: String in ["driver.res","driver_steering.res","driver_static.res","helmet_static.res"]:
		hashes[file] = FileAccess.get_sha256(ROOT+file)
		original[file] = geometry(load(ROOT+file))
	var containers: Array[Node3D] = []
	var materials: Array[Material] = []
	for simple: bool in [false,true]:
		var body := Node3D.new()
		root.add_child(body)
		containers.append(body)
		DRIVER.build(body,CompactFinish.rubber(Color("20272a")),simple)
		var driver := body.get_node("TomkartDriver") as MeshInstance3D
		check(driver.mesh == load(ROOT+("driver_steering.res" if simple else "driver.res")),"original native driver resource retained")
		check(driver.mesh.get_blend_shape_count() == STEERING.STEPS*2,"all steering samples retained")
		var suit: Material
		for part: MeshInstance3D in suit_parts(driver):
			for surface: int in range(part.mesh.get_surface_count()):
				var source: Material = part.mesh.surface_get_material(surface)
				var active: Material = part.get_active_material(surface)
				check(active != source,"finish uses instance binding")
				check(source is StandardMaterial3D,"imported native material remains unchanged")
				check(active.resource_name == source.resource_name,"material role preserved")
				if source.resource_name == "RT_DriverSuit":
					check(active is ShaderMaterial and active.shader == DRIVER.CLOTH,"garment finish used")
					check(suit == null or suit == active,"static and moving panels share finish")
					suit = active
				elif source.resource_name == "RT_Gloves":
					check(active is StandardMaterial3D and active.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,"glove remains opaque")
		materials.append(suit)
		var helmet := driver.get_node("HelmetStatic") as MeshInstance3D
		check(helmet.mesh == load(ROOT+"helmet_static.res"),"helmet native resource retained")
		for surface: int in range(helmet.mesh.get_surface_count()):
			var source: Material = helmet.mesh.surface_get_material(surface)
			if source.resource_name == "HelmetVisor":
				var visor := helmet.get_active_material(surface) as StandardMaterial3D
				check(visor != null and visor != source,"visor uses instance finish")
				check(visor.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(visor.albedo_color.a,1.0),"visor stays opaque")
			else:
				check(helmet.get_active_material(surface) == source,"shell, hardware and seals preserve original finish")
		for input: float in [-1.0,-0.65,0.0,0.65,1.0]:
			STEERING.present(null,driver,input)
			check(driver.get_active_material(1) == suit,"material binding remains during steering")
		# Prepared bases serialize these exact per-surface bindings.
		own(body,body)
		var packed := PackedScene.new()
		check(packed.pack(body) == OK,"finished driver packs")
		var restored := packed.instantiate()
		var restored_driver := restored.get_node("TomkartDriver") as MeshInstance3D
		check(restored_driver.get_active_material(1) is ShaderMaterial,"garment finish survives prepared scene roundtrip")
		var restored_helmet := restored_driver.get_node("HelmetStatic") as MeshInstance3D
		check(restored_helmet.get_surface_override_material(2) != null,"visor finish survives prepared scene roundtrip")
		restored.free()
	check(materials[0] != materials[1],"separate cars do not share mutable finish instances")
	for file: String in hashes:
		check(FileAccess.get_sha256(ROOT+file) == hashes[file],"native mesh file is byte exact "+file)
		check(geometry(load(ROOT+file)) == original[file],"positions, normals, UVs, colours, topology and all morph arrays unchanged "+file)
	for body: Node3D in containers: body.free()
	await process_frame
	print("KART_MATERIAL_FINISH: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
