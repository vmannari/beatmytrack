extends SceneTree
## Frozen implementation comparison. Disposable presentation fixtures only.
const BASELINE = "res://tests/fixtures/later_lap_stutter_before/trail_visibility.gd.txt"
var checks: int = 0
var failures: int = 0
var output: String = "res://../build/later-lap-stutter-2026-10-23"
var camera: Camera3D
var rows: Array[Dictionary] = []
var old_script: GDScript
var fixtures: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func fixture(legacy: bool) -> Dictionary:
	var encoder := SkidTrails.new(); root.add_child(encoder); encoder.set_process(false)
	var visibility: RefCounted = old_script.new(encoder.instances,encoder.mark_transforms) if legacy else encoder.trail_visibility
	return {"encoder":encoder,"view":visibility,"written":0,"loop_pages":32}

func write(row: Dictionary, count: int) -> void:
	var encoder: SkidTrails = row.encoder
	var view: RefCounted = row.view
	for n: int in range(count):
		var index: int = int(row.written)%SkidTrails.CAPACITY
		var page: int = index/TrailVisibility.PAGE_SIZE
		var local: int = index%TrailVisibility.PAGE_SIZE
		var angle: float = local*TAU/512.0
		var point := Vector3((page%int(row.loop_pages))*60.0+sin(angle)*8.0,0.03,cos(angle)*8.0)
		encoder.mark_transforms[index] = Transform3D(Basis(Vector3(0.15,0,0),Vector3(0.15,0.01,0),Vector3(0.0,0.0,0.32)),point)
		encoder.mark_colors[index] = Color(0.32,0.205,0.11,0.15+(local%7)*0.1)
		encoder.mark_custom[index] = Color(float(local%11)/10.0,0.35,1.0,0.65)
		if view.active: view.record(index,encoder.mark_colors,encoder.mark_custom)
		else:
			encoder.instances.set_instance_transform(index,encoder.mark_transforms[index])
			encoder.instances.set_instance_color(index,encoder.mark_colors[index])
			encoder.instances.set_instance_custom_data(index,encoder.mark_custom[index])
			encoder.instances.visible_instance_count = mini(SkidTrails.CAPACITY,encoder.instances.visible_instance_count+1)
		row.written += 1

func present(row: Dictionary, world: Transform3D = Transform3D.IDENTITY) -> float:
	var encoder: SkidTrails = row.encoder
	var start: int = Time.get_ticks_usec()
	row.view.present(camera,encoder.mark_colors,encoder.mark_custom,world)
	return (Time.get_ticks_usec()-start)/1000.0

func same(label: String) -> void:
	var a: Dictionary = fixtures[0]; var b: Dictionary = fixtures[1]
	var first: MultiMesh = a.encoder.instances; var second: MultiMesh = b.encoder.instances
	check(a.view.retained_count == b.view.retained_count and a.view._selection == b.view._selection,label+" retained population and frustum pages")
	check(first.visible_instance_count == second.visible_instance_count,label+" submitted population")
	check(first.buffer.slice(0,first.visible_instance_count*20) == second.buffer.slice(0,second.visible_instance_count*20),label+" exact submitted transforms, pigment and endpoint pressure")
	check(first.custom_aabb == second.custom_aabb,label+" exact culling bounds")

func move_to(x: float) -> void:
	camera.position = Vector3(x,24,18); camera.look_at(Vector3(x,0,0))

func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median_ms":values[values.size()/2],"p95_ms":values[mini(values.size()-1,int(values.size()*0.95))],"max_ms":values[-1]}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	old_script = GDScript.new()
	old_script.source_code = FileAccess.get_file_as_string(BASELINE).replace("\r\n","\n").replace("class_name TrailVisibility\n","")
	check(old_script.reload()==OK,"frozen original compiles")
	root.size = Vector2i(960,540)
	camera = Camera3D.new(); root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 30
	move_to(0)
	fixtures = [fixture(true),fixture(false)]
	for target: int in [511,1023,1024,1536,4096,16384,16385,16896,32768,32805]:
		for row: Dictionary in fixtures: write(row,target-int(row.written)); present(row)
		same("ring at "+str(target))
		for x: float in [0.0,60.0,900.0,1860.0,4000.0,0.0]:
			move_to(x)
			for row: Dictionary in fixtures: present(row)
			same("camera "+str(x)+" ring "+str(target))
	# Repeat a travelling camera over a late-race full ring. Each view change
	# happens in both implementations, with alternating timing order.
	for size: float in [30.0,180.0,1200.0]:
		camera.size = size
		var timings: Array = [[],[]]
		for step: int in range(96):
			move_to(float(step%32)*60.0)
			for k: int in range(2):
				var which: int = (step+k)%2
				timings[which].append(present(fixtures[which]))
			same("moving late ring "+str(size)+" step "+str(step))
		var before: Array[float] = []; before.assign(timings[0])
		var after: Array[float] = []; after.assign(timings[1])
		rows.append({"camera_size":size,"original":stats(before),"current":stats(after)})
	var emission: Array[float] = []
	for row: Dictionary in fixtures:
		var started: int = Time.get_ticks_usec()
		write(row,SkidTrails.CAPACITY)
		emission.append((Time.get_ticks_usec()-started)/float(SkidTrails.CAPACITY))
	for row: Dictionary in fixtures: present(row)
	same("complete active ring overwrite")
	rows.append({"append_original_us_per_mark":emission[0],"append_current_us_per_mark":emission[1]})
	# Several laps revisit the same road. Older pages therefore remain visible
	# together instead of being distributed over a wider and wider world.
	for row: Dictionary in fixtures:
		row.encoder.instances.visible_instance_count = 0; row.view.clear(); row.written = 0; row.loop_pages = 8
	camera.size = 180
	for lap: int in range(5):
		for row: Dictionary in fixtures: write(row,3276)
		var timings: Array = [[],[]]
		for step: int in range(16):
			move_to(float(step%8)*60.0)
			for k: int in range(2):
				var which: int = (step+k)%2
				timings[which].append(present(fixtures[which]))
			same("repeated route lap "+str(lap+1)+" step "+str(step))
		var before: Array[float] = []; before.assign(timings[0])
		var after: Array[float] = []; after.assign(timings[1])
		rows.append({"lap":lap+1,"retained_marks":fixtures[1].view.retained_count,"original":stats(before),"current":stats(after)})
	# Direct/full, compacted, offscreen append, partial page growth and retry.
	camera.size = 30; move_to(0)
	for row: Dictionary in fixtures:
		row.encoder.instances.visible_instance_count = 0; row.view.clear(); row.written = 0; row.loop_pages = 32
	for target: int in [1024,1025,1026,1535,1536,2049]:
		for row: Dictionary in fixtures: write(row,target-int(row.written)); present(row)
		same("retry growth "+str(target))
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE,Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		for row: Dictionary in fixtures: present(row,Transform3D(Basis.IDENTITY,Vector3(60,0,0)))
		same("projection and world transform "+str(projection))
	if DisplayServer.get_name() != "headless": await pixels()
	for row: Dictionary in fixtures: row.encoder.free()
	var report: Dictionary = {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string,"measurements":rows,"scope":"Desktop presentation-path comparison; not Android FPS"}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("LATER_LAP_TRAILS ",JSON.stringify(report))
	quit(1 if failures else 0)

func pixels() -> void:
	var light := DirectionalLight3D.new(); root.add_child(light); light.rotation_degrees = Vector3(-60,-30,0)
	var ground := MeshInstance3D.new(); ground.mesh = PlaneMesh.new(); ground.mesh.size = Vector2(32,32)
	ground.material_override = VisualGeometry.material(Color(0.6,0.62,0.63)); root.add_child(ground)
	move_to(2)
	for row: Dictionary in fixtures: present(row)
	check(fixtures[0].encoder.instances.visible_instance_count > 0,"native pixel comparison contains visible tyre marks")
	same("native pixel view")
	var images: Array[Image] = []
	for index: int in range(2):
		fixtures[0].encoder.visible = index == 0; fixtures[1].encoder.visible = index == 1
		for frame: int in range(4): await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image(); images.append(image)
		image.save_png(output.path_join("trails-"+("original" if index==0 else "current")+".png"))
	check(images[0].get_data()==images[1].get_data(),"original and current native rendered pixels exact")
