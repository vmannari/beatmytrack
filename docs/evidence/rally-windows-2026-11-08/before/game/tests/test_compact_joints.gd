extends SceneTree
## Actual shared-edge, ruled-glass and native inspection regression.
var failures: int=0
var checks: int=0
var output: String="res://../docs/evidence/compact-joints-2026-10-10"
const GLAZING=preload("res://vehicle/compact_glazing.gd")

func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func same(a: Vector3,b: Vector3,label: String) -> void:
	check(a.distance_to(b)<0.0002,label)

func capture(label: String) -> void:
	for frame: int in range(12): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)

func boundary(key: String,height: float) -> Array[Vector3]:
	var resource: ArrayMesh=CompactCoachwork.meshes[key]
	var points: PackedVector3Array=resource.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var unique: Dictionary={}
	for point: Vector3 in points:
		if absf(point.y-height)<0.00001:unique[point]=true
	var result: Array[Vector3]=[]
	for point: Vector3 in unique:result.append(point)
	return result

func mesh_edges(a: Array[Vector3],b: Array[Vector3],label: String) -> void:
	check(not a.is_empty() and not b.is_empty(),label+" nonempty")
	for pair: Array in [[a,b],[b,a]]:
		var maximum: float=0
		for point: Vector3 in pair[0]:
			var distance: float=1000
			for other: Vector3 in pair[1]:distance=minf(distance,point.distance_to(other))
			maximum=maxf(maximum,distance)
		check(maximum<0.0002,label+" matching baked vertices")

func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	for side: float in [-1,1]:
		for index: int in range(33):
			var t: float=index/32.0
			same(CompactCoachwork.rear_shoulder_point(side,1,t),CompactCoachwork.rear_corner_point(side,0,t),"side/corner shared boundary")
			same(CompactCoachwork.rear_corner_point(side,1,t),CompactCoachwork.rear_face_point(0 if side<0 else 1,t),"corner/rear shared boundary")
			var point: Vector3=CompactCoachwork.rear_corner_point(side,t,1)
			same(point,CompactCoachwork.cabin_rear_point(point.x/0.76,0),"corner/hatch shared boundary")
			same(CompactCoachwork.roof_point(side,t),CompactCoachwork.cabin_side_point(side,t,1),"roof/side shared boundary")
	for index: int in range(33):
		var t: float=lerpf(-1,1,index/32.0)
		same(CompactCoachwork.roof_point(t,0),CompactCoachwork.cabin_front_point(t,1),"roof/front shared boundary")
		same(CompactCoachwork.roof_point(t,1),CompactCoachwork.cabin_rear_point(t,1),"roof/hatch shared boundary")
	for front: bool in [false,true]:
		for u: float in [-1,-0.9,-0.4,0,0.4,0.9,1]:
			var bottom: Vector3=GLAZING.windshield_point(front,u,0)
			var top: Vector3=GLAZING.windshield_point(front,u,1)
			var middle: Vector3=GLAZING.windshield_point(front,u,0.5)
			same(middle,(bottom+top)*0.5,"glass has straight vertical generator")
		var center: Vector3=GLAZING.windshield_point(front,0,0.5)
		var chord: Vector3=(GLAZING.windshield_point(front,-1,0.5)+GLAZING.windshield_point(front,1,0.5))*0.5
		check(center.distance_to(chord)>0.016 and center.distance_to(chord)<0.020,"glass has shallow cross-car curvature")
	var directory: String="user://compact_joints_"+TrackLibrary.unique_id()
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
	check(view.car.front_wheels.size()==2 and view.car.rolling_wheels.size()==4,"wheel transforms retained")
	for side: String in ["left","right"]:
		mesh_edges(boundary("rear_corner_"+side,1.01),boundary("cabin_rear_corner_"+side,1.01),"actual corner/hatch edge")
	for front: bool in [false,true]:
		var roof: Array[Vector3]=[]
		for point: Vector3 in boundary("rolled_roof",1.48):
			var target: Vector3=CompactCoachwork.cabin_front_point(point.x/0.63,1) if front else CompactCoachwork.cabin_rear_point(point.x/0.63,1)
			if absf(point.z-target.z)<0.0002:roof.append(point)
		var prefix: String="cabin_front" if front else "cabin_rear"
		var cabin: Array[Vector3]=boundary(prefix,1.48)
		cabin.append_array(boundary(prefix+"_corner_left",1.48))
		cabin.append_array(boundary(prefix+"_corner_right",1.48))
		mesh_edges(roof,cabin,"actual roof/cabin edge")
	for pose: Array in [["rear-left",-2.35,0.15,0.87],["rear-right",2.35,0.15,0.87],["rear-center",PI,0.12,0.88],["side-left",-PI/2,0.10,0.87],["side-right",PI/2,0.10,0.87],["front-left",-0.65,0.15,0.85],["front-center",0.0,0.12,0.87],["roof",0.7,0.70,0.82]]:
		view.yaw=float(pose[1])
		view.elevation=float(pose[2])
		view.set_zoom(float(pose[3]))
		await capture(str(pose[0])+"-1280")
	root.size=Vector2i(960,540)
	view.yaw=-2.35
	view.elevation=0.15
	view.set_zoom(0.87)
	await capture("rear-left-960")
	app.queue_free()
	await process_frame
	print("COMPACT_JOINTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
