extends SceneTree
## Every lower-body package under the real Garage lights; no account or save.
var output := "res://../docs/evidence/volt-body-refinement-2026-11-03/before"
var selected := PackedStringArray()

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument.begins_with("--options="): selected=argument.trim_prefix("--options=").split(",")
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
	for colour: String in ["silver","blue"]:
		var finish: Dictionary=VehicleLivery.defaults("electric")
		finish.colors.body="205a78" if colour=="blue" else "b8bbb9"
		room.apply_livery(finish)
		for option: Array in VehicleCustomisation.options("body","electric"):
			if not selected.is_empty() and str(option[0]) not in selected: continue
			# All choices in silver; representative finishes in blue.
			if colour=="blue" and option[0] not in ["stock","volt_street","volt_carbon","volt_gt","volt_race"]: continue
			var parts: Dictionary=VehicleCustomisation.defaults()
			parts.body=option[0]
			room.apply_customisation(parts)
			for view: String in ["quarter","front","side","rear_quarter","rear"]:
				room.elevation=atan(0.24 if view in ["quarter","rear_quarter"] else 0.09)
				room._orbit()
				room.turntable.rotation.y=float({"quarter":-0.80,"front":0.0,"side":-1.57,"rear_quarter":-2.40,"rear":PI}[view])-CarShowroom.GARAGE_CAMERA_YAW
				room.camera.fov=32
				for frame: int in range(4):
					room.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
					room.reflections.request_draw()
					await process_frame
					await RenderingServer.frame_post_draw
				var picture: Image=room.showroom_viewport.get_texture().get_image()
				if picture.save_png(output.path_join(colour+"_"+str(option[0])+"_"+view+".png"))!=OK: quit(1); return
				count+=1
	print("VOLT_BODY_CAPTURES: ",count)
	room.queue_free()
	await process_frame
	quit()
