extends SceneTree
## Read-only design study; parameter variants are reloaded in isolated memory.
const COACH = preload("res://vehicle/electric_coachwork.gd")
func _initialize() -> void: run.call_deferred()

func curvature(points: Array[Vector2]) -> Dictionary:
	var sampled: Array[Vector2] = [points[0]]
	var remaining: float = 0.02
	for index: int in range(points.size()-1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index+1]
		var length_value: float = a.distance_to(b)
		while length_value>=remaining:
			a = a.lerp(b,remaining/length_value)
			sampled.append(a)
			length_value = a.distance_to(b)
			remaining = 0.02
		remaining -= length_value
	var previous: float = -INF
	var reverse: float = 0
	var rising: float = 0
	for index: int in range(sampled.size()-1):
		var delta: Vector2 = sampled[index+1]-sampled[index]
		var angle: float = rad_to_deg(atan2(-delta.y,-delta.x))
		if is_finite(previous): reverse = maxf(reverse,previous-angle)
		rising = maxf(rising,delta.y)
		previous = angle
	return {"reverse_degrees":reverse,"upward_step":rising}

func point_at(x: float,v: float) -> Vector3:
	var low: float=0.5
	var high: float=1.0
	for i: int in range(18):
		var u: float=(low+high)*0.5
		if COACH.hood_point(u,v).x<x: low=u
		else: high=u
	return COACH.hood_point((low+high)*0.5,v)
func height_at(x: float,z: float) -> float:
	var low: float=0
	var high: float=1
	for i: int in range(18):
		var v: float=(low+high)*0.5
		if point_at(x,v).z<z: low=v
		else: high=v
	return point_at(x,(low+high)*0.5).y
func run() -> void:
	if "--array-audit" in OS.get_cmdline_user_args():
		array_audit()
		return
	var author: GDScript=COACH
	var original: String=FileAccess.get_file_as_string("res://../docs/evidence/electric-sporty-corners-2026-10-27/draft-native/electric_coachwork.gd.txt")
	for end: float in [0.3,1.0]:
		for cz: float in [-1.52,-1.35,-1.20,-1.10]:
			for drop: float in [0.020,0.013]:
				author.source_code=original.replace("pow(1-across*across,0.65)","pow(1-across*across,1.5)").replace("v*v+0.20*","v*v+1.20*").replace("lerpf(front.z,-0.94,v),edge)","lerpf(front.z,-0.94,v),edge*smoothstep(0,"+str(end)+",v))").replace("Vector2(-1.52,rear_y-0.033)","Vector2("+str(cz)+",rear_y-"+str(drop)+")")
				assert(author.reload()==OK)
				var result: Dictionary={"end":end,"cz":cz,"drop":drop,"reverse":0.0,"upward":0.0,"crown":0.0}
				for x: float in [0.0,0.4,0.65]:
					var points: Array[Vector2]=[]
					for step: int in range(241):
						var point: Vector3=point_at(x,1-step/240.0)
						points.append(Vector2(point.z,point.y))
					var front_y: float=point_at(x,0).y
					for step: int in range(1,101):
						var y: float=lerpf(front_y,0.31,step/100.0)
						points.append(Vector2(COACH.front_z(x,y),y))
					var curve: Dictionary=curvature(points)
					result.reverse=maxf(result.reverse,curve.reverse_degrees)
					result.upward=maxf(result.upward,curve.upward_step)
				for z: float in [-1.85,-1.6,-1.3]: result.crown=maxf(result.crown,absf(height_at(0,z)-height_at(0.66,z)))
				print("SPORTY_TANGENT_STUDY ",JSON.stringify(result))
	quit()

func array_audit() -> void:
	var old_root: String="res://assets/vehicles/electric_coachwork_v11"
	var new_root: String="res://assets/vehicles/electric_coachwork_v12"
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(old_root+"/manifest.json"))
	var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(new_root+"/manifest.json"))
	var names: Dictionary={}
	for item: Dictionary in old.meshes: names[item.part]=item.file
	var exact: Array[String]=[]
	var changed: Array[String]=[]
	var refits: Array[Dictionary]=[]
	var refit_delta: float=0
	var protected_count: int=0
	var failures: int=0
	for item: Dictionary in current.meshes:
		var a: ArrayMesh=load(old_root+"/"+names[item.part])
		var b: ArrayMesh=load(new_root+"/"+item.file)
		var same: bool=a.get_surface_count()==b.get_surface_count()
		var protected: bool=true
		for surface: int in range(a.get_surface_count()):
			var data: Array=a.surface_get_arrays(surface)
			for vertex: Vector3 in data[Mesh.ARRAY_VERTEX]: protected=protected and vertex.z>= -0.94
			same=same and data==b.surface_get_arrays(surface)
		if protected:
			protected_count+=1
			if not same:
				var aa: PackedVector3Array=a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var bb: PackedVector3Array=b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var delta: float=0
				if aa.size()!=bb.size(): delta=INF
				else:
					for i: int in range(aa.size()): delta=maxf(delta,aa[i].distance_to(bb[i]))
				refit_delta=maxf(refit_delta,delta)
				# Denser simple side triangles legitimately re-seat these derived
				# ribbons. Keep them within the original 4.5 mm reveal depth;
				# every other protected authored array must remain exact.
				if str(item.part).begins_with("DoorReveal") and str(item.part).ends_with("_simple") and delta<=0.0045:
					refits.append({"part":item.part,"maximum_vertex_delta":delta})
				else:
					failures+=1
					print("FAIL: unchanged protected arrays ",item.part)

		if same: exact.append(item.part)
		else: changed.append(item.part)
	var report: Dictionary={"meshes":current.meshes.size(),"exact_arrays":exact,"changed_arrays":changed,"protected_meshes":protected_count,"protected_failures":failures,"protected_max_vertex_delta":refit_delta,"derived_simple_reveal_refits":refits}
	FileAccess.open("res://../docs/evidence/electric-sporty-corners-2026-10-27/prepared-array-preservation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SPORTY_ARRAY_AUDIT ",current.meshes.size()," resources, ",exact.size()," exact arrays; protected ",protected_count," / ",failures," failures; derived refits ",refits.size(),"; max vertex delta ",refit_delta)
	quit(1 if failures else 0)
