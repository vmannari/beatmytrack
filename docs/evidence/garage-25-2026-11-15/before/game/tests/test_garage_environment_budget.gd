extends SceneTree
## G70: environment budget, exact preparation, closed caps and retained layout.
const Cleanup=preload("res://ui/garage_mesh_cleanup.gd")
const Compare=preload("res://tests/support/garage_geometry_comparison.gd")
var checks: int=0
var failures: int=0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("GARAGE_BUDGET_FAIL ",label)

func triangles(holder: Node) -> int:
	var result: int=0
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.mesh!=null: result+=part.mesh.get_faces().size()/3
	return result

func area(mesh: Mesh) -> float:
	var faces: PackedVector3Array=mesh.get_faces()
	var result: float=0
	for at: int in range(0,faces.size(),3): result+=(faces[at+1]-faces[at]).cross(faces[at+2]-faces[at]).length()*0.5
	return result

func authored_layout(holder: Node) -> Dictionary:
	var result: Dictionary={}
	for child: Node3D in holder.find_children("*","Node3D",true,false):
		if child is MeshInstance3D or str(child.name).begins_with("@"): continue
		result[str(holder.get_path_to(child))]=[child.get_class(),child.transform]
	return result

func cap_checks() -> void:
	for sides: int in [6,8,12,24,48,64,96]:
		var source:=CylinderMesh.new()
		source.radial_segments=sides
		source.rings=0
		source.top_radius=0.012;source.bottom_radius=0.012;source.height=0.035
		var reduced: ArrayMesh=Cleanup.compact_cylinder_caps(source)
		check(reduced!=null,"closed cylinder is eligible "+str(sides))
		if reduced==null: continue
		check(reduced.get_faces().size()==source.get_faces().size()-12,"exactly four redundant cap triangles removed "+str(sides))
		check(reduced.get_aabb()==source.get_aabb(),"cap boundary and axial bounds retained "+str(sides))
		check(absf(area(reduced)-area(source))<0.000001,"closed surface area retained "+str(sides))
		var old: Array=source.surface_get_arrays(0)
		var current: Array=reduced.surface_get_arrays(0)
		check(old[Mesh.ARRAY_VERTEX]==current[Mesh.ARRAY_VERTEX] and old[Mesh.ARRAY_TEX_UV]==current[Mesh.ARRAY_TEX_UV],"original positions and UV records retained "+str(sides))
		var winding: bool=true
		var vertices: PackedVector3Array=current[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=current[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=current[Mesh.ARRAY_INDEX]
		for at: int in range(0,indices.size(),3):
			var a: int=indices[at];var b: int=indices[at+1];var c: int=indices[at+2]
			winding=winding and (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a])<0
		check(winding,"all retained and new faces keep native winding "+str(sides))
		source.cap_bottom=false
		check(Cleanup.compact_cylinder_caps(source)==null,"open-cylinder policy is untouched "+str(sides))
	var cone:=CylinderMesh.new()
	cone.top_radius=0.1;cone.bottom_radius=0.2
	check(Cleanup.compact_cylinder_caps(cone)==null,"cone profiles are outside the exact cap policy")

func run() -> void:
	cap_checks()
	var path: String=GarageEnvironment.PREPARED_ARCHITECTURE
	var reference_path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate-room="): path=arg.trim_prefix("--candidate-room=")
		if arg.begins_with("--reference-room="): reference_path=arg.trim_prefix("--reference-room=")
	var prepared: PackedScene=load(path)
	var candidate: Node=prepared.instantiate()
	if not reference_path.is_empty():
		var reference: Node=load(reference_path).instantiate()
		check(authored_layout(reference)==authored_layout(candidate),"every named object, light and attachment retains its authored transform")
		reference.free()
	var world:=Node3D.new()
	root.add_child(world)
	var car: CarVisual=preload("res://tests/support/garage_architecture_car.gd").new()
	world.add_child(car)
	GarageEnvironment.architecture_scene=null
	GarageEnvironment.build(world,car,false,false)
	var source: Node=GarageEnvironment.architecture_scene.instantiate()
	var before: Array=[];var after: Array=[]
	Compare.geometry(source,before);Compare.geometry(candidate,after)
	check(before==after,"published candidate exactly matches source construction and finishes")
	var room_triangles: int=triangles(candidate)
	var pedestal: Node=GarageEnvironment.pedestal_scene.instantiate()
	var pedestal_triangles: int=triangles(pedestal)
	check(room_triangles<=39000,"workshop meets approximately 70 percent reduction")
	check(room_triangles+pedestal_triangles+14<=41500,"complete environment remains below 31 percent of original 134089")
	for name: String in ["GarageWorkbench","GarageToolStorage","GarageTyreRack","GarageDisplayPlant","GarageCompressor","GarageTrophyWall","GarageRecordStation","GarageDrain"]:
		check(candidate.find_child(name,true,false)!=null,"authored object retained "+name)
	for index: int in range(6): check(candidate.find_child("AwardSlot_"+str(index),true,false)!=null,"earned-award attachment retained "+str(index))
	check(candidate.find_child("GarageVinyl",true,false)!=null and candidate.find_child("GarageRecordSleeves",true,false)!=null,"record animation nodes retained")
	check(candidate.find_child("PegboardPerforations",true,false)==null,"perforation surface joins the material batches")
	print("GARAGE_ENVIRONMENT_BUDGET ",checks," checks, ",failures," failures; workshop=",room_triangles," pedestal=",pedestal_triangles," total=",room_triangles+pedestal_triangles+14)
	source.free();candidate.free();pedestal.free();world.free()
	await process_frame
	quit(1 if failures else 0)
