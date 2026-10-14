extends SceneTree
## Paired visual and saturated-batch cost diagnostic; never races or uploads.
const OUTPUT: String = "res://../docs/evidence/tire-ribbons-2026-10-13"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func quantiles(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[int(values.size()*0.95)]}

func draw_mark(effect: Node3D, a: Vector3, b: Vector3, dirt: float, kind: int, strength: float, wheel: int = 0) -> void:
	if effect is SkidTrails: effect._mark(a,b,dirt,kind,strength,wheel)
	else: effect._mark(a,b,dirt,kind,strength)

func ribbon_contract(after: SkidTrails) -> void:
	after.clear()
	after._mark(Vector3(0,0.028,0),Vector3(0,0.028,0.4),0,0,0.4,0,0.2,0.6)
	after._mark(Vector3(0,0.028,0.4),Vector3(0.1,0.07,0.8),0,0,0.8,0,0.6,1.0)
	var old: Transform3D = after.mark_transforms[0]
	var fresh: Transform3D = after.mark_transforms[1]
	var old_side := Vector3(old.basis.y.x,0,old.basis.y.z)
	check(old_side.is_equal_approx(fresh.basis.x),"curve and width-change joins share their exact cross-section")
	for edge: float in [-0.5,0.5]:
		check((old.origin+old.basis.z*0.5+old_side*edge).is_equal_approx(fresh.origin-fresh.basis.z*0.5+fresh.basis.x*edge),"both shared corners meet on a slope without overlapping bands")
	check(after.mark_custom[0].a == after.mark_custom[1].g,"pressure and opacity have a shared contact value")
	after._mark(Vector3(0.1,0.07,0.8),Vector3(0.2,0.07,1.2),0,2,0.8,0)
	var changed: Transform3D = after.mark_transforms[2]
	check(not changed.basis.x.is_equal_approx(Vector3(fresh.basis.y.x,0,fresh.basis.y.z)),"surface change starts its own ribbon width")
	after.clear()
	after._mark(Vector3.ZERO,Vector3(0.4,0,0),0,0,1.0,0)
	check(after.cursor == 1 and after.instances.visible_instance_count == 1,"reset restores an empty independent ribbon ring")
	var immutable: Transform3D = after.mark_transforms[0]
	after._mark(Vector3(0.4,0,0),Vector3(0.8,0,0.1),0,0,1.0,0)
	check(after.mark_transforms[0] == immutable,"appending never edits or reuploads the previous segment")
	after._mark(Vector3(5,0,5),Vector3(5,0,5),0,0,1.0,0)
	after._mark(Vector3(5,0,5),Vector3(5,1,5),0,0,1.0,0)
	check(after.cursor == 2,"degenerate contacts do not create invalid transforms")

func surfaces(effect: Node3D) -> void:
	effect.clear()
	for row: int in range(5):
		var kind: int = [0,1,2,7,8][row]
		for i: int in range(80):
			var a: float = float(i)/80.0*PI
			var b: float = float(i+1)/80.0*PI
			draw_mark(effect,Vector3(-7+14.0*i/80,0.028,-7+row*3.5+sin(a)),Vector3(-7+14.0*(i+1)/80,0.028,-7+row*3.5+sin(b)),0,kind,0.85)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var after := SkidTrails.new()
	root.add_child(after)
	ribbon_contract(after)
	var effects: Array[Node3D] = [after]
	var before: Node3D
	var baseline: String = OUTPUT+"/skid_trails-before.gd.txt"
	if FileAccess.file_exists(baseline):
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(baseline).replace("\r\n","\n").replace("class_name SkidTrails\n","")
		check(script.reload() == OK,"session baseline compiles")
		before = script.new()
		root.add_child(before)
		effects.push_front(before)
	var state := VehicleState.new()
	var input := DriveFrame.sample(0,0,1)
	var cpu: Dictionary = {}
	var cpu_samples: Dictionary = {"before":[],"after":[]}
	for repeat: int in range(9):
		var order: Array[Node3D] = effects.duplicate()
		if repeat%2 == 1: order.reverse()
		for effect: Node3D in order:
			effect.clear()
			var started: int = Time.get_ticks_usec()
			for i: int in range(6000):
				var angle: float = i*0.02
				state.position = Vector2(sin(angle),cos(angle))*22.0
				state.heading = angle+PI*0.5
				state.velocity = state.forward()*25.0+state.right()*8.0
				effect.sample(state,input)
			cpu_samples["before" if effect == before else "after"].append(float(Time.get_ticks_usec()-started)/6000.0)
	for tag: String in cpu_samples:
		if cpu_samples[tag].is_empty(): continue
		var times: Array[float] = []
		times.assign(cpu_samples[tag])
		cpu[tag] = quantiles(times)
	check(after.instances.visible_instance_count == after.CAPACITY,"ring saturates at existing capacity")
	if before != null:
		check(before.cursor == after.cursor and before.mark_colors == after.mark_colors,"mark count and approved average pigment preserved")
		var pressure_preserved: bool = true
		for i: int in range(after.CAPACITY):
			pressure_preserved = pressure_preserved and is_equal_approx((after.mark_custom[i].g+after.mark_custom[i].a)*0.5,before.mark_custom[i].g)
		check(pressure_preserved,"ribbon endpoint pressures retain each original average physics intensity")
	after.clear()
	after._mark(Vector3(0,0.028,0),Vector3(0,0.028,0.4),0,0,0.8)
	check(is_equal_approx(after.mark_transforms[0].basis.z.length(),0.4),"straight segments meet without six-centimetre opacity overlap")
	check(after.instances.mesh.surface_get_array_len(0) == 4 and after.instances.mesh.surface_get_array_index_len(0) == 6,"joined ribbon uses four indexed vertices and two triangles")
	print("TIRE_MARK_SAMPLE_US: ",JSON.stringify(cpu))
	if DisplayServer.get_name() == "headless":
		for effect: Node3D in effects: effect.free()
		print("TIRE_RIBBON_TESTS: ",checks," checks, ",failures," failures")
		quit(1 if failures else 0)
		return
	root.size = Vector2i(1600,900)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_2X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.2,0.2,0.2)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58,-25,0)
	light.light_energy = 0.8
	root.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.29,0.29,0.27)
	material.roughness = 1.0
	ground.mesh = plane
	ground.material_override = material
	root.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 26
	root.add_child(camera)
	camera.position = Vector3(0,25,16)
	camera.look_at(Vector3.ZERO)
	for effect: Node3D in effects:
		effect.clear()
		for ring: int in range(8):
			var radius: float = 5.0+ring*0.8
			var count: int = int(TAU*radius/0.32)
			for i: int in range(count):
				var a: float = TAU*i/count
				var b: float = TAU*(i+1)/count
				draw_mark(effect,Vector3(sin(a)*radius,0.028,cos(a)*radius),Vector3(sin(b)*radius,0.028,cos(b)*radius),0.7 if ring%3 == 0 else 0.0,0,0.75)
		# Straight control at normal spacing is measurable independent of curvature.
		for i: int in range(60):
			draw_mark(effect,Vector3(-9.6+i*0.32,0.028,0),Vector3(-9.6+(i+1)*0.32,0.028,0),0,0,0.85)
		effect.hide()
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var reports: Array[Dictionary] = []
	var seam_contrast: Dictionary = {}
	for pass_index: int in range(3):
		var order: Array[Node3D] = effects.duplicate()
		if pass_index%2 == 1: order.reverse()
		for effect: Node3D in order:
			var tag: String = "before" if effect == before else "after"
			effect.show()
			for i: int in range(60): await process_frame
			if pass_index == 0:
				await RenderingServer.frame_post_draw
				var picture: Image = root.get_texture().get_image()
				check(picture.save_png(OUTPUT+"/"+RenderingServer.get_current_rendering_method()+"-"+tag+".png") == OK,"actual tire-mark screenshot saved")
				var density: Array[float] = []
				var seam_total: float = 0.0
				var middle_total: float = 0.0
				for i: int in range(15,45):
					for fraction: float in [0.0,0.5]:
						var pixel: Vector2 = camera.unproject_position(Vector3(-9.6+(i+fraction)*0.32,0.028,0))
						var darkest: float = 1.0
						for dy: int in range(-2,3):
							var c: Color = picture.get_pixel(roundi(pixel.x),roundi(pixel.y)+dy)
							darkest = minf(darkest,(c.r+c.g+c.b)/3.0)
						density.append(darkest)
						if fraction == 0.0: seam_total += darkest
						else: middle_total += darkest
				seam_contrast[tag] = absf(seam_total-middle_total)/30.0
				print("TIRE_RIBBON_DENSITY ",tag,": ",JSON.stringify(quantiles(density)))
				# Measure the existing full race budget, with identical visible overdraw.
				for i: int in range(effect.instances.visible_instance_count,SkidTrails.CAPACITY):
					var radius: float = 5.0+float(i%8)*0.8
					var a: float = float(i)*0.32/radius
					var b: float = a+0.32/radius
					draw_mark(effect,Vector3(sin(a)*radius,0.028,cos(a)*radius),Vector3(sin(b)*radius,0.028,cos(b)*radius),0.7 if i%3 == 0 else 0.0,0,0.75)
				for i: int in range(60): await process_frame
			var frame: Array[float] = []
			var gpu: Array[float] = []
			var render: Array[float] = []
			var last: int = Time.get_ticks_usec()
			for i: int in range(240):
				await process_frame
				var now: int = Time.get_ticks_usec()
				frame.append(float(now-last)/1000.0)
				last = now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
				render.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			reports.append({"stage":tag,"pass":pass_index,"frame_ms":quantiles(frame),"gpu_ms":quantiles(gpu),"render_cpu_ms":quantiles(render),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"marks":effect.instances.visible_instance_count})
			effect.hide()
	var file := FileAccess.open(OUTPUT+"/"+RenderingServer.get_current_rendering_method()+"-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"cpu_sample_us":cpu,"cpu_samples_us":cpu_samples,"seam_contrast":seam_contrast,"stages":reports},"\t"))
	file.close()
	print("TIRE_RIBBON_CONTRAST: ",JSON.stringify(seam_contrast))
	if before != null: check(float(seam_contrast.after) <= float(seam_contrast.before)+0.002,"straight ribbon does not add repeated opacity seams")
	print("TIRE_RIBBON_PROFILE: ",JSON.stringify(reports))
	for effect: Node3D in effects:
		surfaces(effect)
		effect.show()
		for i: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT+"/"+RenderingServer.get_current_rendering_method()+"-surfaces-"+("before" if effect == before else "after")+".png") == OK,"rubber, grass, dirt, snow and ice comparison saved")
		effect.hide()
	for effect: Node3D in effects: effect.free()
	print("TIRE_RIBBON_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
