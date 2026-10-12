extends SceneTree
## CG10: actual baked bumper/body distance, closed caps and native overhead views.
var checks: int=0
var failures: int=0
var output: String="res://../docs/evidence/compact-front-bumper-2026-10-10"
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func nearest(point: Vector3,points: Array[Vector3]) -> float:
	var distance: float=1000
	for candidate: Vector3 in points:distance=minf(distance,point.distance_to(candidate))
	return distance
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var model:=CarVisual.new()
	model.batch_parts=false
	root.add_child(model)
	var mesh: ArrayMesh=CompactCoachwork.meshes.rounded_front_bumper
	var arrays: Array=mesh.surface_get_arrays(0)
	var outline: Array[Vector3]=[]
	var body: Array[Vector3]=[]
	for index: int in range(1025):
		var p: Vector3=CompactCoachwork.front_rim_point(lerpf(-1,1,index/1024.0),(0.53-0.33)/0.646)
		body.append(Vector3(p.x,0.53,p.z))
	for side: float in [-1,1]:
		for index: int in range(65):body.append(Vector3(side*CompactCoachwork.body_width(0.53,-1.84),0.53,lerpf(-1.84,-1.76,index/64.0)))
	for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
		var normal: Vector3=arrays[Mesh.ARRAY_NORMAL][index]
		check(is_finite(normal.x) and is_finite(normal.y) and is_finite(normal.z) and normal.length()>0.99,"finite unit bumper normal")
		if absf(arrays[Mesh.ARRAY_TEX_UV][index].y)<0.000001:outline.append(arrays[Mesh.ARRAY_VERTEX][index])
	check(outline.size()>=105,"actual baked outer contour samples")
	var minimum: float=1000
	var maximum: float=0
	for point: Vector3 in outline:
		var distance: float=nearest(point,body)
		minimum=minf(minimum,distance)
		maximum=maxf(maximum,distance)
		check(absf(distance-0.085)<0.001,"actual contour maintains uniform body projection")
		check(nearest(Vector3(-point.x,point.y,point.z),outline)<0.0002,"actual contour symmetric")
	var center: Vector3=outline[0]
	var shoulder: Vector3=outline[0]
	for point: Vector3 in outline:
		if absf(point.x)<absf(center.x):center=point
		if absf(absf(point.x)-0.65)<absf(absf(shoulder.x)-0.65):shoulder=point
	check(shoulder.z-center.z>0.06,"bowed bumper front follows bowed nose")
	for side: String in ["Left","Right"]:
		var cap: MeshInstance3D=model.body.get_node("FrontBumperCap"+side)
		var end: float=1.0 if side=="Left" else 0.0
		var shell: Array[Vector3]=[]
		for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
			if absf(arrays[Mesh.ARRAY_TEX_UV][index].x-end)<0.000001:shell.append(arrays[Mesh.ARRAY_VERTEX][index])
		var points: Array[Vector3]=[]
		for point: Vector3 in cap.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if point.distance_to(cap.mesh.get_aabb().get_center())>0.025:points.append(point)
		for point: Vector3 in shell:check(nearest(point,points)<0.0002,"actual cap meets shell "+side)
		for point: Vector3 in points:check(nearest(point,shell)<0.0002,"actual shell meets cap "+side)
		var indicator: MeshInstance3D=model.body.get_node("FrontBumperIndicator"+side)
		check(absf(indicator.rotation.y)>0.20,"indicator turns with bumper "+side)
		var mount: Vector3=CompactCoachwork._bumper_point(false,CompactCoachwork.front_bumper_parameter(indicator.position.x),0)
		check(indicator.position.distance_to(mount)<0.008,"indicator attached to curved front "+side)
	print("BUMPER_BODY_PROJECTION_METRES ",minimum," ",maximum," FRONT_BOW_METRES ",shoulder.z-center.z)
	model.queue_free()
	await process_frame
	var directory: String="user://compact_bumper_"+TrackLibrary.unique_id()
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
	for pose: Array in [["front-overhead",Vector3(0,0.55,-1.80),Vector3(0,3.0,-0.03)],["front-left",Vector3(-0.58,0.65,-1.99),Vector3(-1.35,0.65,-1.5)],["front-right",Vector3(0.58,0.65,-1.99),Vector3(1.35,0.65,-1.5)],["front-low",Vector3(0,0.63,-2.0),Vector3(0,0.24,-2.65)]]:
		var target: Vector3=(pose[1] as Vector3)*HandlingConfig.BODY_SCALE
		view.camera.fov=38
		view.camera.position=target+(pose[2] as Vector3)
		view.camera.look_at(target)
		for frame: int in range(12):await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(str(pose[0])+"-1280.png"))==OK,"capture "+str(pose[0]))
	view.reset_view()
	view.set_zoom(0.77)
	for frame: int in range(12):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("garage-1280.png"))==OK,"capture Garage")
	app.queue_free()
	await process_frame
	print("COMPACT_FRONT_BUMPER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
