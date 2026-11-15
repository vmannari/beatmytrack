extends SceneTree
## Inspect the actual reveal texture before another live frame can repair it.
var checks: int=0
var failures: int=0
var output: String
var rows: Array[Dictionary]=[]

func _initialize() -> void:
	if "--prior-pass" in OS.get_cmdline_user_args():
		var script: Script=load("res://ui/garage_opening_showroom.gd")
		var source: String=FileAccess.get_file_as_string("res://../build/garage-fast-entry-2026-11-14/before/garage_opening_showroom.gd")
		assert(not source.is_empty(),"The prior-pass fixture must exist beside the original project")
		script.source_code=source
		assert(script.reload(true)==OK)
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("GARAGE_CAPTURE_FAIL ",label)

func frames(count: int=4) -> void:
	for _i: int in range(count): await process_frame

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	Engine.time_scale=0
	for id: String in VehicleCatalog.IDS: await capture_car(id)
	Engine.time_scale=1
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("GARAGE_FIRST_CAPTURE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func capture_car(id: String) -> void:
	var studio: CarShowroom=preload("res://ui/garage_opening_showroom.gd").new()
	studio.vehicle_id=id
	studio.garage_mode=true
	studio.livery=VehicleLivery.defaults(id)
	studio.livery.colors.body="2b83c7"
	studio.customisation=VehicleCustomisation.defaults()
	for category: String in VehicleCustomisation.CATEGORIES:
		studio.customisation[category]=VehicleCustomisation.options(category,id)[1][0]
	studio.condition=VehicleWeathering.new().snapshot()
	studio.condition.dirt=0.2
	var permission: Dictionary={"allowed":false}
	studio.can_begin_studio=func() -> bool: return permission.allowed
	var first: Dictionary={}
	studio.studio_interactive.connect(func() -> void:
		if DisplayServer.get_name()!="headless":
			first.image=studio.showroom_viewport.get_texture().get_image()
		first.views=studio.find_children("*","SubViewport",true,false).size()
		first.lights=studio.camera.get_parent().find_children("*","Light3D",true,false).size())
	root.add_child(studio)
	MenuStyle.fill(studio)
	await frames()
	check(studio.car==null,"closed navigation gate prevents construction "+id)
	Input.action_press("ui_accept")
	permission.allowed=true
	var deadline: int=Time.get_ticks_msec()+60000
	await frames()
	check(studio.car==null,"held input prevents cold native construction "+id)
	Input.action_release("ui_accept")
	while studio._first==null and Time.get_ticks_msec()<deadline: await process_frame
	check(studio._first!=null,"first actual capture owns an observable job "+id)
	Input.action_press("ui_accept")
	check(not studio._current_warm_batch(),"held input prevents capture "+id)
	await frames()
	check(not studio.interaction_ready,"held input cannot reveal an unfinished view "+id)
	Input.action_release("ui_accept")
	var released:=InputEventMouseButton.new()
	released.button_index=MOUSE_BUTTON_LEFT
	studio._input(released)
	check(not studio._current_warm_batch(),"released input has a brief quiet interval "+id)
	var began: int=Time.get_ticks_msec()
	while studio.preparing and Time.get_ticks_msec()<deadline: await process_frame
	check(not studio.preparing and studio.interaction_ready,"actual reflected view completes "+id)
	check(Time.get_ticks_msec()-began>=(studio.ENTRY_IDLE_MS if "ENTRY_IDLE_MS" in studio else 750),"capture respects its quiet interval "+id)
	var state: SceneState=load(GarageEnvironment.PREPARED_ARCHITECTURE).get_state()
	var expected_lights: int=3 # Original Garage key/fill/rim plus authored fixtures.
	for index: int in range(state.get_node_count()):
		if state.get_node_type(index) in [&"DirectionalLight3D",&"OmniLight3D",&"SpotLight3D"]: expected_lights+=1
	check(first.get("views",0)==3 and first.get("lights",0)==expected_lights,"first reveal has only original targets and lights "+id+" actual="+str(first.get("lights",0))+" expected="+str(expected_lights))
	check(studio.car.vehicle_id==id and studio.car.customisation==studio.customisation,"first reveal retains selected fitted car "+id)
	check(studio.car.livery==studio.livery and is_equal_approx(studio.weathering.dirt_amount,0.2),"first reveal retains saved paint and wear "+id)
	for view: SubViewport in studio.reflections.views:
		check(view.msaa_3d==studio.showroom_viewport.msaa_3d,"reflection starts with final sampling "+id)
	studio.set_process(false)
	if DisplayServer.get_name()!="headless":
		var initial: Image=first.image
		check(initial.save_png(output.path_join(id+"-first.png"))==OK,"capture exact first reveal "+id)
		for _i: int in range(8):
			studio.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			studio.reflections.request_draw()
			await RenderingServer.frame_post_draw
			await process_frame
		var settled: Image=studio.showroom_viewport.get_texture().get_image()
		var comparison: Dictionary=pixel_difference(initial,settled)
		# The original staging control also varies by 1-2 byte levels between
		# native draws. Keep that measured quantization separate from readiness.
		check(comparison.get("same_size",false) and comparison.get("maximum",255)<=2 and comparison.get("mean",255)<0.1,"first reveal retains settled full quality within native quantization "+id)
		settled.save_png(output.path_join(id+"-settled.png"))
		rows.append({"vehicle":id,"first_equals_settled":initial.get_data()==settled.get_data(),"comparison":comparison,"size":str(initial.get_size())})
	studio.queue_free()
	await frames(8)

func pixel_difference(a: Image,b: Image) -> Dictionary:
	if a.get_size()!=b.get_size() or a.get_format()!=b.get_format(): return {"same_size":false}
	var left: PackedByteArray=a.get_data()
	var right: PackedByteArray=b.get_data()
	var changed: int=0
	var total: int=0
	var maximum: int=0
	for index: int in range(left.size()):
		var delta: int=absi(left[index]-right[index])
		total+=delta
		maximum=maxi(maximum,delta)
		if delta>0: changed+=1
	return {"same_size":true,"changed_bytes":changed,"maximum":maximum,"mean":float(total)/left.size()}
