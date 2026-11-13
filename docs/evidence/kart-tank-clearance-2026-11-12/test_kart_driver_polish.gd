extends SceneTree
## KDP01-KDP04: native finish and actual restored cockpit articulation.
const OUT: String = "res://../docs/evidence/kart-tank-clearance-2026-11-12"
const DRIVER: ArrayMesh = preload("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
const STEERING = preload("res://vehicle/kart_steering.gd")
const BASE = preload("res://vehicle/modular_car_base.gd")
var checks: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("DRIVER_POLISH_FAIL ",label)

func run() -> void:
	check(DRIVER.get_blend_shape_count() == 6,"six intermediate left/right poses")
	check(DRIVER.get_faces().size()/3 <= 15000,"bounded native driver triangle budget")
	var old: ArrayMesh = load("res://../docs/evidence/kart-driver-polish-2026-11-12/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	for surface: int in range(DRIVER.get_surface_count()):
		var material: StandardMaterial3D = DRIVER.surface_get_material(surface)
		var arrays: Array = DRIVER.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var finite: bool = true
		for index: int in range(vertices.size()): finite = finite and vertices[index].is_finite() and normals[index].is_finite() and normals[index].length_squared() > 0.8
		check(finite,"finite geometry and unit shading normals "+material.resource_name)
		check(material.albedo_texture == null,"native text-free surface "+material.resource_name)
		if material.resource_name in ["RT_DriverSuit","RT_Gloves"]:
			check(material.metallic_specular == 0 and material.roughness == 1,"matte cloth and gloves")
			var preserved: bool = false
			for prior: int in range(old.get_surface_count()):
				if old.surface_get_material(prior).resource_name == material.resource_name:
					var bind: PackedVector3Array = old.surface_get_arrays(prior)[Mesh.ARRAY_VERTEX]
					preserved = true
					if material.resource_name == "RT_Gloves":
						for index: int in range(bind.size()): preserved = preserved and vertices[index].distance_to(bind[index]+STEERING.CENTER-STEERING.SOURCE_CENTER) < 0.000001
					else:
						var retained: Dictionary = {}
						for point: Vector3 in vertices: retained[Vector3i((point*1000000).round())] = true
						var boot_indices: PackedInt32Array = old.surface_get_arrays(prior)[Mesh.ARRAY_INDEX]
						for corner: int in range(72*3): preserved = preserved and retained.has(Vector3i((bind[boot_indices[corner]]*1000000).round()))
			check(preserved,"original boot soles and translated glove geometry remain exact "+material.resource_name)
		var shapes: Array[Array] = DRIVER.surface_get_blend_shape_arrays(surface)
		for shape: Array in shapes:
			var sound: bool = shape[Mesh.ARRAY_VERTEX].size() == vertices.size()
			for point: Vector3 in shape[Mesh.ARRAY_VERTEX]: sound = sound and point.is_finite()
			check(sound,"finite equal-topology steering pose "+material.resource_name)
			if material.resource_name == "RT_DriverSuit":
				var lower_fixed: bool = true
				var count: int = int(DRIVER.get_meta("kart_suit_static_vertices",0))
				lower_fixed = count > 0 and count < vertices.size()
				for index: int in range(count): lower_fixed = lower_fixed and shape[Mesh.ARRAY_VERTEX][index] == vertices[index]
				check(lower_fixed,"knees, feet and pelvis retain their supported pose while steering")
		if material.resource_name == "RT_Helemt":
			var outward: bool = true
			for index: int in range(vertices.size()):
				var radial := Vector3(vertices[index].x,(vertices[index].y-0.865)*0.3,vertices[index].z-0.388)
				if vertices[index].y > 0.95: outward = outward and normals[index].dot(radial) > 0
			check(outward,"helmet crown faces outward and stays opaque from overhead")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100,850)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	BASE.enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	var car := CarVisual.new()
	car.vehicle_id = "kart"
	car.simple_model = true
	world.add_child(car)
	while not car.model_ready: await process_frame
	if prepared: check(BASE.hits > 0,"actual prepared base hit")
	var wheel: Node3D = car.body.find_child("SteeringAssembly",true,false)
	var driver: MeshInstance3D = car.body.find_child("TomkartDriver",true,false)
	check(wheel != null and driver != null,"batching retains both cockpit handles")
	check(wheel.get_child_count() > 0,"wheel geometry remains in the articulated frame")
	var second := CarVisual.new()
	second.vehicle_id = "kart"
	second.simple_model = true
	root.add_child(second)
	while not second.model_ready: await process_frame
	second.visible = false
	ShowroomStudio.build(world,car)
	var camera := Camera3D.new()
	camera.fov = 32
	camera.current = true
	world.add_child(camera)
	var state := VehicleState.new()
	var frame := DriveFrame.new()
	var glove_surface: int = -1
	for surface: int in range(DRIVER.get_surface_count()):
		if DRIVER.surface_get_material(surface).resource_name == "RT_Gloves": glove_surface = surface
	var glove: PackedVector3Array = DRIVER.surface_get_arrays(glove_surface)[Mesh.ARRAY_VERTEX]
	var glove_shapes: Array[Array] = DRIVER.surface_get_blend_shape_arrays(glove_surface)
	for input: float in [-1.0,-0.75,-0.5,-0.25,0.0,0.25,0.5,0.75,1.0,0.0]:
		state.steering = input
		state.tick += 1
		car.present(Vector2.ZERO,0,state,frame)
		check(wheel.basis.is_equal_approx(STEERING.REST*Basis(Vector3.UP,-input*PI/5)),"wheel follows input about its inclined shaft")
		check(is_equal_approx(car.front_wheels[0].rotation.y,-input*0.60),"retained front-wheel steering")
		var total: float = 0
		for shape: int in range(6): total += driver.get_blend_shape_value(shape)
		check(total <= 1.00001 and total >= 0,"bounded interpolation weights")
		var error: float = 0
		var rotation: Basis = STEERING.wheel_basis(input)*STEERING.REST.inverse()
		for index: int in range(glove.size()):
			var actual: Vector3 = glove[index]*(1-total)
			for shape: int in range(6): actual += glove_shapes[shape][Mesh.ARRAY_VERTEX][index]*driver.get_blend_shape_value(shape)
			error = maxf(error,actual.distance_to(STEERING.CENTER+rotation*(glove[index]-STEERING.CENTER)))
		check(error < 0.0015,"both hands follow the rim within 1.5 mm including intermediate inputs")
		measurements.append({"input":input,"max_grip_error_mm":error*1000})
		var other: MeshInstance3D = second.body.find_child("TomkartDriver",true,false)
		var isolated: bool = true
		for shape: int in range(6): isolated = isolated and other.get_blend_shape_value(shape) == 0
		check(isolated,"another car sharing the mesh stays in its own pose")
		if DisplayServer.get_name() != "headless" and input in [-1.0,-0.5,0.0,0.5,1.0]:
			for shot: Array in [["cockpit",Vector3(1.0,.95,-.9),Vector3(0,.56,-.25)],["overhead",Vector3(0,4.2,2.0),Vector3(0,.3,0)]]:
				camera.position = shot[1]
				camera.look_at(shot[2])
				for wait: int in range(5): await process_frame; await RenderingServer.frame_post_draw
				check(viewport.get_texture().get_image().save_png(OUT+"/steering-"+("prepared-" if prepared else "direct-")+shot[0]+"-"+str(input)+".png") == OK,"native steering capture")
	car.present(Vector2.ZERO,0,state,frame)
	check(wheel.basis.is_equal_approx(STEERING.REST),"centre restores without accumulated rotation")
	check(driver.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"posed driver retains live shadow")
	for child: MeshInstance3D in wheel.find_children("*","MeshInstance3D",true,false): check(child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"rotating wheel retains live shadow")
	second.free()
	viewport.free()
	FileAccess.open(OUT+"/steering-measurements-"+("prepared" if prepared else "direct")+".json",FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	print("KART_DRIVER_POLISH ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
