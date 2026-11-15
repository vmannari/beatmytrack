extends SceneTree
const Reducer=preload("res://ui/garage_mesh_reduction.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("GARAGE_SPEAKERS_FAIL ",label)

func source_faces(mesh: Mesh,indices: PackedInt32Array,speaker: int) -> Dictionary:
	var result: Dictionary={}
	var points: PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var x: float=-0.86 if speaker==0 else 0.86
	var bounds:=AABB(Vector3(x-0.135,0.89,-0.128),Vector3(0.27,0.4,0.308)).grow(0.0001)
	var station:=Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(9.80,0,4.70)).affine_inverse()
	for at: int in range(0,indices.size(),3):
		var a: Vector3=points[indices[at]]
		var b: Vector3=points[indices[at+1]]
		var c: Vector3=points[indices[at+2]]
		if bounds.has_point(station*a) and bounds.has_point(station*b) and bounds.has_point(station*c):
			var key: String=var_to_bytes(PackedVector3Array([a,b,c])).hex_encode()
			result[key]=result.get(key,0)+1
	return result

func run() -> void:
	var path: String=GarageEnvironment.PREPARED_ARCHITECTURE
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate-room="): path=arg.trim_prefix("--candidate-room=")
	var world:=Node3D.new();root.add_child(world)
	var car: CarVisual=preload("res://tests/support/garage_architecture_car.gd").new();world.add_child(car)
	GarageEnvironment.architecture_scene=null;Reducer.enabled=false
	GarageEnvironment.build(world,car,false,false)
	Reducer.enabled=true
	var source: Node=GarageEnvironment.architecture_scene.instantiate()
	var candidate: Node=load(path).instantiate()
	var before: Array=source.find_children("*","MeshInstance3D",true,false)
	var after: Array=candidate.find_children("*","MeshInstance3D",true,false)
	check(before.size()==after.size(),"material batches/draw groups retained")
	var totals: Array[int]=[0,0]
	var levels_checked: int=0
	for part: int in range(mini(before.size(),after.size())):
		var original: Mesh=before[part].mesh
		if not original is ArrayMesh: continue
		var original_packet: Dictionary=original.get("_surfaces")[0]
		var master: PackedInt32Array=Reducer._indices(original_packet.index_data,original_packet.vertex_count)
		for speaker: int in range(2):
			var expected: Dictionary=source_faces(original,master,speaker)
			totals[speaker]+=expected.size()
			if expected.is_empty(): continue
			var mesh: ArrayMesh=after[part].mesh
			var packet: Dictionary=mesh.get("_surfaces")[0]
			var levels: Array=[0.0,packet.index_data];levels.append_array(packet.get("lods",[]))
			for level: int in range(1,levels.size(),2):
				var faces: Dictionary=source_faces(mesh,Reducer._indices(levels[level],packet.vertex_count),speaker)
				check(faces==expected,"exact cabinet, woofer and tweeter faces at every level: speaker "+str(speaker)+" batch "+str(part)+" level "+str(level/2))
				levels_checked+=1
	for speaker: int in range(2): check(totals[speaker]>=200,"complete original speaker source fixture "+str(speaker))
	print("GARAGE_SPEAKERS ",checks," checks, ",failures," failures; exact source faces=",totals," levels=",levels_checked)
	source.free();candidate.free();world.free()
	await process_frame
	quit(1 if failures else 0)
