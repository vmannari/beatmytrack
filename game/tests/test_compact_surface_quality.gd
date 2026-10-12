extends SceneTree
## CG15/CG16: native production-surface inspection and optimization comparison.
var output: String="res://../docs/evidence/compact-surface-optimization-2026-10-11"
var phase: String="before"
var render_batched: bool=false
var failures: int=0
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)

func inspect(node: Node,result: Dictionary) -> void:
	if node is MeshInstance3D:
		result.instances+=1
		result.unique_meshes[node.mesh.get_instance_id()]=true
		for index: int in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(index)
			result.vertices+=arrays[Mesh.ARRAY_VERTEX].size()
			result.triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	for child: Node in node.get_children():inspect(child,result)
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):phase=argument.trim_prefix("--phase=")
		if argument=="--batched":render_batched=true
	if phase.ends_with("-batched"):
		render_batched=true
		phase=phase.trim_suffix("-batched")
	VisualGeometry.optimize_model_geometry=phase=="optimized"
	output=ProjectSettings.globalize_path(output).path_join(phase+("-batched" if render_batched else ""))
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	root.msaa_3d=Viewport.MSAA_4X
	var world:=Node3D.new()
	root.add_child(world)
	var car:=CarVisual.new()
	car.batch_parts=render_batched
	world.add_child(car)
	var stats: Dictionary={"instances":0,"unique_meshes":{},"vertices":0,"triangles":0}
	inspect(car,stats)
	stats.unique_meshes=stats.unique_meshes.size()
	print("MODEL_SURFACE_STATS ",JSON.stringify(stats))
	var report:=FileAccess.open(output.path_join("mesh-counts.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(stats,"\t"))
	report.close()
	ShowroomStudio.build(world,car)
	var control: CarVisual
	if phase=="optimized":
		VisualGeometry.optimize_model_geometry=false
		control=CarVisual.new()
		control.batch_parts=render_batched
		world.add_child(control)
		ShowroomStudio._studio_glass(control,{})
		control.visible=false
		VisualGeometry.optimize_model_geometry=true
	var camera:=Camera3D.new()
	camera.fov=38
	camera.current=true
	world.add_child(camera)
	for key: String in ["curved_body_left","curved_body_right"]:
		var arrays: Array=(CompactCoachwork.meshes[key] as ArrayMesh).surface_get_arrays(0)
		var side: float=-1 if key.ends_with("left") else 1
		var maximum: float=0
		var worst: Vector3
		var shoulder_rows: Dictionary={}
		for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
			var point: Vector3=arrays[Mesh.ARRAY_VERTEX][index]
			if point.y>=0.80 and point.y<=0.975 and point.z>0.74 and point.z<1.72:
				var station: int=roundi(point.z*1000000)
				if not shoulder_rows.has(station):shoulder_rows[station]={}
				shoulder_rows[station][roundi(point.y*1000000)]=true
			if point.y<0.82 or point.y>0.93 or minf(absf(point.z-1.28),absf(point.z+1.28))>0.55:continue
			var dy: float=(CompactCoachwork.body_width(point.y+0.00001,point.z)-CompactCoachwork.body_width(point.y-0.00001,point.z))/0.00002
			var dz: float=(CompactCoachwork.body_width(point.y,point.z+0.00001)-CompactCoachwork.body_width(point.y,point.z-0.00001))/0.00002
			var expected:=Vector3(side,-dy,-dz).normalized()
			var angle: float=expected.angle_to(arrays[Mesh.ARRAY_NORMAL][index])
			if angle>maximum:
				maximum=angle
				worst=point
		print("SIDE_NORMAL_ERROR ",key," ",rad_to_deg(maximum)," at ",worst)
		if phase!="before":
			check(maximum<deg_to_rad(0.05),"shoulder normals follow steel surface "+key)
			var signatures: Dictionary={}
			for station: int in shoulder_rows:
				var heights: Array=shoulder_rows[station].keys()
				heights.sort()
				signatures[var_to_bytes(heights)]=true
			check(signatures.size()==1,"uniform shoulder rows across wheel cut-out "+key)
	if phase!="before":
		for suffix: String in ["left","right"]:
			for axle: String in ["front","rear"]:
				var key: String="rolled_wheel_arch_"+axle+"_"+suffix
				var previous: ArrayMesh=ResourceLoader.load("res://assets/vehicles/compact_coachwork_v2/"+key+".res","ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE)
				var old: PackedVector3Array=previous.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var current: PackedVector3Array=(CompactCoachwork.meshes[key] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var z: float=-1.28 if axle=="front" else 1.28
				for point: Vector3 in old:
					if absf(Vector2(point.y-0.37,point.z-z).length()-0.405)>0.00001:continue
					var nearest: float=1000
					for other: Vector3 in current:nearest=minf(nearest,point.distance_to(other))
					check(nearest<0.0002,"original wheel-opening lip retained "+key)
	for pose: Array in [["side-left",Vector3(0,0.72,0),Vector3(-4.65,0.40,0.0)],["side-right",Vector3(0,0.72,0),Vector3(4.65,0.40,0.0)],["front-left",Vector3(0,0.65,0),Vector3(-3.6,1.8,-4.5)],["rear-left",Vector3(0,0.65,0),Vector3(-3.6,1.8,4.5)],["front-shoulder",Vector3(-0.86,0.88,-1.28),Vector3(-1.6,0.15,-0.12)],["rear-shoulder",Vector3(-0.86,0.88,1.28),Vector3(-1.6,0.15,-0.12)]]:
		var target: Vector3=(pose[1] as Vector3)*HandlingConfig.BODY_SCALE
		camera.position=target+(pose[2] as Vector3)
		camera.look_at(target)
		var reference: Image
		if control!=null:
			car.visible=false
			control.visible=true
			for frame: int in range(18):await process_frame
			await RenderingServer.frame_post_draw
			reference=root.get_texture().get_image()
			control.visible=false
			car.visible=true
		for frame: int in range(18):await process_frame
		await RenderingServer.frame_post_draw
		var rendered: Image=root.get_texture().get_image()
		rendered.save_png(output.path_join(str(pose[0])+".png"))
		if phase=="optimized":
			var original: Image=reference
			original.convert(Image.FORMAT_RGBA8)
			rendered.convert(Image.FORMAT_RGBA8)
			var a: PackedByteArray=original.get_data()
			var b: PackedByteArray=rendered.get_data()
			check(a==b,"pixel-identical corrected/optimized "+str(pose[0]))
			if a!=b:
				var changed: int=0
				var maximum: int=0
				for index: int in range(a.size()):
					if a[index]!=b[index]:
						changed+=1
						if changed<=3:print("DIFFERENT_PIXEL ",(index/4)%original.get_width()," ",(index/4)/original.get_width())
					maximum=maxi(maximum,absi(int(a[index])-int(b[index])))
				print("RENDER_DIFFERENCE ",pose[0]," changed_channels ",changed," max ",maximum)
	if phase in ["before","fixed"] and not render_batched:
		for part: Node in car.body.get_children():
			if part is MeshInstance3D and part.name.begins_with("RolledWheelArch"):part.visible=false
		var target:=Vector3(-0.86,0.88,1.28)*HandlingConfig.BODY_SCALE
		camera.position=target+Vector3(-1.6,0.15,-0.12)
		camera.look_at(target)
		for frame: int in range(18):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("rear-without-overlay.png"))
	print("SURFACE_INSPECTION ",phase," ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
