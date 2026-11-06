extends SceneTree
## Replay old/shared staging on the very same full live Garage and reflections.
const Queue = preload("res://race/world_render_preparation.gd")
const Before = preload("res://../docs/evidence/graphics-preparation-2026-11-04/before/game/race/world_render_preparation.gd")
const Shared = preload("res://rendering/graphics_preparation.gd")
var checks: int = 0
var failures: int = 0
var studio: Node
var rows: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("GRAPHICS_GARAGE_FAIL ",label)
func draw() -> bool:
	studio._submit_render()
	await RenderingServer.frame_post_draw
	await process_frame
	return true
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: printerr("GRAPHICS_GARAGE_TIMEOUT"); quit(1))
	root.size = Vector2i(1280,720)
	Engine.time_scale = 0.0
	studio = load("res://ui/garage_preloaded_studio.gd").new()
	studio.vehicle_id = "compact"
	studio.garage_mode = true
	studio.framing_scale = 0.84
	studio.size = Vector2(1168,360)
	studio.livery = VehicleLivery.defaults("compact")
	studio.livery.colors.body = "32b5d7"
	studio.livery.pattern = "offset_gt"
	studio.permitted = func() -> bool: return true
	root.add_child(studio)
	while not studio._warm_setup_ready: await process_frame
	studio.warm()
	while studio.warming: await process_frame
	check(studio.prepared,"actual live Garage prepared")
	check(studio.reflections.views.size() == 2,"both original planar views remain")
	studio.adopt()
	for _i: int in range(8): await draw()
	var reference: Image = studio.showroom_viewport.get_texture().get_image()
	check(reference.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join("reference.png")) == OK,"full live reference")
	for control: bool in [true,false]:
		Before.warmed.clear()
		Shared.invalidate()
		var queue: Node = Before.new() if control else Queue.new()
		studio.add_child(queue)
		queue.hold(studio.camera.get_parent())
		var began: int = Time.get_ticks_usec()
		check(await queue.prepare(draw,func() -> bool: return true),"actual Garage replay completes "+str(control))
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		for _i: int in range(4): await draw()
		var actual: Image = studio.showroom_viewport.get_texture().get_image()
		check(actual.get_data() == reference.get_data(),"exact same-owner Garage pixels "+str(control))
		check(actual.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join("garage-"+str(control)+".png")) == OK,"native Garage replay evidence")
		rows.append({"control":control,"ms":elapsed,"draws":queue.frame_groups,"exact":actual.get_data() == reference.get_data()})
		queue.free()
	check(studio.showroom_viewport.msaa_3d == Viewport.MSAA_4X,"full original live sampling retained")
	check(studio.showroom_viewport.find_world_3d() == studio.reflections.views[0].find_world_3d(),"reflections still share the actual world")
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	studio.queue_free()
	studio = null
	Engine.time_scale = 1.0
	for _i: int in range(16): await process_frame
	print("GRAPHICS_GARAGE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
