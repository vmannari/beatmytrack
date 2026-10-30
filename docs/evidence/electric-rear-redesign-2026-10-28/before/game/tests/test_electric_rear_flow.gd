extends SceneTree
## Independent cuts of actual prepared glass, corner and trunk triangles.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String="res://../docs/evidence/electric-rear-flow-2026-10-28/checks"
var checks: int=0
var failures: int=0
var metrics: Dictionary={}

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)

func cut(car: CarVisual,x: float) -> Array[Dictionary]:
	var segments: Array[Dictionary]=[]
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		var label: String=str(mesh.name)
		if label!="RearScreen" and label!="RearDeck" and not label.begins_with("CanopyBordertrue") and not label.begins_with("CanopySideFrame"): continue
		var arrays: Array=mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i: int in range(0,indices.size(),3):
			var points: Array[Vector3]=[]
			var ns: Array[Vector3]=[]
			for edge: int in range(3):
				var ia: int=indices[i+edge]
				var ib: int=indices[i+(edge+1)%3]
				var a: Vector3=vertices[ia]
				var b: Vector3=vertices[ib]
				if absf(a.x-x)<0.0000001:
					points.append(a);ns.append(normals[ia])
				elif (a.x-x)*(b.x-x)<0:
					var t: float=(x-a.x)/(b.x-a.x)
					points.append(a.lerp(b,t));ns.append(normals[ia].lerp(normals[ib],t))
			if points.size()<2: continue
			var a: int=0
			var b: int=1
			for j: int in range(points.size()):
				if points[j].z<points[a].z: a=j
				if points[j].z>points[b].z: b=j
			if absf(points[a].z-points[b].z)<0.0000001: continue
			segments.append({"a":Vector2(points[a].z,points[a].y),"b":Vector2(points[b].z,points[b].y),"na":ns[a],"nb":ns[b]})
	return segments

func sample(segments: Array[Dictionary],z: float) -> Dictionary:
	var height: float=-INF
	var normal:=Vector3.ZERO
	for segment: Dictionary in segments:
		if z<float(segment.a.x)-0.0000001 or z>float(segment.b.x)+0.0000001: continue
		var t: float=clampf((z-segment.a.x)/(segment.b.x-segment.a.x),0,1)
		var y: float=lerpf(segment.a.y,segment.b.y,t)
		if y>height:
			height=y
			normal=segment.na.lerp(segment.nb,t).normalized()
	return {"height":height,"normal":normal}

func run() -> void:
	var before: bool="--before" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output=arg.trim_prefix("--evidence-root=")
	if before:
		output+="/before"
		var author: GDScript=COACH
		author.source_code=FileAccess.get_file_as_string("res://../docs/evidence/electric-rear-flow-2026-10-28/before/game/vehicle/electric_coachwork.gd")
		assert(author.reload()==OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var label: String="simple" if simple else "full"
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for x: float in [0.0,-0.30,0.30,-0.60,0.60,-0.80,0.80]:
			var segments: Array[Dictionary]=cut(car,x)
			var a: Dictionary=sample(segments,1.625)
			var b: Dictionary=sample(segments,1.645)
			var c: Dictionary=sample(segments,1.655)
			var d: Dictionary=sample(segments,1.675)
			var near_a: Dictionary=sample(segments,1.6499)
			var near_b: Dictionary=sample(segments,1.6501)
			var valid: bool=is_finite(a.height) and is_finite(b.height) and is_finite(c.height) and is_finite(d.height) and is_finite(near_a.height) and is_finite(near_b.height)
			var left: float=rad_to_deg(atan2(b.height-a.height,0.020))
			var right: float=rad_to_deg(atan2(d.height-c.height,0.020))
			var join_angle: float=absf(left-right)
			var normal_angle: float=rad_to_deg(acos(clampf(near_a.normal.dot(near_b.normal),-1,1)))
			var gap: float=absf(near_a.height-near_b.height)
			check(valid,"prepared rear window/corner/trunk section populated "+label+str(x))
			check(gap<0.001,"rear join has no height step "+label+str(x))
			check(join_angle<4.0,"rear window continues into trunk without a slope kink "+label+str(x))
			check(normal_angle<2.5,"prepared specular normals flow through rear join "+label+str(x))
			metrics[label+str(x)]={"before_grade_degrees":left,"after_grade_degrees":right,"join_grade_change_degrees":join_angle,"normal_change_degrees":normal_angle,"height_gap_metres":gap,"join_height_model_metres":(near_a.height+near_b.height)*0.5}
		var triangles: int=0
		for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: triangles+=mesh.mesh.get_faces().size()/3
		check(triangles<(45000 if simple else 120000),"retained whole-car geometry budget "+label)
		car.free()
	FileAccess.open(output.path_join("rear-flow.json"),FileAccess.WRITE).store_string(JSON.stringify({"before":before,"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("ELECTRIC_REAR_FLOW: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
