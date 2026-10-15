extends SceneTree
## Real surface seating, exact restored pixels, stroke reversal and aggregate native render work.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-wash-polish-2026-10-14"
var view: CarShowroom

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func settle() -> void:
	for tick: int in range(5): await frame()
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func pixels() -> PackedByteArray:
	return view.showroom_viewport.get_texture().get_image().get_data()
func project(point: Vector3) -> Vector2:
	return view.camera.unproject_position(view.car.body.global_transform*point)*view.size/Vector2(view.showroom_viewport.size)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
	output=ProjectSettings.globalize_path(output).path_join("quality")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	view=CarShowroom.new()
	view.garage_mode=true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	view.set_process(false)
	view.yaw=-PI*0.5
	view.elevation=0.24
	view.set_zoom(0.62)
	await settle()
	# Finish the native sky/radiance and initial target work before equivalence capture.
	for tick: int in range(30): await frame()
	var original := PackedByteArray()
	if DisplayServer.get_name()!="headless":
		original=pixels()
		view.showroom_viewport.get_texture().get_image().save_png(output.path_join("native-baseline.png"))
	var condition: Dictionary=view.weathering.snapshot()
	view.set_wash_mode(true)
	var effect: Node3D=view.wash_effect
	var resources: Array=[effect.foam.multimesh,effect.water.multimesh]
	var surface: Dictionary=view.pick_body_surface(project(Vector3(-0.85,0.56,0.05)))
	check(not surface.is_empty(),"actual door contact")
	check(effect.foam.multimesh.use_custom_data and effect.water.multimesh.use_custom_data,"fixed pool lifetime attributes")
	var height: float=0.0
	for point: Vector3 in effect.foam.multimesh.mesh.get_faces(): height=maxf(height,point.y)
	check(height>0.095,"rendered lather includes raised rounded air pockets")
	for tick: int in range(24):
		effect.set_contact(surface)
		effect.advance(1.0/30.0,true)
	await settle()
	await capture("door-detail")
	effect.mitt.hide()
	effect.water.hide()
	await settle()
	await capture("lather-only")
	if DisplayServer.get_name()!="headless": check(pixels()!=original,"lather visible on real opaque paint")
	# The same lather displaced out from the panel must not paint the air/background.
	effect.reset()
	check(surface.has("normal") and surface.has("position"),"effect cleanup leaves caller contact intact")
	var unsupported: Dictionary=surface.duplicate()
	unsupported.position += unsupported.normal*0.22
	for tick: int in range(20):
		effect.set_contact(unsupported)
		effect.advance(1.0/30.0,true)
	effect.mitt.hide()
	effect.water.hide()
	await settle()
	if DisplayServer.get_name()!="headless":
		view.showroom_viewport.get_texture().get_image().save_png(output.path_join("native-unsupported.png"))
		var unsupported_pixels: PackedByteArray=pixels()
		# Keep identical native depth-read/transparent passes for the clipping control.
		# Mobile's resolve can round the whole image by one level when this pass is used.
		for index: int in range(effect.foam.multimesh.instance_count):
			var data: Color=effect.foam.multimesh.get_instance_custom_data(index)
			data.b=0.0
			effect.foam.multimesh.set_instance_custom_data(index,data)
		await settle()
		view.showroom_viewport.get_texture().get_image().save_png(output.path_join("native-unsupported-control.png"))
		check(pixels()==unsupported_pixels,"unsupported lather contributes exact zero pixels")
	await capture("no-floating-lather")
	effect.water.show()
	effect.reset()
	# Rapidly reversing contact cannot snap the mitt half a turn in one rendered step.
	var previous: Vector3=Vector3.ZERO
	for tick: int in range(90):
		var point: Vector3=Vector3(-0.85,0.56,0.05+sin(float(tick)*0.48)*0.25)
		var contact: Dictionary=view.pick_body_surface(project(point))
		effect.set_contact(contact)
		effect.advance(1.0/60.0,true)
		var axis: Vector3=effect.mitt.global_basis.x.normalized()
		if tick>0: check(previous.dot(axis)>0.98,"continuous mitt orientation through reversal")
		check(effect.mitt.global_basis.y.normalized().dot(contact.normal)>0.999,"pressure retains surface normal")
		previous=axis
	check(resources==[effect.foam.multimesh,effect.water.multimesh],"reversal reuses fixed resources")
	check(view.weathering.snapshot()==condition,"visual-only updates never clean or persist condition")
	effect.reset()
	view.set_wash_mode(false)
	await settle()
	if DisplayServer.get_name()!="headless":
		view.showroom_viewport.get_texture().get_image().save_png(output.path_join("native-restored.png"))
		check(pixels()==original,"ending wash restores exact original render")
	await budget(surface)
	await responsive()
	view.queue_free()
	await frame()
	check(not is_instance_valid(effect),"teardown releases refined effect")
	print("GARAGE_WASH_POLISH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func budget(surface: Dictionary) -> void:
	if DisplayServer.get_name()=="headless": return
	var targets: Array[RID]=[view.showroom_viewport.get_viewport_rid()]
	for target: SubViewport in view.reflections.views: targets.append(target.get_viewport_rid())
	for target: RID in targets: RenderingServer.viewport_set_measure_render_time(target,true)
	var rows: Array[Dictionary]=[]
	for active: bool in [false,true,false]:
		view.set_wash_mode(active)
		var cpu: Array[float]=[]
		var gpu: Array[float]=[]
		var calls: Array[int]=[]
		var triangles: Array[int]=[]
		for tick: int in range(90):
			if active:
				view.wash_effect.set_contact(surface)
				view.wash_effect.advance(1.0/60.0,true)
			await frame()
			if tick<30: continue
			var total_cpu: float=0.0
			var total_gpu: float=0.0
			var total_calls: int=0
			var total_triangles: int=0
			for target: RID in targets:
				total_cpu+=RenderingServer.viewport_get_measured_render_time_cpu(target)
				total_gpu+=RenderingServer.viewport_get_measured_render_time_gpu(target)
				total_calls+=RenderingServer.viewport_get_render_info(target,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
				total_triangles+=RenderingServer.viewport_get_render_info(target,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			cpu.append(total_cpu)
			gpu.append(total_gpu)
			calls.append(total_calls)
			triangles.append(total_triangles)
		cpu.sort()
		gpu.sort()
		calls.sort()
		triangles.sort()
		rows.append({"active":active,"samples":cpu.size(),"cpu_ms":cpu[cpu.size()/2],"gpu_ms":gpu[gpu.size()/2],"draw_calls":calls[calls.size()/2],"triangles":triangles[triangles.size()/2]})
	check(rows[0].draw_calls==rows[2].draw_calls and rows[0].triangles==rows[2].triangles,"idle render work restores exactly")
	var report: Dictionary={"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"views":targets.size(),"main":var_to_str(view.showroom_viewport.size),"reflection":var_to_str(view.reflections.views[0].size),"samples":rows,"note":"Aggregate native CPU/GPU render timings across original three views on a shared desktop; not phone FPS or an improvement claim."}
	var file:=FileAccess.open(output.path_join("render-work.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("WASH_POLISH_RENDER_WORK ",JSON.stringify(report))

func responsive() -> void:
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1600,720)]:
		root.size=dimensions
		view.yaw=-0.92
		view.elevation=0.59
		view.set_zoom(0.55)
		view.set_wash_mode(true)
		await settle()
		var contact: Dictionary=view.pick_body_surface(project(Vector3(-0.28,0.62,-1.5)))
		check(not contact.is_empty(),"hood contact at "+str(dimensions.x))
		for tick: int in range(20):
			view.wash_effect.set_contact(contact)
			view.wash_effect.advance(1.0/30.0,true)
		await settle()
		await capture("hood-"+str(dimensions.x))
		view.set_wash_mode(false)
