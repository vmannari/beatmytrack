extends SceneTree
## Shape gates on actual glass/deck triangles; continuity alone is insufficient.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String="res://../docs/evidence/electric-rear-redesign-2026-10-28/shape"
var checks: int=0
var failures: int=0
var metrics: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)

func cut(car: CarVisual,x: float,only: String) -> Array[Dictionary]:
	var segments: Array[Dictionary]=[]
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		var label: String=str(mesh.name)
		if label!=only: continue
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
		author.source_code=FileAccess.get_file_as_string("res://../docs/evidence/electric-rear-redesign-2026-10-28/before/game/vehicle/electric_coachwork.gd")
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
		var glass: MeshInstance3D=car.body.get_node("RearScreen")
		var arrays: Array=glass.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var low_y: float=INF
		var high_y: float=-INF
		var low_z: float=INF
		var high_z: float=-INF
		for i: int in range(vertices.size()):
			if uv[i].y>0.99999:
				low_y=minf(low_y,vertices[i].y);high_y=maxf(high_y,vertices[i].y)
				low_z=minf(low_z,vertices[i].z);high_z=maxf(high_z,vertices[i].z)
		check(high_y-low_y<0.045,"rear-glass bottom has a shallow crown without bowed corners "+label)
		check(high_z-low_z<0.045,"rear-glass base has a restrained plan curve "+label)
		metrics[label+"_glass_base"]={"height_spread_model_metres":high_y-low_y,"depth_spread_model_metres":high_z-low_z}
		for x: float in [0.0,-0.40,0.40]:
			var segments: Array[Dictionary]=cut(car,x,"RearScreen")
			var end_z: float=-INF
			for segment: Dictionary in segments: end_z=maxf(end_z,segment.b.x)
			var lowest: float=INF
			var reverse: float=0
			var valid: bool=true
			var angles: Array[float]=[]
			for i: int in range(11):
				var z: float=end_z-0.28+i*0.02
				var a: Dictionary=sample(segments,z)
				var b: Dictionary=sample(segments,z+0.02)
				valid=valid and is_finite(a.height) and is_finite(b.height)
				var angle: float=rad_to_deg(atan2(b.height-a.height,0.02))
				lowest=minf(lowest,angle)
				reverse=maxf(reverse,angle-lowest)
				angles.append(angle)
			check(valid,"actual lower glass section populated "+label+str(x))
			check(reverse<1.25,"glass keeps its convex rake instead of curling into the trunk "+label+str(x))
			metrics[label+"_glass_"+str(x)]={"maximum_grade_reversal_degrees":reverse,"angles":angles}
		var deck: MeshInstance3D=car.body.get_node("RearDeck")
		var start: float=deck.mesh.get_aabb().position.z
		var end: float=deck.mesh.get_aabb().end.z
		var middle: Array[Dictionary]=cut(car,0,"RearDeck")
		var left: Array[Dictionary]=cut(car,-0.75,"RearDeck")
		var right: Array[Dictionary]=cut(car,0.75,"RearDeck")
		var crown: float=sample(middle,start+0.025).height-(sample(left,start+0.025).height+sample(right,start+0.025).height)*0.5
		check(is_finite(crown) and crown>0 and crown<0.020,"trunk is gently crowned rather than domed "+label)
		var maximum: float=0
		var rising: float=-INF
		for i: int in range(8):
			var z0: float=lerpf(start+0.02,end-0.02,i/8.0)
			var z1: float=lerpf(start+0.02,end-0.02,(i+1)/8.0)
			var angle: float=rad_to_deg(atan2(sample(middle,z1).height-sample(middle,z0).height,z1-z0))
			maximum=maxf(maximum,absf(angle));rising=maxf(rising,angle)
		check(maximum<9.0,"trunk has a low restrained longitudinal profile "+label)
		check(rising<0.5,"trunk has no scooped dip and upturned centre hump "+label)
		check(car.body.find_children("TrunkShutline*","MeshInstance3D",true,false).is_empty() and car.body.find_children("TrunkSide*","MeshInstance3D",true,false).size()==6,"boot opening follows the window and tail instead of a floating rectangle "+label)
		metrics[label+"_deck"]={"crown_model_metres":crown,"maximum_grade_degrees":maximum,"maximum_upward_grade_degrees":rising}
		car.free()
	FileAccess.open(output.path_join("rear-shape.json"),FileAccess.WRITE).store_string(JSON.stringify({"before":before,"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("ELECTRIC_REAR_SHAPE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
