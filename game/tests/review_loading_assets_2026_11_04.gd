extends SceneTree
## Read-only baked-resource eligibility audit, never constructs or blesses new assets.
const Base = preload("res://vehicle/modular_car_base.gd")
const Garage = preload("res://ui/garage_car_cache.gd")
const Header = preload("res://ui/header_simple_cache.gd")
func _initialize() -> void: run.call_deferred()
func differences(saved: Dictionary, current: Dictionary) -> Array:
	var result: Array = []
	for path: String in current:
		if saved.get(path,"") != current[path]: result.append(path)
	for path: String in saved:
		if not current.has(path): result.append(path)
	return result
func run() -> void:
	var rows: Array = []
	for id: String in VehicleCatalog.IDS:
		var sources: Dictionary = Base.source_hashes(id)
		for simple: bool in [false,true]:
			for editable: bool in [false,true]:
				var car := CarVisual.new()
				car.vehicle_id = id
				car.simple_model = simple
				car.editable_kits = editable
				var path: String = Base.path_for(car)
				if ResourceLoader.exists(path):
					var packed: PackedScene = load(path)
					var holder: Node = packed.instantiate()
					var data: Dictionary = holder.get_meta("modular_car_base",{})
					rows.append({"kind":"modular","path":path,"sha256":FileAccess.get_sha256(path),"eligible":Base._eligible(car),"key_matches":data.get("key",[]) == Base.key_for(car),"sources_match":data.get("sources",{}) == sources,"differences":differences(data.get("sources",{}),sources)})
					holder.free()
				car.free()
		var car := CarVisual.new()
		car.vehicle_id = id
		car.editable_kits = VehicleCustomisation.supported(id)
		var path: String = Garage.DIRECTORY+id+".scn"
		var packed: PackedScene = load(path)
		var holder: Node = packed.instantiate()
		var data: Dictionary = holder.get_meta("garage_rest",{})
		var geometry_sources: Dictionary = Garage.geometry_sources(id)
		rows.append({"kind":"garage","path":path,"sha256":FileAccess.get_sha256(path),"key_matches":data.get("key",[]) == Garage.geometry_key(car),"sources_match":data.get("sources",{}) == geometry_sources,"differences":differences(data.get("sources",{}),geometry_sources)})
		holder.free()
		car.free()
	var car := CarVisual.new()
	car.simple_model = true
	var path: String = Header.DIRECTORY+"compact.scn"
	var packed: PackedScene = load(path)
	var holder: Node = packed.instantiate()
	var data: Dictionary = holder.get_meta("garage_rest",{})
	var revision: String = Header.geometry_revision()
	rows.append({"kind":"header","path":path,"sha256":FileAccess.get_sha256(path),"key_matches":Header.valid_data(data,car,revision),"sources_match":data.get("sources",{}) == Header.geometry_sources(),"differences":differences(data.get("sources",{}),Header.geometry_sources())})
	holder.free()
	car.free()
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows},"  "))
	print("ASSET_REVIEW ",rows.size()," resources inspected")
	quit()
