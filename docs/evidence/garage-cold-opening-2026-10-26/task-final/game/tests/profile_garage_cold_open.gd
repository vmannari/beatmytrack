extends SceneTree
## Isolated first-frame attribution. Variants alter only in-memory script copies.
var output: String="res://../build/garage-cold-open"
var variant: String="original"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--variant="): variant=arg.trim_prefix("--variant=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var script: GDScript=load("res://ui/car_showroom.gd")
	var source: String=script.source_code.replace("\r\n","\n")
	var boundary: int=source.find("\nfunc refresh_thumbnail()")
	var remaining: String=source.substr(boundary)
	source=source.left(boundary)
	source=source.replace("func _ready() -> void:\n","func _ready() -> void:\n\tvar cold_stamp: int=Time.get_ticks_usec()\n")
	for marker: String in ["\tworld.add_child(car)","\telse: ShowroomStudio.build(world,car)","\tweathering.configure(car, \"pine\", VehicleCatalog.config(vehicle_id))","\tweathering.restore(condition)","\tif not read_only: _cache_pick_meshes(car)"]:
		source=source.replace(marker,marker+"\n\tprint(\"COLD_STAGE "+marker.strip_edges().replace('"','')+" \",(Time.get_ticks_usec()-cold_stamp)/1000.0)\n\tcold_stamp=Time.get_ticks_usec()")
	if variant=="no_reflections": source=source.replace("reflections.build(self,world,turntable)","reflections.owner=self # diagnostic: no reflection views")
	if variant=="no_pick_meshes": source=source.replace("if not read_only: _cache_pick_meshes(car)","pass # diagnostic: no picking preparation")
	script.source_code=source+remaining
	if script.reload()!=OK: quit(1);return
	if variant=="no_sky":
		var lighting: GDScript=load("res://ui/garage_environment.gd")
		lighting.source_code=lighting.source_code.replace("environment.environment.sky = ShowroomStudio.cached_sky","environment.environment.sky = null").replace("Environment.REFLECTION_SOURCE_SKY","Environment.REFLECTION_SOURCE_DISABLED")
		assert(lighting.reload()==OK)
	root.size=Vector2i(1280,720)
	var began: int=Time.get_ticks_usec()
	var view:=CarShowroom.new()
	view.garage_mode=true
	view.size=Vector2(1180,480)
	root.add_child(view)
	var report: Dictionary={"variant":variant,"call_ms":(Time.get_ticks_usec()-began)/1000.0,"frames":[]}
	print("COLD_DISPATCH ",report.call_ms)
	for index: int in range(12):
		var tick: int=Time.get_ticks_usec()
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
		await process_frame
		var frame: Dictionary={"frame":index,"ms":(Time.get_ticks_usec()-tick)/1000.0,"mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),"surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),"draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)}
		report.frames.append(frame)
		print("COLD_DRAW ",JSON.stringify(frame))
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(output.path_join("garage.png"))
	view.queue_free()
	for _i: int in range(8): await process_frame
	var file:=FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	quit()
