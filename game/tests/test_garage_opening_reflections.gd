extends SceneTree
## The first revealed live Garage must already use its original reflective finishes.
var checks: int=0
var failures: int=0
var output: String="res://../build/garage-opening-reflections"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(count: int=6) -> void:
	for _i: int in range(count): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func difference(a: Image,b: Image,rect: Rect2i) -> int:
	var changed: int=0
	for y: int in range(rect.position.y,rect.end.y):
		for x: int in range(rect.position.x,rect.end.x):
			var ca: Color=a.get_pixel(x,y)
			var cb: Color=b.get_pixel(x,y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>0.025: changed+=1
	return changed
func capture(label: String) -> void:
	if DisplayServer.get_name()!="headless":
		check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	var studio: CarShowroom=preload("res://ui/garage_opening_showroom.gd").new()
	studio.garage_mode=true
	studio.livery=VehicleLivery.defaults("compact")
	studio.customisation=VehicleCustomisation.defaults()
	root.add_child(studio)
	MenuStyle.fill(studio)
	var picture: Control=studio.find_child("GarageOpeningPicture",true,false)
	check(picture!=null and picture.visible and picture.get_script()==preload("res://ui/garage_loading_car.gd"),"neutral model placeholder is available immediately")
	var last_input: int=studio._last_input
	var hover:=InputEventMouseMotion.new()
	studio._input(hover)
	check(studio._last_input==last_input,"passive pointer movement does not postpone full quality")
	var deadline: int=Time.get_ticks_msec()+120000
	var uncovered_while_preparing: bool=false
	var started: int=Time.get_ticks_msec()
	while studio.preparing and not studio.interaction_ready and Time.get_ticks_msec()<deadline:
		if is_instance_valid(picture) and not picture.visible: uncovered_while_preparing=true
		await process_frame
	check(studio.interaction_ready or not studio.preparing,"live Garage becomes ready within deadline")
	var first_live_ms: int=Time.get_ticks_msec()-started
	check(not studio.preparing,"first interactive live view has finished original material preparation")
	check(not uncovered_while_preparing,"opening picture covers every incomplete finish draw")
	check(studio.find_children("OpeningLiveGeometry","MeshInstance3D",true,false).is_empty(),"first live view has no flat substitute geometry")
	var rig: GarageReflections=studio.reflections
	check(rig!=null and rig.views.size()==2,"first live view retains both bounded reflection targets")
	var floor_mesh: MeshInstance3D=studio.camera.get_parent().find_child("GarageConcrete",true,false)
	check(floor_mesh.visible and floor_mesh.layers==1 and floor_mesh.get_active_material(0)==rig.floor_material,"original floor reflection shader is actually visible at first live view")
	await frames()
	await capture("first-live")
	while studio.preparing and Time.get_ticks_msec()<deadline: await process_frame
	check(not studio.preparing,"full preparation completes")
	check(studio.find_children("*","SubViewport",true,false).size()==3,"temporary preparation target is released")
	check(bool(rig.floor_material.get_shader_parameter("reflection_enabled")) and bool(rig.deck_material.get_shader_parameter("reflection_enabled")),"original floor and pedestal reflections enabled")
	if DisplayServer.get_name()!="headless":
		await frames()
		var with_reflections: Image=studio.showroom_viewport.get_texture().get_image()
		await capture("reflections-on")
		rig.set_enabled(false)
		await frames()
		var without: Image=studio.showroom_viewport.get_texture().get_image()
		await capture("reflections-off-diagnostic")
		var w: int=with_reflections.get_width()
		var h: int=with_reflections.get_height()
		var deck: int=difference(with_reflections,without,Rect2i(int(w*0.35),int(h*0.67),int(w*0.36),int(h*0.25)))
		var floor_pixels: int=difference(with_reflections,without,Rect2i(int(w*0.05),int(h*0.65),int(w*0.24),int(h*0.25)))
		print("REFLECTION_PIXELS deck=",deck," floor=",floor_pixels)
		check(deck>100,"original pedestal reflection affects visible pixels")
		check(floor_pixels>100,"original floor reflection affects visible pixels")
		rig.set_enabled(true)
		await frames()
		var reflected: PackedByteArray=rig.views[1].get_texture().get_image().get_data()
		studio.rotate_view(Vector2(35,0))
		await frames()
		check(rig.views[1].get_texture().get_image().get_data()!=reflected,"reflection follows live orbit")
	var yaw: float=studio.yaw
	studio.rotate_view(Vector2(10,0))
	check(studio.yaw!=yaw,"restored live view retains orbit input")
	var report: Dictionary={"checks":checks,"failures":failures,"live_ms":first_live_ms,"renderer":RenderingServer.get_current_rendering_method()}
	studio.queue_free()
	await frames(12)
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("GARAGE_OPENING_REFLECTIONS ",JSON.stringify(report))
	quit(1 if failures else 0)
