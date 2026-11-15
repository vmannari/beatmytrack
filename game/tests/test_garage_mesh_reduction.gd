extends SceneTree
const Reducer=preload("res://ui/garage_mesh_reduction.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("GARAGE_REDUCTION_FAIL ",label)

func records(packet: Dictionary) -> Array:
	var result: Array=[]
	var count: int=packet.vertex_count
	var format: int=packet.format
	var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
	var ats: int=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var raw: PackedByteArray=packet.vertex_data
	var attributes: PackedByteArray=packet.get("attribute_data",PackedByteArray())
	for index: int in range(count):
		result.append([raw.slice(index*ps,(index+1)*ps),raw.slice(count*ps+index*ns,count*ps+(index+1)*ns),attributes.slice(index*ats,(index+1)*ats)])
	return result

func run() -> void:
	var path: String=Reducer.PATH
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate-recipe="): path=arg.trim_prefix("--candidate-recipe=")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var world:=Node3D.new();root.add_child(world)
	var car: CarVisual=preload("res://tests/support/garage_architecture_car.gd").new();world.add_child(car)
	Reducer.enabled=false;GarageEnvironment.architecture_scene=null
	GarageEnvironment.build(world,car,false,false)
	Reducer.enabled=true
	var holder: Node=GarageEnvironment.architecture_scene.instantiate()
	var controls: Dictionary={}
	var originals: Dictionary={}
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		controls[part]=[part.mesh,part.transform,part.material_override,part.layers,part.cast_shadow]
		if part.mesh is ArrayMesh: originals[part.mesh]=var_to_bytes(part.mesh.get("_surfaces"))
	var stats: Dictionary=Reducer.apply(holder,data)
	check(stats.matched==92 and stats.kept==3 and stats.invalid==0 and stats.missing==0,"complete recipe and protected batches")
	var reduced: int=0
	for part: MeshInstance3D in controls:
		var control: Array=controls[part]
		var source: Mesh=control[0]
		check([part.transform,part.material_override,part.layers,part.cast_shadow]==control.slice(1),"instance placement and finish retained")
		if not source is ArrayMesh:
			check(part.mesh==source,"primitive unchanged");continue
		check(var_to_bytes(source.get("_surfaces"))==originals[source],"source buffers untouched")
		if part.get_meta("garage_keep_detail",false): check(part.mesh==source,"protected lettering and fronts exact")
		if part.mesh==source: continue
		reduced+=1
		check(part.mesh.get_aabb()==source.get_aabb() and part.mesh.custom_aabb==source.custom_aabb,"culling bounds retained")
		for surface: int in range(source.get_surface_count()):
			var packet: Dictionary=part.mesh.get("_surfaces")[surface]
			var prior: Array=records(source.get("_surfaces")[surface])
			var subset: bool=true
			for row: Array in records(packet): subset=subset and row in prior
			check(subset,"every encoded position/normal/tangent/UV/colour record is original")
			var valid: bool=true
			var levels: Array=[0.0,packet.index_data];levels.append_array(packet.get("lods",[]))
			for at: int in range(1,levels.size(),2):
				var indices: PackedInt32Array=Reducer._indices(levels[at],packet.vertex_count)
				valid=valid and not indices.is_empty() and indices.size()%3==0
				for index: int in indices: valid=valid and index>=0 and index<packet.vertex_count
			check(valid,"master and every retained distance level have valid remapped indices")
	check(reduced==89,"all eligible mesh instances use the recipe")
	var sample: ArrayMesh=originals.keys()[0]
	check(Reducer._mesh(sample,{"surfaces":[]})==null,"wrong surface count rejected")
	var key: String=Reducer.signature(sample)
	var bad: Dictionary=data.duplicate(true);bad.meshes.erase(key)
	check(Reducer.apply(holder,{"schema":"obsolete"}).invalid==1,"obsolete recipe rejected")
	var fixture:=Node3D.new();var instance:=MeshInstance3D.new();instance.mesh=sample;fixture.add_child(instance)
	check(Reducer.apply(fixture,bad).missing==1 and instance.mesh==sample,"unknown mesh retains original geometry")
	bad=data.duplicate(true);bad.meshes[key]={"surfaces":[]}
	check(Reducer.apply(fixture,bad).invalid==1 and instance.mesh==sample,"invalid recipe retains original geometry")
	fixture.free();holder.free();world.free()
	print("GARAGE_MESH_REDUCTION ",checks," checks, ",failures," failures")
	await process_frame
	quit(1 if failures else 0)
