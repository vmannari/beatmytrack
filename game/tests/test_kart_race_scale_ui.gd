extends "res://tests/test_kart_refinement_ui.gd"
## Actual race before/after comparison in one frozen scene and unchanged camera.
const BEFORE = "res://../docs/evidence/kart-driver-race-scale-2026-11-12/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
func pixels(camera: Camera3D, node: MeshInstance3D) -> Rect2:
	var first: bool = true
	var result := Rect2()
	for surface: int in range(node.mesh.get_surface_count()):
		for point: Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var pixel: Vector2 = camera.unproject_position(node.global_transform*point)
			if first: result = Rect2(pixel,Vector2.ZERO); first = false
			else: result = result.expand(pixel)
	return result
func capture(label: String) -> void:
	if label!="race": super.capture(label); return
	var app: Node = root.find_child("CircuitApp",true,false)
	assert(app!=null and app.game!=null)
	var game: Node = app.game
	var camera: Camera3D = game.camera
	var car: CarVisual = game.car
	var driver: MeshInstance3D = car.find_child("TomkartDriver",true,false)
	var helmet: MeshInstance3D = driver.find_child("HelmetStatic",true,false)
	var current_driver: Mesh = driver.mesh
	var current_helmet: Mesh = helmet.mesh
	var old_processing: bool = game.is_processing()
	game.set_process(false)
	var camera_transform: Transform3D = camera.global_transform
	var car_transform: Transform3D = car.global_transform
	var extent: float = camera.size
	driver.mesh = load(BEFORE+"driver.res")
	helmet.mesh = load(BEFORE+"helmet_static.res")
	await settle(3)
	var before: Rect2 = pixels(camera,helmet)
	check(root.get_texture().get_image().save_png(output+"/race-before-size.png")==OK,"actual race original driver capture")
	driver.mesh = current_driver
	helmet.mesh = current_helmet
	await settle(3)
	var after: Rect2 = pixels(camera,helmet)
	check(camera.global_transform==camera_transform and camera.size==extent,"actual race comparison preserves camera and view extent")
	check(car.global_transform==car_transform,"actual race comparison preserves kart scale and position")
	check(after.size.x/before.size.x>=1.19 and after.size.y/before.size.y>=1.19,"actual race visibly enlarges helmet relative to the unchanged kart")
	FileAccess.open(output+"/race-size.json",FileAccess.WRITE).store_string(JSON.stringify({"helmet_before_pixels":str(before.size),"helmet_after_pixels":str(after.size),"width_ratio":after.size.x/before.size.x,"height_ratio":after.size.y/before.size.y,"car_scale":str(car.scale),"camera_extent":extent,"driver_scale":str(driver.scale)},"\t"))
	super.capture(label)
	game.set_process(old_processing)
