extends SceneTree
## Compare each real Garage preview with the stock Volt from category cameras.
var failures := 0
var checks := 0
var output := "res://../tmp/volt-kit-visibility"

func _initialize() -> void: run.call_deferred()

func changed_pixels(first: Image,second: Image) -> int:
	first.convert(Image.FORMAT_RGBA8)
	second.convert(Image.FORMAT_RGBA8)
	var a: PackedByteArray=first.get_data()
	var b: PackedByteArray=second.get_data()
	if a.size()!=b.size(): return 0
	var count:=0
	for i: int in range(0,a.size(),4):
		if maxi(absi(int(a[i])-int(b[i])),maxi(absi(int(a[i+1])-int(b[i+1])),absi(int(a[i+2])-int(b[i+2]))))>12: count+=1
	return count

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless":
		push_error("Volt visibility test needs a rendered display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(960,540)
	var room:=CarShowroom.new()
	room.vehicle_id="electric"
	room.read_only=true
	room.garage_mode=true
	room.framing_scale=0.57
	room.zoom=0.90
	room.livery=VehicleLivery.defaults("electric")
	if "--dark" in OS.get_cmdline_user_args():
		room.livery.colors={"body":"203b50","accent":"d2d9d7","detail":"87969d"}
	room.customisation=VehicleCustomisation.defaults()
	room.size=Vector2(root.size)
	root.add_child(room)
	while not room.showroom_ready: await process_frame
	var report: Dictionary={"renderer":RenderingServer.get_current_rendering_method(),"choices":{}}
	for category: String in VehicleCustomisation.CATEGORIES:
		var yaw: float={"hood":-0.80,"aero":-2.40,"rims":-1.57,"body":-0.80}[category]
		var elevation: float={"hood":0.40,"aero":0.46,"rims":0.08,"body":0.20}[category]
		room.elevation=atan(elevation)
		room._orbit()
		room.turntable.rotation.y=yaw-CarShowroom.GARAGE_CAMERA_YAW
		room.camera.fov=32
		var original: Image
		for option: Array in VehicleCustomisation.options(category,"electric"):
			var value: Dictionary=VehicleCustomisation.defaults()
			value[category]=option[0]
			room.apply_customisation(value)
			for frame: int in range(4):
				room.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
				room.reflections.request_draw()
				await process_frame
				await RenderingServer.frame_post_draw
			var picture: Image=room.showroom_viewport.get_texture().get_image()
			var name_value: String=category+"_"+str(option[0])
			if picture.save_png(output.path_join(name_value+".png"))!=OK:
				failures+=1
				print("FAIL: capture ",name_value)
			if option[0]=="stock":
				original=picture
			else:
				var pixels: int=changed_pixels(original,picture)
				report.choices[name_value]=pixels
				checks+=1
				if pixels<1500:
					failures+=1
					print("FAIL: too little visible change ",name_value," pixels=",pixels)
	report.merge({"checks":checks,"failures":failures})
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("VOLT_KIT_VISIBILITY: ",checks," checks, ",failures," failures")
	room.queue_free()
	await process_frame
	quit(1 if failures else 0)
