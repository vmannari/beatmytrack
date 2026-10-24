extends SceneTree
## Broad surface-only rinsing, connected endpoints, actual visible spray and motion.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/hose-spray-refinement-2026-10-24"
var page: GaragePage
var metrics: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func settle() -> void:
	while page._menu_motion != null: await frame()
	for tick: int in range(6): await frame()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for tick: int in range(4): await frame()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func mathematical_coverage() -> void:
	var effect := VehicleWeathering.new()
	var initial: Dictionary = effect.snapshot()
	effect.restore(initial)
	effect.bounds = AABB(Vector3(-2,-2,-2),Vector3(4,4,4))
	var point: Vector3 = effect.bounds.position+effect.bounds.size*Vector3(7,10,7)/15.0
	effect.wash(point,0.8,"hose",Vector3.UP)
	var broad: PackedByteArray = effect.slow_wash_image.get_data()
	check(broad[10*256+7*16+10] > 0,"new fan cleans tangential cells 0.8 model-units from the aim")
	check(broad[12*256+7*16+7] == 0,"wide fan never penetrates to the opposite surface")
	check(broad[10*256+7*16+12] == 0,"spray still stops outside its footprint")
	var primary: PackedByteArray = effect.wash_image.get_data()
	check(primary[10*256+7*16+7] <= 6,"large spray retains very slow heavy-grime rate")
	effect.restore(initial)
	effect.begin_wash_batch()
	for tick: int in range(80): effect.wash(point,0.01,"hose",Vector3.UP)
	effect.end_wash_batch()
	check(effect.slow_wash_image.get_data() == broad and effect.wash_image.get_data() == primary,"split surface spray preserves exact work in both layers")
	var normal_miss: Dictionary = effect.snapshot()
	effect.wash(point+Vector3.UP*0.8,0.8,"hose",Vector3.UP)
	check(effect.slow_wash_image.get_data()[10*256+7*16+7] == broad[10*256+7*16+7],"depth fence protects panels behind the aimed plane")
	check(normal_miss != effect.snapshot(),"depth-fenced spray still works on its own plane")

func mouse(view: CarShowroom, pixel: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pixel
	event.pressed = pressed
	view.gui_input.emit(event)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().music_enabled = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	mathematical_coverage()
	var folder: String = "user://hose_refinement_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	page = GaragePage.new()
	page.records = records
	page.theme = MenuStyle.theme()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	await settle()
	page._show_section("care")
	await settle()
	page._select_wash_tool("hose")
	var view: CarShowroom = page.showroom
	view.set_process(false)
	view.yaw = 0.3
	view.elevation = 0.93
	view.set_zoom(0.95)
	var point := Vector3(0,1.44,0.1)
	var pixel: Vector2 = view.camera.unproject_position(view.car.body.global_transform*point)*view.size/Vector2(view.showroom_viewport.size)
	mouse(view,pixel,true)
	view._process(0.05)
	var effect: Node3D = view.wash_effect
	var rig: Node3D = effect.hose
	var resources: Array = [rig.cable.mesh,rig.spray.multimesh,rig.mist.mesh]
	var child_count: int = rig.get_child_count()
	check(rig.reel.visible and rig.cable.visible,"active spray has a reel and a continuous hose")
	check(rig.cable_points.size() == 49,"one fixed continuous tube path")
	var start: Vector3 = rig.nozzle.global_transform*Vector3(0,0,0.1)
	var end: Vector3 = rig.reel.global_transform*rig.REEL_OUTLET
	check((rig.cable_points[0] as Vector3).distance_to(rig.to_local(start)) < 0.0001,"hose starts inside nozzle coupling")
	check((rig.cable_points[48] as Vector3).distance_to(rig.to_local(end)) < 0.0001,"hose finishes at the fixed reel outlet")
	var reel_pose: Transform3D = rig.reel.global_transform
	var water_on := PackedByteArray()
	if DisplayServer.get_name() != "headless":
		await capture("wide-spray-roof")
		water_on = view.showroom_viewport.get_texture().get_image().get_data()
		rig.spray.hide()
		rig.mist.hide()
		effect.water.hide()
		view.invalidate_render()
		for tick: int in range(5): await frame()
		var dry: Image = view.showroom_viewport.get_texture().get_image()
		var wet := Image.create_from_data(dry.get_width(),dry.get_height(),false,dry.get_format(),water_on)
		var changed: int = 0
		var lower := Vector2i(dry.get_width(),dry.get_height())
		var upper := Vector2i.ZERO
		for y: int in range(dry.get_height()):
			for x: int in range(dry.get_width()):
				var a: Color = dry.get_pixel(x,y)
				var b: Color = wet.get_pixel(x,y)
				if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) < 0.025: continue
				changed += 1
				lower = lower.min(Vector2i(x,y))
				upper = upper.max(Vector2i(x,y))
		check(changed > 300,"spray changes a readable number of actual native pixels")
		check(upper.x-lower.x > 80 and upper.y-lower.y > 50,"actual water spreads across a broad projected area")
		metrics.append({"water_pixels_over_2_5_percent":changed,"water_pixel_span":upper-lower})
		rig.spray.show()
		rig.mist.show()
		effect.water.show()
	var before: PackedByteArray = water_on
	for tick: int in range(12):
		view._process(1.0/30.0)
		await capture("motion-%02d" % tick)
	check(rig.get_child_count() == child_count and [rig.cable.mesh,rig.spray.multimesh,rig.mist.mesh] == resources,"motion retains original meshes and bounded pools")
	if DisplayServer.get_name() != "headless":
		check(view.showroom_viewport.get_texture().get_image().get_data() != before,"actual native water animates while nozzle stays aimed")
	mouse(view,pixel,false)
	view._process(0.05)
	check(not rig.visible and not rig.spray.is_visible_in_tree() and not rig.mist.is_visible_in_tree(),"release stops all spray layers and connected hose")
	view.elevation = 0.42
	view.yaw = -0.75
	view.set_zoom(1.05)
	pixel = view.camera.unproject_position(view.car.body.global_transform*Vector3(-0.5,0.88,-1.35))*view.size/Vector2(view.showroom_viewport.size)
	mouse(view,pixel,true)
	for tick: int in range(8): view._process(1.0/30.0)
	check(rig.reel.global_transform == reel_pose,"reel stays anchored when aiming and orbiting")
	check(rig.cable_points[0].distance_to(rig.to_local(rig.nozzle.global_transform*Vector3(0,0,0.1))) < 0.0001,"moving nozzle retains its hose connection")
	await capture("wide-spray-ordinary-view")
	mouse(view,pixel,false)
	page._select_wash_tool("mitt")
	check(not rig.visible,"switching back to mitt clears the complete hose rig")
	page._show_section("cars")
	await settle()
	check(not rig.visible and not view.wash_mode,"navigation clears the complete rig")
	page.queue_free()
	await frame()
	check(not is_instance_valid(rig),"teardown frees hose, reel, water and cable together")
	for id: String in VehicleCatalog.IDS:
		var other := CarShowroom.new()
		other.garage_mode = true
		other.vehicle_id = id
		other.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(other)
		other.set_process(false)
		other.yaw = -PI*0.5
		other.elevation = 0.45
		other.set_zoom(1.1)
		for tick: int in range(4): await frame()
		var target: Vector3 = other.car.body.global_transform*other.weathering.bounds.get_center()
		var hit: Vector2 = other.camera.unproject_position(target)*other.size/Vector2(other.showroom_viewport.size)
		other.set_wash_tool("hose")
		other.set_wash_mode(true)
		mouse(other,hit,true)
		other._process(0.05)
		check(other.wash_effect.hose != null and other.wash_effect.hose.visible,id+" actual side contact shows connected hose and broad fan")
		if other.wash_effect.hose != null:
			var car_rig: Node3D = other.wash_effect.hose
			check(car_rig.cable_points[0].distance_to(car_rig.to_local(car_rig.nozzle.global_transform*Vector3(0,0,0.1))) < 0.0001,id+" moving end stays coupled")
			check(car_rig.cable_points[48].distance_to(car_rig.to_local(car_rig.reel.global_transform*car_rig.REEL_OUTLET)) < 0.0001,id+" fixed end stays coupled")
		other.set_wash_mode(false)
		check(not other.wash_effect.visible,id+" Done clears the complete rig")
		other.queue_free()
		await frame()
	FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	print("Garage hose refinement: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
