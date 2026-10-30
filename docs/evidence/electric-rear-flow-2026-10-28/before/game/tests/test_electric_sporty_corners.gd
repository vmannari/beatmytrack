extends SceneTree
## Absolute silhouette gates on prepared triangles, independent of author parameters.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String = "res://../docs/evidence/electric-sporty-corners-2026-10-27/checks"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func height(faces: PackedVector3Array, x: float, z: float) -> float:
	var result: float = -INF
	for i: int in range(0,faces.size(),3):
		var point: Variant = Geometry3D.ray_intersects_triangle(Vector3(x,2,z),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
		if point != null: result = maxf(result,point.y)
	return result

func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	if before:
		output += "/before"
		var author: GDScript = COACH
		author.source_code = FileAccess.get_file_as_string("res://../docs/evidence/electric-sporty-corners-2026-10-27/before/game/vehicle/electric_coachwork.gd")
		assert(author.reload()==OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var label: String="simple" if simple else "full"
		var faces:=PackedVector3Array()
		for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
			if str(mesh.name).begins_with("Hood") or mesh.name=="ClamshellHood" or str(mesh.name).begins_with("SculptedSide"): faces.append_array(mesh.mesh.get_faces())
		for z: float in [-1.88,-1.75]:
			for x: float in [0.66,0.72]:
				var left: float=height(faces,-x,z)
				var right: float=height(faces,x,z)
				metrics[label+"_corner_"+str(x)+"_"+str(z)]=[left,right]
				check(is_finite(left) and is_finite(right),"actual corner rays hit "+label+str(x)+str(z))
				check(maxf(left,right)<(0.935 if z< -1.8 else 0.96),"lower sporting front shoulders "+label+str(x)+str(z))
				check(absf(left-right)<0.00001,"retained corner symmetry "+label+str(x)+str(z))
		var brow: MeshInstance3D=car.body.get_node("FormedFrontHoodJoin")
		var points: Array=brow.mesh.surface_get_arrays(0)
		var corner_top: float=-INF
		for i: int in range(points[Mesh.ARRAY_VERTEX].size()):
			var uv: Vector2=points[Mesh.ARRAY_TEX_UV][i]
			# Collapsed top cells may omit UV=1 while retaining the same endpoint.
			if uv.x<0.0001 or uv.x>0.9999: corner_top=maxf(corner_top,points[Mesh.ARRAY_VERTEX][i].y)
		metrics[label+"_outer_brow_height"]=corner_top
		check(is_finite(corner_top) and corner_top<0.88,"outer brow loses tall block silhouette "+label)
		check(car.front_wheels.size()==2 and car.rolling_wheels.size()==4,"retained independent wheels "+label)
		var clearance: float=INF
		for arch: MeshInstance3D in car.body.find_children("ArchReturn*","MeshInstance3D",true,false):
			if arch.mesh.get_aabb().end.z>0: continue
			for point: Vector3 in arch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				clearance=minf(clearance,Vector2(point.y-0.37,point.z+COACH.AXLE).length()-0.37)
		metrics[label+"_front_arch_clearance"]=clearance
		check(is_finite(clearance) and clearance>0.030,"front opening retains tyre clearance "+label)
		car.free()
	FileAccess.open(output.path_join("sporty-corners.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"before":before,"metrics":metrics},"\t"))
	print("ELECTRIC_SPORTY_CORNERS: ",checks," checks, ",failures," failures, ",JSON.stringify(metrics))
	quit(1 if failures else 0)
