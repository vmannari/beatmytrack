extends SceneTree
## Export preflight: metadata and full dependency checks for every expected bake.
const Base=preload("res://vehicle/modular_car_base.gd")
const Kits=preload("res://vehicle/modular_car_kits.gd")
const Garage=preload("res://ui/garage_car_cache.gd")
const Header=preload("res://ui/header_simple_cache.gd")
var checks: int=0
var failures: int=0
var resources: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("PREPARED_ASSET_FAIL ",label)
func inspect(path: String,metadata: String,key: Array,sources: Dictionary) -> void:
	check(ResourceLoader.exists(path),"exists "+path)
	if not ResourceLoader.exists(path): return
	var packed: PackedScene=load(path)
	check(packed!=null,"loads "+path)
	if packed==null: return
	var holder: Node=packed.instantiate()
	var data: Dictionary=holder.get_meta(metadata,{})
	resources+=1
	check(data.get("key",[])==key,"current key "+path)
	check(not sources.is_empty() and data.get("sources",{})==sources,"complete current sources "+path)
	if metadata!="modular_kit": check(Base._valid_holder(holder,data),"complete articulation "+path)
	holder.free()
func run() -> void:
	check(not preload("res://vehicle/prepared_asset_sources.gd").manifest().is_empty(),"dependency manifest available")
	for id: String in ["electric"]:
		if ("--exclude-vehicle="+id) in OS.get_cmdline_user_args(): continue
		var sources: Dictionary=Base.source_hashes(id)
		var validation=preload("res://vehicle/prepared_asset_sources.gd")
		check(validation.runtime_projection(sources)==validation.runtime_hashes(id),"runtime code/configuration guard covers every preserved leaf "+id)
		for simple: bool in [false,true]:
			if "--simple-only" in OS.get_cmdline_user_args() and not simple: continue
			for editable: bool in [false,true]:
				if editable and not VehicleCustomisation.supported(id): continue
				var car:=CarVisual.new()
				car.vehicle_id=id;car.simple_model=simple;car.editable_kits=editable
				check(Base._eligible(car),"base eligible "+id)
				inspect(Base.path_for(car),"modular_car_base",Base.key_for(car),sources)
				if editable:
					for category: String in VehicleCustomisation.CATEGORIES:
						for option: Array in VehicleCustomisation.options(category,id).slice(1):
							inspect(Kits.path_for(car,category,option[0]),"modular_kit",Kits.key_for(car,category,option[0]),Kits.geometry_sources(id))
				car.free()
		if "--simple-only" not in OS.get_cmdline_user_args():
			var car:=CarVisual.new()
			car.vehicle_id=id;car.simple_model=false;car.editable_kits=VehicleCustomisation.supported(id)
			inspect(Garage.DIRECTORY+car.model_id+".scn","garage_rest",Garage.geometry_key(car),Garage.geometry_sources(id))
			car.free()
	print("PREPARED_ASSETS ",resources," resources; ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
