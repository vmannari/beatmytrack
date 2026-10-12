extends SceneTree
## CG12: inspect actual hood crown and matching accent geometry; native views.
var checks: int=0
var failures: int=0
var output: String="res://../docs/evidence/compact-shaped-hood-2026-10-10"
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var model:=CarVisual.new()
	model.batch_parts=false
	root.add_child(model)
	var steel: Array=(CompactCoachwork.meshes.crowned_hood as ArrayMesh).surface_get_arrays(0)
	var paint: Array=(CompactCoachwork.meshes.hood_accent as ArrayMesh).surface_get_arrays(0)
	var surface: Dictionary={}
	var middle: Array[Vector3]=[]
	for index: int in range(steel[Mesh.ARRAY_VERTEX].size()):
		var point: Vector3=steel[Mesh.ARRAY_VERTEX][index]
		surface[Vector2i(roundi(point.x*10000),roundi(point.z*10000))]=point
		if absf(steel[Mesh.ARRAY_TEX_UV][index].y-0.25)<0.000001:middle.append(point)
		var normal: Vector3=steel[Mesh.ARRAY_NORMAL][index]
		check(is_finite(normal.x) and is_finite(normal.y) and is_finite(normal.z) and normal.length()>0.99,"finite unit hood normals")
	for point: Vector3 in paint[Mesh.ARRAY_VERTEX]:
		var key:=Vector2i(roundi(point.x*10000),roundi(point.z*10000))
		check(surface.has(key) and point.distance_to((surface.get(key,Vector3.ZERO) as Vector3)+Vector3.UP*0.0015)<0.00001,"actual accent vertices match shaped steel")
	var center: Vector3=middle[0]
	var edge: Vector3=middle[0]
	for point: Vector3 in middle:
		if absf(point.x)<absf(center.x):center=point
		if absf(point.x)>absf(edge.x):edge=point
	check(center.y-edge.y>0.055 and center.y-edge.y<0.080,"visible restrained crown in actual mesh")
	for point: Vector3 in middle:
		var opposite:=Vector2i(roundi(-point.x*10000),roundi(point.z*10000))
		check(surface.has(opposite) and absf((surface[opposite] as Vector3).y-point.y)<0.00001,"actual hood shape symmetric")
	print("HOOD_CROWN_METRES ",center.y-edge.y," CENTER ",center," SIDE ",edge)
	model.queue_free()
	await process_frame
	var directory: String="user://compact_hood_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(directory.path_join("records.json"))
	app.library=TrackLibrary.new(directory)
	app.cloud_root_override=directory.path_join("cloud")
	root.size=Vector2i(1280,720)
	root.add_child(app)
	while not app.startup_complete:await process_frame
	VehicleCatalog.selected="compact"
	app._show_screen("garage")
	await create_timer(0.45).timeout
	var view: CarShowroom=app.root_ui.find_child("GarageShowroom",true,false)
	for pose: Array in [["hood-top",Vector3(0,1.02,-1.55),Vector3(0,2.0,-0.03)],["hood-front-left",Vector3(-0.12,1.02,-1.55),Vector3(-1.3,0.65,-1.6)],["hood-front-right",Vector3(0.12,1.02,-1.55),Vector3(1.3,0.65,-1.6)],["hood-low",Vector3(0,1.02,-1.55),Vector3(0,0.30,-2.1)]]:
		var target: Vector3=(pose[1] as Vector3)*HandlingConfig.BODY_SCALE
		view.camera.fov=38
		view.camera.position=target+(pose[2] as Vector3)
		view.camera.look_at(target)
		for frame: int in range(12):await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(str(pose[0])+"-1280.png"))==OK,"native capture "+str(pose[0]))
	view.reset_view()
	view.elevation=0.65
	view.set_zoom(0.78)
	for frame: int in range(12):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("garage-high-1280.png"))==OK,"native Garage capture")
	app.queue_free()
	await process_frame
	print("COMPACT_HOOD: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
