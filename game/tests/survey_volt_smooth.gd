extends SceneTree
const Source=preload("res://tests/support/volt_smooth_source.gd")
const D=preload("res://vehicle/car_detail_reduction.gd")
const M=preload("res://vehicle/electric_reference_mesh.gd")
const WORK: String="res://../build/volt-reflection-smoothing-2026-11-15"
const OUT: String="res://../docs/evidence/volt-reflection-smoothing-2026-11-15"
var catalog: Dictionary={};var rows: Array=[]
func _initialize() -> void: run.call_deferred()
func inspect(car: CarVisual,holders: Variant) -> void:
	if holders!=null:return
	for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		var label: String=str(part.name)
		if not (label.begins_with("ReferenceSide") or label.begins_with("ReferenceArch") or label in ["ReferenceRear","ReferenceRearDeck","ReferenceHood"] or label.begins_with("ReferenceRearQuarterPanel") or label.begins_with("ReferenceRearPillar") or label.begins_with("ReferenceWindowBottom") or label.begins_with("ReferenceAPillar")):continue
		var native: Mesh=null;var native_key: String=""
		for key: String in M.meshes:
			if key.ends_with("_simple") and key.trim_suffix("_simple").replace(".","_")==label:native=M.meshes[key];native_key=key;break
		assert(native!=null,label)
		catalog[label]={"current":part.mesh,"native":native,"native_key":native_key}
		rows.append({"name":label,"current_triangles":part.mesh.get_faces().size()/3,"native_triangles":native.get_faces().size()/3,"current_key":D.mesh_key(part.mesh),"native_key":D.mesh_key(native),"resource":part.mesh.resource_path,"native_resource":native.resource_path})
		print("VOLT_CORNER_PART ",label," current=",part.mesh.get_faces().size()/3," native=",native.get_faces().size()/3)
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=inspect
	var car=Source.new();car.vehicle_id="electric";car.simple_model=true;car.cache_rest_pose=false
	root.add_child(car)
	while not car.model_ready:await process_frame
	var resource:=Resource.new();resource.set_meta("catalog",catalog)
	assert(ResourceSaver.save(resource,WORK.path_join("survey.res"),ResourceSaver.FLAG_COMPRESS)==OK)
	FileAccess.open(OUT.path_join("survey.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	car.free();quit()
