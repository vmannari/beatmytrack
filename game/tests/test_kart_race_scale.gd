extends SceneTree
## KRS01-KRS03: larger native anatomy with fixed contacts and camera projection.
const OUT = "res://../docs/evidence/kart-driver-race-scale-2026-11-12"
const ROOT = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("RACE_SCALE_FAIL ",label)
func bounds(mesh: ArrayMesh) -> AABB:
	var first: bool = true
	var result := AABB()
	for surface: int in range(mesh.get_surface_count()):
		for point: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if first: result = AABB(point,Vector3.ZERO); first = false
			else: result = result.expand(point)
	return result
func centre(points: PackedVector3Array, offset: int, row: int) -> Vector3:
	var result := Vector3.ZERO
	for column: int in range(16): result += points[offset+row*17+column]
	return result/16
func projected(camera: Camera3D, mesh: ArrayMesh) -> Rect2:
	var first: bool = true
	var result := Rect2()
	for surface: int in range(mesh.get_surface_count()):
		for point: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var pixel: Vector2 = camera.unproject_position(point*HandlingConfig.BODY_SCALE)
			if first: result = Rect2(pixel,Vector2.ZERO); first = false
			else: result = result.expand(pixel)
	return result
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var before: String = OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
	var old: ArrayMesh = load(before+"driver.res")
	var old_head: ArrayMesh = load(before+"helmet_static.res")
	var mesh: ArrayMesh = load(ROOT+"driver.res")
	var head: ArrayMesh = load(ROOT+"helmet_static.res")
	if "--before" in OS.get_cmdline_user_args(): mesh = old; head = old_head
	check(mesh.get_faces().size()==old.get_faces().size() and head.get_faces().size()==old_head.get_faces().size(),"native triangle budget retained")
	check(mesh.get_surface_count()==2 and head.get_surface_count()==4 and mesh.get_blend_shape_count()==preload("res://vehicle/kart_steering.gd").STEPS*2,"moving cloth and static helmet roles retained")
	var old_packet: Dictionary = old.get("_surfaces")[0]
	var packet: Dictionary = mesh.get("_surfaces")[0]
	# Steering travel has been enlarged; protect the neutral grip packet here.
	# Posed grip fidelity at every new target/midpoint is checked by driver_polish.
	for key: String in ["vertex_data","attribute_data","index_data"]: check(packet.get(key)==old_packet.get(key),"raw neutral glove/contact packet retained "+key)
	var arrays: Array = mesh.surface_get_arrays(1)
	var prior: Array = old.surface_get_arrays(1)
	for attribute: int in [Mesh.ARRAY_INDEX,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]: check(arrays[attribute]==prior[attribute],"sewn topology and cloth attributes retained "+str(attribute))
	var prefix: int = mesh.get_meta("kart_suit_static_vertices")
	var fixed: bool = true
	var count: int = 0
	for vertex: int in range(prefix):
		var point: Vector3 = prior[Mesh.ARRAY_VERTEX][vertex]
		if point.y<0.46 or (point.y<=0.60 and point.z>=0.30):
			fixed = fixed and point==arrays[Mesh.ARRAY_VERTEX][vertex]
			count += 1
	check(fixed and count>600,"hips, legs, soles and supported back retain their fitted positions")
	var poses: Array[Array] = [arrays]
	poses.append_array(mesh.surface_get_blend_shape_arrays(1))
	for pose: int in range(poses.size()):
		var points: PackedVector3Array = poses[pose][Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = poses[pose][Mesh.ARRAY_NORMAL]
		var finite: bool = points.size()==arrays[Mesh.ARRAY_VERTEX].size()
		var still: bool = true
		for vertex: int in range(points.size()): finite = finite and points[vertex].is_finite() and normals[vertex].is_finite() and normals[vertex].length_squared()>0.8 and mesh.custom_aabb.has_point(points[vertex])
		for vertex: int in range(prefix): still = still and points[vertex]==arrays[Mesh.ARRAY_VERTEX][vertex]
		check(finite,"finite equal-topology pose inside culling bounds "+str(pose))
		check(still,"supported body stays fixed through steering "+str(pose))
		for side: int in range(2):
			var offset: int = prefix+side*21*17
			var upper_a: Vector3 = centre(points,offset,2)
			var upper_b: Vector3 = centre(points,offset,8)
			var lower_a: Vector3 = centre(points,offset,12)
			var lower_b: Vector3 = centre(points,offset,19)
			var bow: float = 0
			for row: int in range(3,8): bow = maxf(bow,(centre(points,offset,row)-upper_a).cross(upper_b-upper_a).length()/upper_a.distance_to(upper_b))
			for row: int in range(13,19): bow = maxf(bow,(centre(points,offset,row)-lower_a).cross(lower_b-lower_a).length()/lower_a.distance_to(lower_b))
			check(bow<0.001,"defined upper-arm/forearm shafts retained "+str(pose)+"/"+str(side))
	var old_box: AABB = bounds(old_head)
	var box: AABB = bounds(head)
	check(box.size.x/old_box.size.x>=1.19 and box.size.y/old_box.size.y>=1.19,"helmet is visibly larger relative to the unchanged kart")
	check(box.end.y-old_box.end.y>=0.09,"seated upper silhouette is taller")
	var camera := FollowCamera.new()
	root.add_child(camera)
	camera.current = true
	camera.speed_zoom_enabled = false
	camera.follow(Vector2.ZERO,Vector2.ZERO,0,0,true)
	await process_frame
	var projected_before: Rect2 = projected(camera,old_head)
	var projected_after: Rect2 = projected(camera,head)
	var ratio: Vector2 = projected_after.size/projected_before.size
	check(ratio.x>=1.19 and ratio.y>=1.19,"same race camera gives a larger driver helmet")
	var data: Dictionary = {"checks":checks,"failures":failures,"helmet_width_ratio":box.size.x/old_box.size.x,"helmet_height_ratio":box.size.y/old_box.size.y,"crown_increase_mm":(box.end.y-old_box.end.y)*1000,"race_projection_ratio":str(ratio),"before_race_helmet_pixels":str(projected_before.size),"after_race_helmet_pixels":str(projected_after.size),"camera_extent":camera.size,"protected_vertices":count}
	FileAccess.open(OUT+("/scale-control.json" if "--before" in OS.get_cmdline_user_args() else "/scale-after.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("KART_RACE_SCALE ",JSON.stringify(data))
	camera.free()
	quit(1 if failures else 0)
