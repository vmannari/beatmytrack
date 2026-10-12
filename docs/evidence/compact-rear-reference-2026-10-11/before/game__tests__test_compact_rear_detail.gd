extends SceneTree
## CG17/CG18: emitted rear fittings, bumper pocket, brake response and actual Garage.
var checks: int=0
var failures: int=0
var output: String="res://../docs/evidence/compact-rear-detail-2026-10-11"
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func capture(view: CarShowroom,label: String,yaw: float,elevation: float,zoom: float) -> void:
	view.yaw=yaw
	view.elevation=elevation
	view.set_zoom(zoom)
	for frame: int in range(12):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var car:=CarVisual.new()
	car.batch_parts=false
	root.add_child(car)
	var face: MeshInstance3D=car.body.get_node("RearPlateFace")
	var frame: MeshInstance3D=car.body.get_node("RearPlateFrame")
	var letters: MeshInstance3D=car.body.get_node("RearPlateLetters")
	var bounds: AABB=face.mesh.get_aabb()
	check(face.position==Vector3(0,0.47,2.142),"plate centred horizontally and vertically on bumper")
	check(face.position.y+bounds.end.y<0.60 and face.position.y+bounds.position.y>0.34,"plate entirely inside bumper height")
	check(frame.position.z+frame.mesh.get_aabb().end.z<2.15,"frame set below outer bumper face")
	check(letters.mesh is TextMesh and letters.mesh.text=="BMT 01","original plate identity uses existing licensed font")
	check(letters.mesh.get_aabb().size.x<0.32 and letters.mesh.get_aabb().size.y<0.10,"registration fits plate margins")
	var bumper: MeshInstance3D=car.body.get_node("RoundedRearBumper")
	var recessed: int=0
	for point: Vector3 in bumper.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(point.x)<0.19 and absf(point.y-0.47)<0.055 and point.z>2.10:
			check(point.z<2.14,"emitted bumper pocket behind plate")
			recessed+=1
	check(recessed>20,"actual baked bumper contains the inset, not only a floating frame")
	for suffix: String in ["Left","Right"]:
		var housing: MeshInstance3D=car.body.get_node("RearLampHousing"+suffix)
		var red: MeshInstance3D=car.body.get_node("RearBrakeLens"+suffix)
		var amber: MeshInstance3D=car.body.get_node("RearIndicator"+suffix)
		var reverse: MeshInstance3D=car.body.get_node("RearReverseLens"+suffix)
		check(red.material_override==car.brake_material,"brake lens retains live material "+suffix)
		check(amber.mesh.get_aabb().position.y>red.mesh.get_aabb().end.y and red.mesh.get_aabb().position.y>reverse.mesh.get_aabb().end.y,"separate lens bands "+suffix)
		for lens: MeshInstance3D in [red,amber,reverse]:
			var a: AABB=lens.mesh.get_aabb()
			var h: AABB=housing.mesh.get_aabb()
			check(a.position.y>h.position.y and a.end.y<h.end.y,"lens inside housing height "+suffix)
			var nearest: float=INF
			for point: Vector3 in lens.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				nearest=minf(nearest,point.z-CompactCoachwork.rear_skin(point.x,point.y))
			check(nearest<0 and nearest> -0.014,"lens backs embedded in tail skin "+suffix)
	var left: MeshInstance3D=car.body.get_node("RearLampHousingLeft")
	var right: MeshInstance3D=car.body.get_node("RearLampHousingRight")
	check(absf(left.mesh.get_aabb().position.x+right.mesh.get_aabb().end.x)<0.00001,"rear lamps mirror symmetrically")
	var normal_energy: float=car.brake_material.emission_energy_multiplier
	car.rear_braking=true
	car._update_rear_lights()
	check(car.brake_material.emission_energy_multiplier>normal_energy,"new red lenses brighten when braking")
	car.queue_free()
	await process_frame
	var directory: String="user://compact_rear_detail_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(directory.path_join("records.json"))
	app.library=TrackLibrary.new(directory)
	app.cloud_root_override=directory.path_join("cloud")
	root.size=Vector2i(1280,720)
	root.add_child(app)
	while not app.startup_complete:await process_frame
	VehicleCatalog.selected="compact"
	app._show_screen("garage")
	await create_timer(0.45).timeout
	var view: CarShowroom=app.root_ui.find_child("GarageShowroom",true,false)
	check(view!=null,"actual Garage showroom present")
	if view!=null:
		await capture(view,"garage-rear",PI,0.13,0.74)
		await capture(view,"garage-rear-left",-2.35,0.20,0.79)
		await capture(view,"garage-rear-right",2.35,0.20,0.79)
		await capture(view,"garage-rear-high",PI,0.42,0.79)
		await capture(view,"garage-rear-close",PI,0.10,0.50)
	app.queue_free()
	await process_frame
	print("COMPACT_REAR_DETAIL: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

