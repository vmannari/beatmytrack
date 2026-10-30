extends SceneTree
## Whole-panel convexity, measured on fixed-X prepared triangle sections.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String = "res://../docs/evidence/electric-convex-hood-2026-10-27/checks"
var checks: int=0
var failures: int=0
var metrics: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)

func section(car: CarVisual,x: float) -> Array[Vector2]:
	var points: Array[Vector2]=[]
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if mesh.name!="ClamshellHood" and not str(mesh.name).begins_with("HoodSurround"): continue
		var faces: PackedVector3Array=mesh.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			for edge: int in range(3):
				var a: Vector3=faces[i+edge]
				var b: Vector3=faces[i+(edge+1)%3]
				if absf(a.x-x)<0.000001: points.append(Vector2(a.z,a.y))
				if (a.x-x)*(b.x-x)<0:
					var p: Vector3=a.lerp(b,(x-a.x)/(b.x-a.x))
					points.append(Vector2(p.z,p.y))
	points.sort_custom(func(a: Vector2,b: Vector2)->bool:return a.x<b.x)
	return points

func height(points: Array[Vector2],z: float) -> float:
	for i: int in range(points.size()-1):
		var a: Vector2=points[i]
		var b: Vector2=points[i+1]
		if a.x<=z and b.x>=z and b.x-a.x>0.000001: return lerpf(a.y,b.y,(z-a.x)/(b.x-a.x))
	return NAN

func run() -> void:
	var before: bool="--before" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output=arg.trim_prefix("--evidence-root=")
	if before:
		output+="/before"
		var author: GDScript=COACH
		author.source_code=FileAccess.get_file_as_string("res://../docs/evidence/electric-convex-hood-2026-10-27/before/game/vehicle/electric_coachwork.gd")
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
		for x: float in [0.0,0.30,0.50,0.60]:
			var points: Array[Vector2]=section(car,x)
			var angles: Array[float]=[]
			var samples: Array=[]
			for i: int in range(27):
				var z: float=-2.12+0.04*i
				var a: float=height(points,z)
				var b: float=height(points,z+0.04)
				angles.append(rad_to_deg(atan2(b-a,0.04)))
				samples.append([z,a])
			var lowest: float=INF
			var reverse: float=0
			var convex: int=0
			var valid: bool=true
			for i: int in range(angles.size()):
				valid=valid and is_finite(angles[i])
				lowest=minf(lowest,angles[i])
				reverse=maxf(reverse,angles[i]-lowest)
				if i>0 and angles[i]<=angles[i-1]+0.05: convex+=1
			var front: float=(angles[0]+angles[1]+angles[2]+angles[3])/4.0
			var back: float=(angles[-1]+angles[-2]+angles[-3]+angles[-4])/4.0
			var fraction: float=float(convex)/(angles.size()-1)
			metrics[label+"_"+str(x)]={"samples":samples,"angles_degrees":angles,"whole_panel_reverse_degrees":reverse,"convex_fraction":fraction,"front_grade":front,"rear_grade":back}
			check(valid,"all actual panel sections populated "+label+str(x))
			check(reverse<1.25,"whole panel has no drop-then-plateau reversal "+label+str(x))
			check(fraction>=0.80,"at least 80 percent of main panel bends convexly "+label+str(x))
			check(front>back+2.0,"forward panel becomes steeper toward nose "+label+str(x))
			check(lowest>2.0,"main hood has no nearly horizontal shelf "+label+str(x))
		car.free()
	FileAccess.open(output.path_join("convex-hood.json"),FileAccess.WRITE).store_string(JSON.stringify({"before":before,"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("ELECTRIC_CONVEX_HOOD: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
