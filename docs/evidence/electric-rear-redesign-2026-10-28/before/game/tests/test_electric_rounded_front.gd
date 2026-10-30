extends SceneTree
## Measured production front silhouette and matched reference-angle review views.
const COACH = preload("res://vehicle/electric_coachwork.gd")
const EVIDENCE: String = "res://../docs/evidence/electric-rounded-front-2026-10-25"
var output: String = EVIDENCE
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
var reviewing_before: bool = false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func front_faces(car: CarVisual) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh: MeshInstance3D in car.body.find_children("FormedFront*","MeshInstance3D",true,false):
		result.append_array(mesh.mesh.get_faces())
	return result

func front_hit(faces: PackedVector3Array, x: float, y: float) -> float:
	var z: float = INF
	# Keep the same authored paint probes after the front's shared lowering.
	# The old 0.32 height now lies inside the lowered cooling opening.
	var origin: Vector3=Vector3(x,y,-3) if reviewing_before else COACH.deform_front_point(Vector3(x,y,-3))
	for index: int in range(0,faces.size(),3):
		var point: Variant = Geometry3D.ray_intersects_triangle(origin,Vector3.BACK,faces[index],faces[index+1],faces[index+2])
		if point != null: z = minf(z,point.z)
	return z

func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	reviewing_before=before
	if before:
		output += "/before"
		var author: GDScript = COACH
		author.source_code = FileAccess.get_file_as_string(output+"/game/vehicle/electric_coachwork.gd").replace("res://assets/vehicles/electric_coachwork_v5",output+"/electric_coachwork_v5")
		assert(author.reload() == OK)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var label: String = "simple" if simple else "full"
		var faces: PackedVector3Array = front_faces(car)
		var centre: float = front_hit(faces,0,0.60)
		var mid: float = front_hit(faces,0.45,0.60)
		var outer: float = front_hit(faces,0.75,0.60)
		var low: float = front_hit(faces,0,0.32)
		var high: float = front_hit(faces,0,0.72)
		metrics[label] = {"centre_z":centre,"mid_z":mid,"outer_z":outer,"low_z":low,"high_z":high,"half_width_bow":mid-centre,"outer_bow":outer-centre,"vertical_bow":low-centre}
		check(is_finite(centre) and is_finite(mid) and is_finite(outer) and is_finite(low) and is_finite(high),"all actual front surface rays hit, "+label)
		check(mid-centre > 0.045,"whole central face is bowed across its width, "+label)
		check(outer-centre > 0.16,"rounded corners sweep back into the wings, "+label)
		# The latest owner correction removes the rejected low bumper bulge.
		check(low-centre > 0.12 and high < centre,"lower bumper tucks behind the light brow, "+label)
		car.free()
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,960)
		var viewport := SubViewport.new()
		viewport.size = root.size
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		for simple: bool in [false,true]:
			var world := Node3D.new()
			viewport.add_child(world)
			var car := CarVisual.new()
			car.vehicle_id = "electric"
			car.simple_model = simple
			car.livery = VehicleLivery.defaults("electric")
			world.add_child(car)
			ShowroomStudio.build(world,car)
			var camera := Camera3D.new()
			world.add_child(camera)
			camera.current = true
			camera.fov = 34
			var shots: Array = [
				["head-on",Vector3(0,1.35,-5.2),Vector3(0,0.72,-0.35)],
				["front",Vector3(-3.0,2.2,-4.7),Vector3(0,0.72,-0.9)],
				["overhead",Vector3(0,6,-2.5),Vector3(0,0.6,-0.8)]]
			for shot: Array in shots:
				camera.position = shot[1]
				camera.look_at(shot[2])
				await settle()
				check(viewport.get_texture().get_image().save_png(output.path_join(("simple-" if simple else "full-")+shot[0]+".png")) == OK,"native front review "+str(shot[0]))
			world.free()
		viewport.free()
	var report := FileAccess.open(output+"/rounded-front.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"before":before,"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_ROUNDED_FRONT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
