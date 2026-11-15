extends SceneTree
const Source=preload("res://tests/support/volt_smooth_source.gd")
const D=preload("res://vehicle/car_detail_reduction.gd")
var expected: Dictionary={};var checks: int=0;var failures: int=0
func observe(car: CarVisual,holders: Variant) -> void:
	if holders!=null:return
	var found: Dictionary={}
	for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		var label: String=str(part.name)
		if not expected.has(label):continue
		checks+=1;found[label]=true
		if D.mesh_key(part.mesh)!=expected[label].after:failures+=1;printerr("VSR_CURRENT_SOURCE_FAIL ",label)
	checks+=1
	if found.size()!=expected.size():failures+=1;printerr("VSR_CURRENT_SOURCE_FAIL missing charts")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	expected=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/volt-reflection-smoothing-2026-11-15/publication.json")).replacements
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=observe
	var car=Source.new();car.vehicle_id="electric";car.editable_kits=false;car.cache_rest_pose=false;root.add_child(car)
	while not car.model_ready:await process_frame
	car.free();print("VSR_CURRENT_SOURCE ",checks," checks, ",failures," failures");quit(1 if failures else 0)
