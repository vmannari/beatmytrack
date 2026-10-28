extends SceneTree
## Requests during preparation survive; original paint/parts tools work after reveal.
var checks: int=0
var failures: int=0
var studio: CarShowroom
var output: String="res://../build/garage-opening-tools"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(count: int=4) -> void:
	for _i: int in range(count): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	studio=preload("res://ui/garage_opening_showroom.gd").new()
	studio.garage_mode=true
	studio.livery=VehicleLivery.defaults("compact")
	studio.customisation=VehicleCustomisation.defaults()
	root.add_child(studio)
	MenuStyle.fill(studio)
	var paint: Dictionary=studio.livery.duplicate(true)
	paint.colors.body="c72d34"
	var parts: Dictionary=VehicleCustomisation.defaults()
	parts.aero="wing"
	studio.apply_livery(paint,true)
	studio.apply_customisation(parts,true)
	studio.update_records({})
	check(studio.preparing and not studio.interaction_ready,"tools wait for original full quality")
	check(studio._pending.paint==paint and studio._pending.parts==parts,"latest paint and parts requests coexist while covered")
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	studio._input(click)
	check(studio._last_input>0,"deliberate input still pauses cold preparation")
	await frames()
	check(studio.find_child("GarageOpeningPicture",true,false).visible,"picture covers preparation while input is active")
	studio.hide()
	await frames()
	check(not studio._current_warm_batch(),"hidden preparation is suspended")
	studio.show()
	var deadline: int=Time.get_ticks_msec()+120000
	while studio.preparing and Time.get_ticks_msec()<deadline: await process_frame
	check(studio.interaction_ready and not studio.preparing,"full quality becomes interactive")
	check(studio.car.livery.colors.body=="c72d34" and studio.car.customisation.aero=="wing","deferred paint and fitted wing are present at first reveal")
	check(studio.find_children("OpeningLiveGeometry","MeshInstance3D",true,false).is_empty(),"tools edit original geometry without substitute finishes")
	paint.colors.body="2d83c7"
	studio.apply_livery(paint,true)
	check(studio.paint_motion!=null,"original paint sweep still animates")
	while studio.paint_motion!=null and Time.get_ticks_msec()<deadline: await process_frame
	check(studio.car.livery.colors.body=="2d83c7","live paint sweep finishes on the requested colour")
	parts.aero="lip"
	studio.apply_customisation(parts,true)
	check(studio.kit_motion!=null,"original parts sweep still animates")
	while studio.kit_motion!=null and Time.get_ticks_msec()<deadline: await process_frame
	check(studio.car.customisation.aero=="lip","live parts sweep finishes on requested aero")
	check(bool(studio.reflections.deck_material.get_shader_parameter("reflection_enabled")),"parts changes retain actual pedestal reflections")
	await frames()
	if DisplayServer.get_name()!="headless":
		check(root.get_texture().get_image().save_png(output.path_join("original-paint-and-parts.png"))==OK,"capture original reflective paint and parts")
	studio.queue_free()
	await frames(12)
	# Destruction also cancels a deliberately paused, partly built opening.
	var pending: CarShowroom=preload("res://ui/garage_opening_showroom.gd").new()
	pending.garage_mode=true
	root.add_child(pending)
	MenuStyle.fill(pending)
	while pending._first==null and Time.get_ticks_msec()<deadline: await process_frame
	check(pending._first!=null,"cancellation fixture reaches an owned preparation job")
	pending._input(click)
	var ref: WeakRef=weakref(pending)
	pending.queue_free()
	await frames(12)
	check(ref.get_ref()==null,"paused preparation releases the original world on destruction")
	print("GARAGE_OPENING_TOOLS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
