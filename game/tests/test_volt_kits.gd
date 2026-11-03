extends SceneTree
## Verify every Volt option on both editable model qualities.
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func signature(frames: Array) -> String:
	var parts: Array[String] = []
	for frame: Node3D in frames:
		for mesh: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh == null: continue
			var arrays: Array=mesh.mesh.surface_get_arrays(0)
			parts.append(var_to_bytes([mesh.transform,arrays[Mesh.ARRAY_VERTEX]]).hex_encode().sha256_text())
	parts.sort()
	return str(parts).sha256_text()

func run() -> void:
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	var defaults: Dictionary=VehicleCustomisation.defaults()
	for category: String in VehicleCustomisation.CATEGORIES:
		check(VehicleCustomisation.options(category,"electric").size()==16,"original plus 15 Volt options "+category)
		for option: Array in VehicleCustomisation.options(category,"electric"):
			var value: Dictionary=defaults.duplicate(true)
			value[category]=option[0]
			check(VehicleCustomisation.valid(value,"electric"),"admit Volt option "+category+"/"+str(option[0]))
			check(not VehicleCustomisation.description(category,str(option[0]),"electric").is_empty(),"description "+category+"/"+str(option[0]))
			if option[0]!="stock": check(not VehicleCustomisation.valid(value,"kart"),"vehicle-scoped part "+category+"/"+str(option[0]))
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.editable_kits=true
		car.batch_parts=false
		car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for category: String in VehicleCustomisation.CATEGORIES:
			var known: Dictionary={}
			for option: Array in VehicleCustomisation.options(category,"electric"):
				var value: Dictionary=defaults.duplicate(true)
				value[category]=option[0]
				car.change_kit_parts(value)
				var frames: Array=car.kit_frames.get(category,[])
				check(frames.size()==(4 if category=="rims" else 1),"replaceable frames "+category+"/"+str(option[0])+" simple="+str(simple))
				var meshes:=0
				for frame: Node3D in frames: meshes+=frame.find_children("*","MeshInstance3D",true,false).size()
				check(meshes>0 if option[0]!="stock" or category in ["hood","rims"] else meshes==0,"part geometry "+category+"/"+str(option[0]))
				if category=="hood":
					var stock_hoods: int=car.body.find_children("ReferenceHood","MeshInstance3D",true,false).size()
					var custom_hoods: int=car.body.find_children("VoltHoodSkinV5_*","MeshInstance3D",true,false).size()
					check(stock_hoods==(1 if option[0]=="stock" else 0) and custom_hoods==(0 if option[0]=="stock" else 1),"hood replaces original "+str(option[0])+" simple="+str(simple))
				if option[0]!="stock":
					var sig: String=signature(frames)
					check(not known.has(sig),"distinct geometry "+category+"/"+str(option[0])+" simple="+str(simple))
					known[sig]=true
			car.change_kit_parts(defaults)
			check(car.customisation==defaults,"restore original "+category)
		var combined: Dictionary={"version":1,"hood":"volt_triple","aero":"volt_gt","rims":"volt_mesh","body":"volt_sport"}
		car.change_kit_parts(combined)
		check(car.customisation==combined and car.rolling_wheels.size()==4 and car.front_wheels.size()==2,"independent simultaneous parts and live wheels")
		car.queue_free()
		await process_frame
	print("VOLT_KITS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
