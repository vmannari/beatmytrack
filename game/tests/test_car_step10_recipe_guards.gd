extends SceneTree
const S=preload("res://vehicle/car_surface_reduction.gd")
const D=preload("res://vehicle/car_detail_reduction.gd")
var checks: int=0;var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("STEP10_RECIPE_FAIL ",label)
func run() -> void:
	var car:=CarVisual.new();car.vehicle_id="compact";root.add_child(car)
	while not car.model_ready:await process_frame
	for child: Node in car.get_children():child.free()
	car.front_wheels.clear();car.rear_wheels.clear();car.rolling_wheels.clear();car.brake_lights.clear();car.kit_frames.clear()
	car.body=Node3D.new();car.add_child(car.body)
	var parts: Array=[];var originals: Array=[]
	for n: int in range(2):
		var part:=MeshInstance3D.new();var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,BoxMesh.new().surface_get_arrays(0))
		part.mesh=mesh;part.material_override=StandardMaterial3D.new();part.position.x=n*2.0;car.body.add_child(part);parts.append(part);originals.append(mesh)
	var group: Dictionary=D.groups(car)[0];var rows: Dictionary={};var targets: Array=[]
	for entry: Dictionary in group.entries:
		var selected: ArrayMesh=entry.part.mesh.duplicate();selected.set_meta("car_surface_source",entry.source)
		var file: String="guard"+str(targets.size())+".res";S.meshes[S.ROOT.path_join(file)]=selected;targets.append(selected)
		rows[entry.code]={"source":entry.source,"mesh":file,"result":D.mesh_key(selected)}
	var key: String=group.vehicle+"_"+group.code
	var recipe: Dictionary={"schema":S.SCHEMA,"context":group.code,"parts":rows}
	S.recipes[key]=recipe.duplicate(true)
	var last: String=group.entries[-1].code
	S.recipes[key].parts[last].result="incorrect-result"
	S.apply_group(group,D)
	for n: int in range(parts.size()):check(parts[n].mesh==originals[n],"late invalid member rejects entire frame")
	S.recipes[key]=recipe.duplicate(true);S.recipes[key].context="stale-context";S.apply_group(group,D)
	check(parts[0].mesh==originals[0],"stale complete-frame identity rejects")
	S.recipes[key]=recipe.duplicate(true);S.recipes[key].parts[last].mesh="../escape.res";S.apply_group(group,D)
	check(parts[0].mesh==originals[0],"path traversal rejects entire frame")
	S.recipes[key]=recipe.duplicate(true);S.apply_group(group,D)
	for n: int in range(parts.size()):check(parts[n].mesh==targets[n],"valid frame replaces every member")
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type spatial; void vertex(){VERTEX.y+=0.01;}";material.shader=shader
	parts[0].material_override=material
	var entry: Dictionary=D.groups(car)[0].entries[0]
	check(not S.permitted(entry),"unreviewed shader/displacement rejected")
	parts[0].material_override=StandardMaterial3D.new();parts[0].mesh.set_meta("car_keep_master",true)
	check(not S.permitted(D.groups(car)[0].entries[0]),"protected fitted contours cannot enter reduction")
	car.free();print("STEP10_RECIPE_GUARDS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
