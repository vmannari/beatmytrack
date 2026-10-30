extends SceneTree
## Rear fittings must preserve exact arrays while yielding and honoring cancel.
var checks: int=0
var failures: int=0
var callbacks: int=0
var cancel_after: int=-1
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func checkpoint() -> bool:
	callbacks+=1
	await process_frame
	return cancel_after<0 or callbacks<cancel_after
func make(simple: bool) -> CarVisual:
	var car:=CarVisual.new()
	car.simple_model=simple;car.body=Node3D.new();car.add_child(car.body)
	car.brake_material=StandardMaterial3D.new()
	return car
func fingerprint(car: CarVisual) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for node: Node3D in car.body.find_children("*","Node3D",true,false):
		hash.update(var_to_bytes([node.get_class(),node.transform]))
		if node is MeshInstance3D:
			hash.update(var_to_bytes([node.layers,node.cast_shadow]))
			for surface: int in range(node.mesh.get_surface_count()): hash.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
	return hash.finish().hex_encode()
func build(car: CarVisual,paint: Material,trim: Material,metal: Material) -> void:
	var supports_checkpoints: bool=false
	for method: Dictionary in (load("res://vehicle/compact_rear_design.gd") as Script).get_script_method_list():
		if method.name=="build": supports_checkpoints=method.args.size()>=5
	if supports_checkpoints: await (load("res://vehicle/compact_rear_design.gd") as Script).call("build",car,paint,trim,metal,checkpoint)
	else: CompactRearDesign.build(car,paint,trim,metal)
func run() -> void:
	var task_config:=ConfigFile.new();task_config.set_value("backend","url","");assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	var paint: Material=CompactFinish.paint(Color("39738c"))
	var trim: Material=CompactFinish.rubber(Color("171e21"))
	var metal: Material=CompactFinish.alloy(Color("b5b8ae"))
	for simple: bool in [false,true]:
		var reference: CarVisual=make(simple)
		CompactRearDesign.build(reference,paint,trim,metal)
		var expected: String=fingerprint(reference)
		var expected_nodes: int=reference.body.find_children("*","Node3D",true,false).size()
		var cooperative: CarVisual=make(simple)
		callbacks=0;cancel_after=-1
		await build(cooperative,paint,trim,metal)
		check(callbacks>=6,"rear construction supplies checkpoints between fitting groups")
		check(fingerprint(cooperative)==expected,"cooperative rear arrays, transforms and render flags exactly match synchronous construction")
		check(cooperative.body.find_children("*","Node3D",true,false).size()==expected_nodes,"cooperative construction preserves every original fitting")
		check(cooperative.paint_variants.size()==reference.paint_variants.size(),"paint ownership declarations remain exact")
		reference.free();cooperative.free()
		var cancelled: CarVisual=make(simple)
		callbacks=0;cancel_after=3
		await build(cancelled,paint,trim,metal)
		check(callbacks==3,"cancellation returns at the failed checkpoint")
		check(cancelled.body.find_child("RearLampHousingLeft",true,false)!=null and cancelled.body.find_child("RearPlateFrame",true,false)==null,"cancelled rear construction retains earlier fittings without adding later groups")
		var nodes: int=cancelled.body.get_child_count()
		for index: int in range(4): await process_frame
		check(cancelled.body.get_child_count()==nodes,"cancelled work does not resume on later frames")
		cancelled.free()
	for index: int in range(8): await process_frame
	print("COMPACT_REAR_PREPARATION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
