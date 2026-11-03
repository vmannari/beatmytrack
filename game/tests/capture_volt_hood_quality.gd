extends SceneTree
## Offline, owner-data-free inspection of every hood under the real Garage lights.
var settle_frames: int=4
var selected_options: PackedStringArray=[]
var output := "res://../docs/evidence/volt-hood-quality-2026-11-02/views"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument.begins_with("--options="): selected_options=argument.trim_prefix("--options=").split(",")
	if DisplayServer.get_name()=="headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,720)
	var room:=CarShowroom.new()
	room.vehicle_id="electric"
	room.read_only=true
	room.garage_mode=true
	room.framing_scale=0.57
	room.zoom=0.90
	room.livery=VehicleLivery.defaults("electric")
	room.customisation=VehicleCustomisation.defaults()
	room.size=Vector2(root.size)
	root.add_child(room)
	while not room.showroom_ready: await process_frame
	var count:=0
	for colour: String in ["blue","silver"]:
		var finish: Dictionary=VehicleLivery.defaults("electric")
		finish.colors.body="205a78" if colour=="blue" else "b8bbb9"
		room.apply_livery(finish)
		for option: Array in VehicleCustomisation.options("hood","electric"):
			if not selected_options.is_empty() and str(option[0]) not in selected_options: continue
			var parts: Dictionary=VehicleCustomisation.defaults()
			parts.hood=option[0]
			room.apply_customisation(parts)
			for view: String in ["quarter","front","side"]:
				room.elevation=atan(0.40 if view=="quarter" else 0.55 if view=="front" else 0.09)
				room._orbit()
				room.turntable.rotation.y=({"quarter":-0.80,"front":0.0,"side":-1.57}[view])-CarShowroom.GARAGE_CAMERA_YAW
				room.camera.fov=32
				for frame: int in range(settle_frames):
					room.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
					room.reflections.request_draw()
					await process_frame
					await RenderingServer.frame_post_draw
				var picture: Image=room.showroom_viewport.get_texture().get_image()
				if picture.save_png(output.path_join(colour+"_"+str(option[0])+"_"+view+".png"))!=OK: quit(1); return
				count+=1
	print("VOLT_HOOD_CAPTURES: ",count)
	room.queue_free()
	await process_frame
	quit()
