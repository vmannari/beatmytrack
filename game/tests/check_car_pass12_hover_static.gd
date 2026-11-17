extends SceneTree
const Source=preload("res://tests/support/car_pass12_source.gd")
const Static=preload("res://vehicle/car_static_reduction.gd")
const Detail=preload("res://vehicle/car_detail_reduction.gd")
var rows: Array=[]
var mode: String=""
var old_source: bool=false
func observe(car: CarVisual,holders: Variant) -> void:
	if not old_source:return
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders:parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		var file: String=part.mesh.resource_path.trim_prefix("res://")
		var original: String="res://../build/car-pass12-2026-11-16/before/game/"+file
		if ResourceLoader.exists(original):part.mesh=load(original)
func reduce(part: MeshInstance3D,id: String) -> ArrayMesh:
	var result: ArrayMesh=Static.resolve(part.mesh,id)
	if result!=part.mesh:rows.append({"mode":mode,"old_source":old_source,"path":str(part.name),"before":part.mesh.get_faces().size()/3,"after":result.get_faces().size()/3,"source":Detail.mesh_key(part.mesh)})
	return result
func _initialize() -> void:run.call_deferred()
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=observe;Static.offline=reduce
	var totals: Array=[]
	for prior: bool in [true,false]:
		old_source=prior
		for current: String in ["stock","fitted"]:
			mode=current
			var car=Source.new();car.vehicle_id="hovercraft";car.simple_model=true;car.cache_rest_pose=false;car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,"hovercraft")[-1][0]
			root.add_child(car)
			while not car.model_ready:await process_frame
			var count: int=0
			for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
				if part.is_visible_in_tree() and part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:count+=part.mesh.get_faces().size()/3
			totals.append({"mode":mode,"old_source":prior,"triangles":count});car.free();await process_frame
	FileAccess.open("res://../docs/evidence/car-pass12-2026-11-16/hover-static-control.json",FileAccess.WRITE).store_string(JSON.stringify({"totals":totals,"reductions":rows},"  "))
	print("CP2_HOVER_STATIC ",totals);quit()
