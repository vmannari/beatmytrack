extends SceneTree
## Regression: CanvasItem redraw/resize must never dispatch optional GPU warming.
var checks: int=0
var failures: int=0
var output: String="res://../build/native-shader-preparation-2026-10-28/warm-scheduling"
var studio: Node
var permission: Dictionary={"allowed":true,"limit":-1}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(count: int=4) -> void:
	for index: int in range(count): await process_frame
func allowed() -> bool:
	return permission.allowed and (permission.limit<0 or studio.warm_draws<permission.limit)
func stopped() -> void:
	var deadline: int=Time.get_ticks_msec()+120000
	while studio.warming and Time.get_ticks_msec()<deadline: await process_frame
	check(not studio.warming,"an explicit warming invocation returns after preparation or permission loss")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var config:=ConfigFile.new();config.set_value("backend","url","");assert(config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")
	root.size=Vector2i(1280,720)
	Engine.max_fps=60
	studio=load("res://ui/garage_preloaded_studio.gd").new()
	studio.vehicle_id="compact";studio.garage_mode=true;studio.framing_scale=0.84
	studio.size=Vector2(1168,360);studio.permitted=allowed
	studio.warm()
	check(studio.warm_draws==0 and not studio.warming,"pre-tree warming request does no work")
	root.add_child(studio)
	var deadline: int=Time.get_ticks_msec()+120000
	while not studio.showroom_ready and Time.get_ticks_msec()<deadline: await process_frame
	check(studio.showroom_ready,"original cooperative construction completes")
	await frames(8)
	check(studio.warm_draws==0,"construction does not schedule optional warming through CanvasItem._draw")
	var before: int=studio.warm_draws
	studio.queue_redraw();studio.size=Vector2(1200,368)
	await frames(6)
	check(studio.warm_draws==before,"redraw and resize do not submit optional warm frames")
	permission.allowed=false
	studio.warm()
	await frames(3)
	check(studio.warm_draws==before and not studio.warming,"permission loss prevents explicit warming")
	permission.allowed=true;permission.limit=studio.warm_draws+2
	studio.warm();studio.warm()
	await stopped()
	check(studio.warm_draws==before+2,"one explicit invocation submits exactly two frames before its gate closes")
	check(not studio.prepared and not studio._pending.is_empty(),"interrupted warming preserves unfinished work")
	before=studio.warm_draws
	studio.queue_redraw();studio.size=Vector2(1168,360)
	await frames(6)
	check(studio.warm_draws==before,"paused preparation stays paused through another canvas redraw")
	permission.limit=-1
	studio.warm()
	await stopped()
	check(studio.prepared,"explicit resume prepares the exact live view")
	check(not studio.read_only and studio.camera.fov==40.0,"live preparation never switches to the carousel camera")
	before=studio.warm_draws
	studio.queue_redraw()
	await frames(4)
	check(studio.warm_draws==before,"prepared studios do not restart warming on canvas redraw")
	var held: Array=studio._held.duplicate()
	studio.adopt()
	check(studio._held.is_empty() and studio._pending.is_empty(),"live adoption releases held preparation state")
	var restored: bool=true
	for entry: Dictionary in held:
		var node: Object=entry.node.get_ref()
		if is_instance_valid(node): restored=restored and node.visible and is_equal_approx(node.extra_cull_margin,float(entry.margin))
	check(restored,"live adoption restores every held visibility and culling margin")
	check(studio.reflections.views.size()==2 and studio.showroom_viewport.msaa_3d==Viewport.MSAA_4X,"both original reflections and live sampling remain")
	await frames(8)
	var target: String=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(target)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		studio.showroom_viewport.get_texture().get_image().save_png(target.path_join("studio.png"))
	var report: Dictionary={"checks":checks,"failures":failures,"warm_draws":studio.warm_draws,"max_draw_ms":studio.max_draw_ms}
	FileAccess.open(target.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	studio.queue_free();studio=null
	await frames(32)
	print("GARAGE_WARM_SCHEDULING ",JSON.stringify(report))
	quit(1 if failures else 0)
