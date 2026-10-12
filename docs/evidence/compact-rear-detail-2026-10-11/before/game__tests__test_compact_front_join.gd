extends SceneTree
## CG08: actual baked front/fender/hood boundaries and native app close-ups.
var failures: int=0
var checks: int=0
var output: String="res://../docs/evidence/compact-front-join-2026-10-10"

func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)

func vertices(key: String) -> Array[Vector3]:
	var mesh: ArrayMesh=CompactCoachwork.meshes[key]
	var result: Array[Vector3]=[]
	var unique: Dictionary={}
	for point: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:unique[point]=true
	for point: Vector3 in unique:result.append(point)
	return result

func edge(key: String,predicate: Callable) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for point: Vector3 in vertices(key):
		if predicate.call(point):result.append(point)
	return result

func matching(a: Array[Vector3],b: Array[Vector3],label: String) -> void:
	check(not a.is_empty() and not b.is_empty(),label+" nonempty")
	var maximum: float=0
	for pair: Array in [[a,b],[b,a]]:
		for point: Vector3 in pair[0]:
			var distance: float=1000
			for other: Vector3 in pair[1]:distance=minf(distance,point.distance_to(other))
			maximum=maxf(maximum,distance)
	print("FRONT_EDGE_MAX_METRES ",label," ",maximum)
	check(maximum<0.0002,label+" matching baked vertices within 0.2mm")

func seam_normals(first: String,second: String,label: String) -> void:
	var a: Array=(CompactCoachwork.meshes[first] as ArrayMesh).surface_get_arrays(0)
	var b: Array=(CompactCoachwork.meshes[second] as ArrayMesh).surface_get_arrays(0)
	var shared: int=0
	var maximum: float=0
	var normals: Dictionary={}
	for index: int in range(b[Mesh.ARRAY_VERTEX].size()):normals[b[Mesh.ARRAY_VERTEX][index]]=b[Mesh.ARRAY_NORMAL][index]
	for index: int in range(a[Mesh.ARRAY_VERTEX].size()):
		var point: Vector3=a[Mesh.ARRAY_VERTEX][index]
		if normals.has(point):
			shared+=1
			maximum=maxf(maximum,(a[Mesh.ARRAY_NORMAL][index] as Vector3).angle_to(normals[point]))
	print("FRONT_SEAM_NORMAL_DEGREES ",label," ",rad_to_deg(maximum)," vertices ",shared)
	check(shared>=24,label+" shared normal samples")
	check(maximum<deg_to_rad(8),label+" smooth lighting across join")

func retained_rear_profiles() -> void:
	# The owner repairs shoulder shading with a new Y sampling grid. Check
	# the actual original profile points, rather than requiring old topology.
	for side: float in [-1,1]:
		var suffix: String="left" if side<0 else "right"
		for kind: String in ["rear_shoulder","rear_corner"]:
			var previous: ArrayMesh=load("res://assets/vehicles/compact_coachwork_v2/"+kind+"_"+suffix+".res")
			var samples: Array[Vector3]=[]
			for row: int in range(25):
				var v: float=CompactCoachwork.body_fraction(lerpf(0.33,1.01,row/24.0),1.01)
				var columns: int=12 if kind=="rear_shoulder" else 24
				for column: int in range(columns+1):
					samples.append(CompactCoachwork.rear_shoulder_point(side,column/float(columns),v) if kind=="rear_shoulder" else CompactCoachwork.rear_corner_point(side,column/float(columns),v))
			for point: Vector3 in previous.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var distance: float=1000
				for sample: Vector3 in samples:distance=minf(distance,point.distance_to(sample))
				check(distance<0.0002,"original rear profile point retained "+kind+suffix)
	var previous: ArrayMesh=load("res://assets/vehicles/compact_coachwork_v2/rear_coachwork.res")
	var samples: Array[Vector3]=[]
	for row: int in range(25):
		var v: float=CompactCoachwork.body_fraction(lerpf(0.33,1.01,row/24.0),1.01)
		for column: int in range(41):samples.append(CompactCoachwork.rear_face_point(column/40.0,v))
	for point: Vector3 in previous.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var distance: float=1000
		for sample: Vector3 in samples:distance=minf(distance,point.distance_to(sample))
		check(distance<0.0002,"original rear face profile retained")

func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String="user://compact_front_join_"+TrackLibrary.unique_id()
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
	var retained: Dictionary=CompactCoachwork.meshes.duplicate()
	retained.merge(preload("res://vehicle/compact_glazing.gd").sheets)
	var changed: Array[String]=["curved_body_left","curved_body_right","crowned_hood","hood_accent","rolled_wheel_arch_front_left","rolled_wheel_arch_front_right","rolled_wheel_arch_rear_left","rolled_wheel_arch_rear_right","arch_rubber_seal_front_left","arch_rubber_seal_front_right","rounded_front_bumper","rear_shoulder_left","rear_shoulder_right","rear_corner_left","rear_corner_right","rear_coachwork"]
	for key: String in retained:
		var previous: String="res://assets/vehicles/compact_coachwork_v2/"+key+".res"
		if key not in changed and ResourceLoader.exists(previous):
			var earlier: ArrayMesh=load(previous)
			check(var_to_bytes(earlier.surface_get_arrays(0))==var_to_bytes((retained[key] as ArrayMesh).surface_get_arrays(0)),"previous mirror/rear/cabin/glass geometry exact "+key)
	retained_rear_profiles()
	var hood_front: Array[Vector3]=edge("crowned_hood",func(p: Vector3) -> bool:
		return absf(p.y-(0.976+0.010*(1-pow(p.x/CompactCoachwork.front_rim_width(),2))))<0.00001)
	var nose_top: Array[Vector3]=[]
	for key: String in ["front_coachwork","front_corner_left","front_corner_right"]:
		nose_top.append_array(edge(key,func(p: Vector3) -> bool:
			return absf(p.y-(0.976+0.010*(1-pow(p.x/CompactCoachwork.front_rim_width(),2))))<0.00001))
	matching(hood_front,nose_top,"hood/front/corner rim")
	for side: float in [-1,1]:
		var suffix: String="left" if side<0 else "right"
		matching(edge("curved_body_"+suffix,func(p: Vector3) -> bool:return absf(p.z+1.84)<0.00001),edge("front_corner_"+suffix,func(p: Vector3) -> bool:return absf(p.z+1.84)<0.00001),"fender/corner "+suffix)
		matching(edge("crowned_hood",func(p: Vector3) -> bool:
			for index: int in range(25):
				if p.distance_to(CompactCoachwork.hood_point(side,index/24.0))<0.00001:return true
			return false),edge("curved_body_"+suffix,func(p: Vector3) -> bool:return p.z<=-1.015+0.00001 and absf(p.y-CompactCoachwork.body_upper(p.z))<0.00001),"hood/fender "+suffix)
		var face_edge: Array[Vector3]=edge("front_coachwork",func(p: Vector3) -> bool:
			# Membership uses the analytical endpoint to allow the tiny hood crown.
			for index: int in range(25):
				if p.distance_to(CompactCoachwork.front_face_point(0 if side<0 else 1,index/24.0))<0.00001:return true
			return false)
		var corner_edge: Array[Vector3]=edge("front_corner_"+suffix,func(p: Vector3) -> bool:
			for index: int in range(25):
				if p.distance_to(CompactCoachwork.front_corner_point(side,0,index/24.0))<0.00001:return true
			return false)
		matching(face_edge,corner_edge,"face/corner "+suffix)
		seam_normals("front_coachwork","front_corner_"+suffix,"face/corner "+suffix)
		seam_normals("curved_body_"+suffix,"front_corner_"+suffix,"fender/corner "+suffix)
		for index: int in range(25):
			var v: float=index/24.0
			var a: Vector3=CompactCoachwork.front_face_point(0 if side<0 else 1,v)
			var front_tangent: Vector3=(CompactCoachwork.front_face_point(0.0001 if side<0 else 0.9999,v)-a).normalized()
			var corner_tangent: Vector3=(CompactCoachwork.front_corner_point(side,0.0001,v)-a).normalized()
			check(absf(front_tangent.dot(corner_tangent))>0.999,"front/corner tangent continuity")
	check(view.car.rolling_wheels.size()==4 and view.car.front_wheels.size()==2,"wheel transforms retained")
	for pose: Array in [["corner-right",Vector3(0.76,0.91,-1.97),Vector3(1.0,0.40,-1.0)],["corner-left",Vector3(-0.76,0.91,-1.97),Vector3(-1.0,0.40,-1.0)],["corner-low",Vector3(0.76,0.88,-1.97),Vector3(1.0,0.06,-1.0)],["hood-join",Vector3(0.70,0.99,-1.90),Vector3(0.65,0.90,-0.75)]]:
		var target: Vector3=(pose[1] as Vector3)*HandlingConfig.BODY_SCALE
		view.camera.fov=30
		view.camera.position=target+(pose[2] as Vector3)
		view.camera.look_at(target)
		for frame: int in range(12):await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(str(pose[0])+"-1280.png"))==OK,"native capture "+str(pose[0]))
	view.camera.fov=38.0
	view.reset_view()
	for frame: int in range(12):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("garage-1280.png"))==OK,"native garage capture")
	app.queue_free()
	await process_frame
	print("COMPACT_FRONT_JOIN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
