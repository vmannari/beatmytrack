extends SceneTree
## CLV04: Actual six-car detail-reduced Garage/race integration in disposable local storage.
var checks: int = 0
var failures: int = 0
var output: String
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("SIMPLIFIED_APP_FAIL ",label)
func settle(frames: int = 10) -> void:
	for frame: int in range(frames):
		await process_frame
		await RenderingServer.frame_post_draw
func triangles(node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D and node.is_visible_in_tree() and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: count+=node.mesh.get_faces().size()/3
	for child: Node in node.get_children(): count+=triangles(child)
	return count
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output="res://../docs/evidence/car-iteration-01-2026-11-15/app-"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,720)
	for id: String in VehicleCatalog.IDS:
		if id=="super_rally": continue
		var folder: String = ProjectSettings.globalize_path("res://../build/car-iteration-01-2026-11-15/app/"+TrackLibrary.unique_id())
		DirAccess.make_dir_recursive_absolute(folder)
		var app: Node = load("res://core/app.tscn").instantiate()
		app.records=LocalRecords.new(folder.path_join("records.json"))
		app.records.settings.selected_car=id
		app.library=TrackLibrary.new(folder)
		app.cloud_root_override=folder.path_join("cloud")
		root.add_child(app)
		while not app.startup_complete: await process_frame
		VehicleCatalog.selected=id
		app._show_screen("garage")
		await settle()
		var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
		check(page!=null,"actual Garage loads "+id)
		page.open_car(VehicleCatalog.IDS.find(id))
		while not page.showroom.showroom_ready or not page.showroom.car.model_ready: await process_frame
		while page.showroom.get("preparing")==true: await process_frame
		await settle()
		check(page.showroom.car.vehicle_id==id,"Garage car identity "+id)
		var direct := CarVisual.new()
		direct.vehicle_id=id
		root.add_child(direct)
		while not direct.model_ready: await process_frame
		check(triangles(page.showroom.car)==triangles(direct),"current Garage/direct geometry "+id)
		var expected_triangles: int = triangles(direct)
		direct.free()
		check(root.get_texture().get_image().save_png(output+"/"+id+"-garage.png")==OK,"Garage capture "+id)
		var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
		await app._start_race(track,true,true)
		await settle(20)
		var game: Node = app.game
		game.set_physics_process(false)
		game.countdown_label.hide()
		check(game.handling.vehicle_id==id and game.car.vehicle_id==id,"race car and handling identity "+id)
		check(game.handling.snapshot()==VehicleCatalog.config(id).snapshot(),"complete canonical race tune "+id)
		check(triangles(game.car)==expected_triangles,"race retains current production geometry "+id)
		if id=="kart":
			var wheel: Node3D = game.car.find_child("SteeringAssembly",true,false)
			var driver: MeshInstance3D = game.car.find_child("TomkartDriver",true,false)
			for input: float in [-1.0,0.0,1.0,0.0]:
				# A window can lose focus during parallel native runs. Advance the
				# fixture tick so the paused-presentation cache sees changed state.
				game.sim.state.tick+=1
				game.sim.state.steering=input
				game._present_frame(1.0/60.0)
				check(wheel.basis.is_equal_approx(preload("res://vehicle/kart_steering.gd").REST*Basis(Vector3.UP,-input*PI/3)),"actual race steering wheel")
				var weight: float = 0
				for shape: int in range(driver.mesh.get_blend_shape_count()): weight+=driver.get_blend_shape_value(shape)
				check(is_equal_approx(weight,absf(input)),"actual race ten-pose driver")
		check(root.get_texture().get_image().save_png(output+"/"+id+"-race.png")==OK,"race capture "+id)
		app.free()
		await settle(12)
		print("CAR_SIMPLIFICATION_APP_CAR ",id)
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	print("CAR_SIMPLIFICATION_APP ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
