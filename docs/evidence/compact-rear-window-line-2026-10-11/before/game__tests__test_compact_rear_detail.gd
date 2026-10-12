extends SceneTree
## CG17/CG18: emitted rear fittings, bumper pocket, brake response and actual Garage.
var checks: int=0
var failures: int=0
var output: String="res://../docs/evidence/compact-clear-rear-window-2026-10-11"
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
	check(absf(face.mesh.get_aabb().get_center().x)<0.000001 and absf(face.mesh.get_aabb().get_center().y-CompactRearDesign.PLATE_CENTER)<0.000001,"plate centred horizontally and vertically on bumper")
	check(bounds.end.y<0.60 and bounds.position.y>0.371,"plate entirely inside bumper height")
	check(frame.mesh.get_aabb().end.z<2.13,"frame set below outer bumper face")
	check(letters.mesh is TextMesh and letters.mesh.text=="BMT 01","original plate identity uses existing licensed font")
	check(letters.mesh.get_aabb().size.x<0.35 and letters.mesh.get_aabb().size.y<0.12,"registration fits plate margins")
	var bumper: MeshInstance3D=car.body.get_node("RoundedRearBumper")
	var recessed: int=0
	for point: Vector3 in bumper.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(point.x)<0.19 and absf(point.y-CompactRearDesign.PLATE_CENTER)<0.060 and point.z>2.10:
			check(point.z<2.125,"emitted bumper pocket behind plate")
			recessed+=1
	check(recessed>20,"actual baked bumper contains the inset, not only a floating frame")
	for suffix: String in ["Left","Right"]:
		var housing: MeshInstance3D=car.body.get_node("RearLampHousing"+suffix)
		var red: MeshInstance3D=car.body.get_node("RearBrakeLens"+suffix)
		var amber: MeshInstance3D=car.body.get_node("RearIndicator"+suffix)
		var reverse: MeshInstance3D=car.body.get_node("RearReverseLens"+suffix)
		var outer_ratio: float=0
		for point: Vector3 in housing.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:outer_ratio=maxf(outer_ratio,absf(point.x)/CompactCoachwork.width_at_height(point.y))
		check(outer_ratio>0.988 and outer_ratio<1.0,"lamp housing at extreme rear corner "+suffix)
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
	check(absf(bounds.size.x/bounds.size.y-2.0)<0.001,"American plate aspect is two to one")
	var header: MeshInstance3D=car.body.get_node("RearPlateHeader")
	check(letters.mesh.depth==0.0,"printed registration uses flat geometry")
	check(header.mesh.text=="BEAT MY TRACK","fictional American-style jurisdiction header")
	check(header.position.y>letters.position.y,"plate header above main registration")
	var bumper_bounds: AABB=bumper.mesh.get_aabb()
	check(absf(bumper_bounds.size.y/0.26-0.88)<0.001,"rear bumper twelve percent slimmer")
	check(absf(bumper_bounds.end.y-0.60)<0.001,"bumper keeps original upper body join")
	check(car.body.has_node("RearBumperUpperBevel") and car.body.get_node("RearBumperUpperBevel").material_override.roughness>0.8,"defined matte upper bumper bevel")
	check(car.body.has_node("TailgatePanelSeam") and car.body.has_node("TailgateCrease"),"tailgate outlined with horizontal crease")
	var handle: MeshInstance3D=car.body.get_node("RearRecessedHandle")
	check(handle.mesh.get_aabb().size.x>0.29,"slightly larger hatch handle")
	check(handle.position.z+handle.mesh.get_aabb().end.z<CompactCoachwork.rear_depth(handle.position.y)+0.006,"handle nested in steel recess")
	var face_mesh: MeshInstance3D=car.body.get_node("RearCoachwork")
	var pressed: int=0
	for point: Vector3 in face_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(point.x)<0.13 and absf(point.y-0.898)<0.03:
			check(point.z<CompactCoachwork.rear_depth(point.y)-0.010,"actual steel includes handle recess")
			pressed+=1
	check(pressed>5,"handle recess exists in baked geometry")
	for pipe: int in range(2):
		var exhaust: Node3D=car.body.get_node("RearExhaustAssembly/RearExhaust"+str(pipe+1))
		check(exhaust.position.x>0.30 and exhaust.position.x<0.70,"both exhaust mouths on vehicle right")
		check(exhaust.position.y+0.049<bumper_bounds.position.y,"exhaust mouths below bumper")
		check(exhaust.has_node("Rim") and exhaust.has_node("Interior") and exhaust.has_node("DarkBack"),"open metal rim and dark exhaust interior")
	var first: Node3D=car.body.get_node("RearExhaustAssembly/RearExhaust1")
	var second: Node3D=car.body.get_node("RearExhaustAssembly/RearExhaust2")
	check(first.position.y==second.position.y and first.position.z==second.position.z,"side-by-side exhausts aligned horizontally")
	check(second.position.x-first.position.x>0.098,"exhaust mouths separated")
	check(car.body.has_node("RearWiperPivot") and car.body.get_node("RearWiperArm").get_child_count()==4,"rear wiper has pivot, shaped arm and blade")
	check(not car.body.has_node("RearGlassReflection0") and not car.body.has_node("RearGlassReflection1"),"rear window has no decorative reflection stripes")
	check(car.rolling_wheels.size()==4 and car.front_wheels.size()==2,"original wheels and steering preserved")
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
		await capture(view,"garage-rear-close",PI,0.10,0.59)
		await capture(view,"garage-side",PI/2,0.10,0.74)
		view.car.rear_braking=true
		view.car._update_rear_lights()
		await capture(view,"garage-rear-braking",PI,0.13,0.74)
		view.car.rear_braking=false
		view.car._update_rear_lights()
		var parent: Node=view
		while parent is not GaragePage:parent=parent.get_parent()
		var page: GaragePage=parent as GaragePage
		page._preview_color(Color("804439"),"body")
		page._preview_color(Color("b7af9c"),"accent")
		await capture(view,"garage-rear-livery",PI,0.13,0.74)
	app.queue_free()
	await process_frame
	print("COMPACT_REAR_DETAIL: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

