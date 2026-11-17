extends "res://tests/test_car_model_revert.gd"
const WORK: String="res://../build/volt-hood-outline-2026-11-16"
const VHO_OUT: String="res://../docs/evidence/volt-hood-outline-2026-11-16"
func non_contour_signature(holder: Node3D) -> Array:
	var result: Array=[]
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		var material: Material=part.get_active_material(0)
		if material is ShaderMaterial and material.shader.resource_path.ends_with("panel_contour.gdshader"):continue
		var streams: Array=[]
		for surface: int in range(part.mesh.get_surface_count()):
			var packet: Dictionary=RenderingServer.mesh_get_surface(part.mesh.get_rid(),surface)
			for field: String in ["format","vertex_count","index_count","vertex_data","attribute_data","skin_data","index_data","blend_shapes"]:streams.append(packet.get(field))
		result.append(var_to_bytes([holder.global_transform.affine_inverse()*part.global_transform,part.cast_shadow,streams]).hex_encode().sha256_text())
	result.sort();return result
func _initialize() -> void:verify.call_deferred()
func verify() -> void:
	Base.enabled=true;Kits.enabled=true;Cache.enabled=true;preload("res://ui/garage_car_cache.gd").enabled=false
	var rows: Array=[]
	for mode: String in ["stock","fitted","full"]:
		var old: Node3D=load(WORK.path_join("electric-"+mode+"-before.scn")).instantiate();root.add_child(old)
		var car:=CarVisual.new();car.vehicle_id="electric";car.simple_model=mode!="full";car.editable_kits=mode=="fitted";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults("electric");car.customisation=VehicleCustomisation.defaults()
		if mode=="fitted":
			for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,"electric")[-1][0]
		var before_hits: int=Base.hits;var kit_hits: int=Kits.hits;root.add_child(car)
		while not car.model_ready:await process_frame
		check(Base.hits==before_hits+1,"actual current prepared "+mode)
		if mode=="fitted":check(Kits.hits==kit_hits+4,"actual four fitted modules")
		var measured: Dictionary=inventory(car,false)
		check(measured.triangles==int({"stock":21309,"fitted":27033,"full":114648}[mode]),"unchanged whole-model triangle count "+mode)
		check(non_contour_signature(car)==non_contour_signature(old),"all non-contour GPU streams and transforms exact "+mode)
		rows.append({"mode":mode,"inventory":measured});old.free();car.free();await process_frame
	FileAccess.open(VHO_OUT.path_join("prepared.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("VHO_PREPARED ",checks," checks, ",failures," failures");quit(1 if failures else 0)
