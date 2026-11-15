extends SceneTree
const Coarse = preload("res://vehicle/car_coarse_reduction.gd")
var baker = preload("res://tests/support/car_coarse_bake.gd").new()

func _initialize() -> void: run.call_deferred()

func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	Coarse.offline=baker.create_coarse
	var only: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle="): only=argument.trim_prefix("--vehicle=")
	for id: String in Coarse.IDS:
		if not only.is_empty() and id!=only: continue
		for editable: bool in [false,true]:
			var car := CarVisual.new()
			car.vehicle_id=id
			car.simple_model=true
			car.editable_kits=editable
			car.cache_rest_pose=false
			car.livery=VehicleLivery.defaults(id)
			root.add_child(car)
			while not car.model_ready: await process_frame
			print("COARSE_STOCK ",id," editable=",editable," triangles=",triangles(car))
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id):
						var parts: Dictionary = car.customisation.duplicate()
						parts[category]=option[0]
						car.change_kit_parts(parts)
					var parts: Dictionary=car.customisation.duplicate()
					parts[category]="stock"
					car.change_kit_parts(parts)
			car.free()
			await process_frame
		print("COARSE_BAKE ",id," resources=",baker.observations.size())
	var directory: String="res://../docs/evidence/challenger-continuous-side-2026-11-15"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	FileAccess.open(directory.path_join("recipes"+("-"+only if not only.is_empty() else "")+".json"),FileAccess.WRITE).store_string(JSON.stringify(baker.observations,"\t"))
	quit()

func triangles(car: CarVisual) -> int:
	var count: int=0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh!=null and part.is_visible_in_tree() and part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: count+=part.mesh.get_faces().size()/3
	return count

