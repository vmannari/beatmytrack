extends SceneTree
var output: String
var views: Array[CarShowroom]=[]
var results: Dictionary={}
var failures: int=0
func _initialize() -> void: run.call_deferred()
func make() -> CarShowroom:
	var view:=CarShowroom.new()
	view.vehicle_id="compact";view.garage_mode=true;view.framing_scale=0.84
	view.livery=VehicleLivery.defaults("compact")
	view.livery.colors.body="c72d34";view.livery.pattern=LiveryCatalog.patterns[0].id
	view.livery.stickers.hood.id=LiveryCatalog.stickers[0].id
	view.condition=VehicleWeathering.new().snapshot()
	view.condition.dirt=0.2;view.condition.slow_dirt=0.1
	view.size=Vector2(1280,500)
	root.add_child(view)
	view.update_records({"music_record":"exploration"})
	return view
func capture(view: CarShowroom,pose: String) -> Image:
	if pose=="records": view.set_record_view(true)
	elif pose=="wall": view.set_trophy_view(true)
	for _i: int in range(90): await process_frame
	await RenderingServer.frame_post_draw
	return view.showroom_viewport.get_texture().get_image()
func diff(a: Image,b: Image) -> Dictionary:
	var aa: PackedByteArray=a.get_data();var bb: PackedByteArray=b.get_data()
	assert(aa.size()==bb.size())
	var total: int=0;var changed: int=0;var maximum: int=0
	for index: int in range(aa.size()):
		var d: int=absi(int(aa[index])-int(bb[index]));total+=d;maximum=maxi(maximum,d)
		if d>0: changed+=1
	return {"mean_byte_error":float(total)/aa.size(),"changed_bytes":changed,"max_byte_error":maximum}
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	root.size=Vector2i(1280,500)
	GameSoundtrack.instance().music_enabled=false
	var source: Dictionary={};var controls: Dictionary={}
	var original: CarShowroom=make()
	for pose: String in ["car","records","wall"]:
		source[pose]=await capture(original,pose)
		controls[pose]=await capture(original,pose)
		source[pose].save_png(output.path_join("original-"+pose+".png"))
	original.free()
	load("res://../docs/evidence/garage-first-entry-2026-10-27/early_shared.gd").install()
	GarageEnvironment.architecture_scene=null
	GarageMaterials.finishes.clear()
	var shared: CarShowroom=make()
	for pose: String in ["car","records","wall"]:
		var actual: Image=await capture(shared,pose)
		actual.save_png(output.path_join("shared-"+pose+".png"))
		results[pose]={"control":diff(source[pose],controls[pose]),"shared":diff(source[pose],actual)}
		if results[pose].shared.mean_byte_error>results[pose].control.mean_byte_error+0.01:
			failures+=1;print("FAIL: original shared finish pixels ",pose," ",results[pose])
	print("SHARED_COMPARISON ",JSON.stringify(results))
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"results":results},"  "))
	shared.free();await process_frame;quit(1 if failures else 0)
