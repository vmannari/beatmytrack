extends SceneTree
## Actual projected mesh coverage, retained viewing controls and saved return view.
const Fixture = preload("res://tests/test_customisation_carousel.gd")
var page: GaragePage
var checks: int = 0
var failures: int = 0
var output: String
var samples: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	while page._workbench_focus_pending or page._menu_motion!=null or page.showroom.camera_motion!=null and page.showroom.camera_motion.is_running(): await process_frame
	for tick: int in range(10): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var deadline: int = Time.get_ticks_msec()+20000
	while page.livery_menu.pattern_icons.busy and Time.get_ticks_msec()<deadline: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)

func mesh_projection() -> Rect2:
	var box: Rect2
	var first: bool = true
	for mesh: MeshInstance3D in page.showroom.car.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not mesh.is_visible_in_tree(): continue
		var bounds: AABB = mesh.mesh.get_aabb()
		for x: float in [bounds.position.x,bounds.end.x]:
			for y: float in [bounds.position.y,bounds.end.y]:
				for z: float in [bounds.position.z,bounds.end.z]:
					var at: Vector2 = page.showroom.camera.unproject_position(mesh.global_transform*Vector3(x,y,z))
					box = Rect2(at,Vector2.ZERO) if first else box.expand(at)
					first = false
	return box

func measure(label: String) -> void:
	var view: CarShowroom = page.showroom
	var box: Rect2 = mesh_projection()
	var pixels: Vector2 = Vector2(view.showroom_viewport.size)
	var angle: float = rad_to_deg(asin(view.camera.basis.z.y))
	var fraction: float = box.size.y/pixels.y
	samples.append({"label":label,"vehicle":page.vehicle_id,"window":str(root.size),"viewport":str(pixels),"height_fraction":fraction,"width_fraction":box.size.x/pixels.x,"elevation_degrees":angle,"bounds":str(box)})
	check(Rect2(Vector2(4,64),pixels-Vector2(8,72)).encloses(box),"whole car clears the heading and viewport edges "+label)
	check(fraction>=0.50,"car uses at least half the available height "+label)
	if page.vehicle_id=="compact" and root.size.x>=1280: check(fraction>=0.60,"Compact uses the main paint view height "+label)
	check(angle>=29.9 and angle<=42.0,"paint entry has a raised three-quarter angle "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().music_enabled = false
	output = "res://../docs/evidence/garage-paint-framing-2026-10-26/native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.theme = MenuStyle.theme()
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	VehicleCatalog.selected = "compact"
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	var shop := Fixture.Shop.new()
	host.add_child(shop)
	page = GaragePage.new()
	page.records = LocalRecords.new("user://paint_framing_"+TrackLibrary.unique_id()+".json")
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.pattern = "apex_twin"
	paint.colors.body = "a44844"
	paint.colors.accent = "ebe3d0"
	page.records.settings.vehicle_liveries = {"compact":paint}
	page.economy = shop
	host.add_child(page)
	MenuStyle.fill(page)
	page.offset_left = 20
	page.offset_right = -20
	page.offset_top = 112
	page.offset_bottom = -20
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for index: int in range(VehicleCatalog.IDS.size()):
			page._show_section("cars")
			await settle()
			var home: Transform3D = page.showroom.camera.transform
			var orbit: Vector3 = Vector3(page.showroom.yaw,page.showroom.elevation,page.showroom.zoom)
			page.open_car(index)
			page._set_customise_tab("livery")
			await settle()
			var label: String = page.vehicle_id+"/"+str(dimensions.x)
			measure(label)
			var from_home := Vector2(home.basis.z.x,home.basis.z.z).normalized()
			var direction: Vector3 = page.showroom.camera.basis.z
			check(from_home.dot(Vector2(direction.x,direction.z).normalized())>0.9999,"paint entry retains horizontal viewing direction "+label)
			if dimensions.x==1720 or index==0: await capture("paint-"+page.vehicle_id+"-"+str(dimensions.x))
			var transform: Transform3D = page.showroom.camera.transform
			page._preview_livery(2)
			page._preview_livery(3)
			check(page.showroom.camera.transform.is_equal_approx(transform),"browsing paints keeps the fitted camera "+label)
			page._set_customise_tab("colours")
			await settle()
			check(page.showroom.camera.transform.is_equal_approx(transform),"Colours keeps the same fitted view "+label)
			page._show_section("cars")
			await settle()
			check(page.showroom.camera.transform.is_equal_approx(home) and Vector3(page.showroom.yaw,page.showroom.elevation,page.showroom.zoom)==orbit,"leaving restores exact Garage view "+label)
	page.open_car(0)
	await settle()
	page.showroom.rotate_view(Vector2(30,8))
	page.showroom.zoom_by(0.9)
	var rotated: Vector3 = page.showroom.camera.basis.z
	var zoom: float = page.showroom.zoom
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await settle()
	check(page.showroom.camera.basis.z.dot(rotated)>0.99999 and page.showroom.zoom==zoom,"resize retains player angle and zoom")
	page._preview_livery(4)
	check(page.showroom.camera.basis.z.dot(rotated)>0.99999,"later choice retains rotated view")
	host.queue_free()
	for tick: int in range(8): await process_frame
	if DisplayServer.get_name()!="headless": await app_capture()
	var file := FileAccess.open(output.path_join("coverage.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"))
	print("GARAGE_PAINT_FRAMING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func app_capture() -> void:
	var directory: String = "user://paint_framing_app_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.pattern = "apex_twin"
	paint.colors.body = "a44844"
	paint.colors.accent = "ebe3d0"
	app.records.settings.vehicle_liveries = {"compact":paint}
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	var deadline: int = Time.get_ticks_msec()+30000
	page = null
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(app.root_ui): page = app.root_ui.find_child("GaragePage",true,false)
		if app.screen=="garage" and is_instance_valid(page) and page.is_visible_in_tree(): break
		await process_frame
	var ready: bool = app.screen=="garage" and is_instance_valid(page) and page.is_visible_in_tree()
	check(ready,"actual App prepares Garage")
	if ready:
		page.open_car(0)
		await settle()
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1720,960)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			await settle()
			measure("actual-app/"+str(dimensions.x))
			await capture("paint-app-"+str(dimensions.x))
	app.queue_free()
	await process_frame
