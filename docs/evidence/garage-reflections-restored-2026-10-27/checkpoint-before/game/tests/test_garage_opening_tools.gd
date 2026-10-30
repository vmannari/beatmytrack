extends SceneTree
var checks: int=0
var failures: int=0
var studio: CarShowroom
var output: String="res://../build/garage-opening-tools"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func active_frame() -> void:
	var motion:=InputEventMouseMotion.new()
	studio._input(motion)
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	else: studio._sync_live_finish()
func bindings(label: String) -> void:
	check(studio._facade!=null and not studio._facade.items.is_empty(),label+" has temporary live bindings")
	for item: Dictionary in studio._facade.items:
		var source: Object=item.source.get_ref()
		if not is_instance_valid(source): continue
		check(source.layers==8 and not source.visible,label+" keeps original finish reserved")
		check(item.copy.mesh==source.mesh,label+" uses the same geometry")
		check(item.copy.global_transform==source.global_transform,label+" follows the exact source transform")
		if item.copy.global_transform!=source.global_transform: print("POSE_DIFFERENCE ",source.get_path()," local ",source.transform," proxy ",item.copy.transform," global ",source.global_transform," proxy ",item.copy.global_transform)
		for surface: int in range(source.mesh.get_surface_count()):
			var original: Material=source.get_active_material(surface)
			var live: Material=item.copy.get_active_material(surface)
			if original is ShaderMaterial and live is ShaderMaterial:
				for parameter: String in ["paint_color","dirt_amount","snow_amount","garage_paint_progress","garage_kit_progress"]:
					var expected: Variant=original.get_shader_parameter(parameter)
					if expected!=null: check(live.get_shader_parameter(parameter)==expected,label+" retains "+parameter)
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
	var deadline: int=Time.get_ticks_msec()+60000
	while not studio.interaction_ready and Time.get_ticks_msec()<deadline: await process_frame
	check(studio.interaction_ready and studio.preparing,"live tools precede full native preparation")
	var paint: Dictionary=studio.livery.duplicate(true)
	paint.colors.body="c72d34"
	studio.apply_livery(paint,true)
	await active_frame()
	bindings("paint sweep")
	while studio.paint_motion!=null: await active_frame()
	await active_frame()
	bindings("paint settled")
	var parts: Dictionary=VehicleCustomisation.defaults()
	parts.aero="wing"
	studio.apply_customisation(parts,true)
	await active_frame()
	bindings("parts sweep")
	while studio.kit_motion!=null: await active_frame()
	await active_frame()
	bindings("parts settled")
	studio.update_records({})
	await active_frame()
	bindings("record refreshed")
	check(studio.car.customisation.aero=="wing","live main model has the requested rear aero")
	check(studio.preparing,"input keeps cold full-finish work paused")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("early-painted-wing.png"))==OK,"capture live paint and fitted parts before full preparation")
	studio.queue_free()
	for _frame: int in range(12): await process_frame
	print("GARAGE_OPENING_TOOLS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
