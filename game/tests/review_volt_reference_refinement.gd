extends SceneTree
## Matched native views of the owner's side, rear-glass and door corrections.
const COACH=preload("res://vehicle/electric_coachwork.gd")
var output: String="res://../docs/evidence/volt-reference-refinement-2026-10-29/preview"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output=arg.trim_prefix("--evidence-root=")
	if "--before" in OS.get_cmdline_user_args():
		var author: GDScript=COACH
		author.source_code=FileAccess.get_file_as_string("res://../docs/evidence/volt-reference-refinement-2026-10-29/task-base/game/vehicle/electric_coachwork.gd")
		assert(author.reload()==OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1440,720)
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
	var result: Dictionary={"renderer":RenderingServer.get_current_rendering_method(),"captures":[],"failures":0}
	for worn: bool in [false,true]:
		if worn: room.weathering.restore({"dirt":0.38,"slow_dirt":0.12,"mud":0.09,"smudge":0.02,"color":"463225"})
		for shot: Array in [["side",-PI*0.5,0.08,2.35],["side-opposite",PI*0.5,0.08,2.35],["front",0.0,0.18,0.0],["bonnet",-0.45,0.90,0.0],["rear-quarter",-2.40,0.46,0.0],["rear-low",-2.40,0.18,0.0],["front-quarter",-0.80,0.28,0.0],["front-pillar",-0.80,0.28,0.0]]:
			room.elevation=atan(float(shot[2]))
			room._orbit()
			room.turntable.rotation.y=float(shot[1])-CarShowroom.GARAGE_CAMERA_YAW
			room.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if float(shot[3])>0 else Camera3D.PROJECTION_PERSPECTIVE
			room.camera.size=float(shot[3]) if float(shot[3])>0 else 2.35
			room.camera.fov=32
			if str(shot[0])=="front-pillar":
				var advance: float=0.20/HandlingConfig.BODY_SCALE
				var target: Vector3=room.car.body.to_global(Vector3(-0.86,1.15,-0.65-advance))
				var direction: Vector3=(room.camera.global_position-Vector3(0,0.55+GarageEnvironment.DECK_HEIGHT,0)).normalized()
				room.camera.global_position=target+direction*1.8
				room.camera.look_at(target)
			for frame: int in range(6):
				room.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
				room.reflections.request_draw()
				await process_frame
				await RenderingServer.frame_post_draw
			var name_value: String=str(shot[0])+("-worn" if worn else "-clean")
			var saved: Error=room.showroom_viewport.get_texture().get_image().save_png(output.path_join(name_value+".png"))
			result.captures.append({"name":name_value,"save_error":saved})
			if saved!=OK: result.failures+=1
	room.queue_free()
	await process_frame
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("VOLT_CABIN_REVIEW: ",JSON.stringify(result))
	quit(1 if result.failures else 0)
