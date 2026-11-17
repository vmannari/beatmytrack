extends "res://tests/capture_car_mechanics.gd"
## Actual prepared controls differ only by this pass's new component levels.
func capture() -> void:
	Engine.time_scale=0.0
	preload("res://ui/garage_car_cache.gd").enabled=false
	var directory: String=OUT.path_join("distance-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for id: String in ["compact","kart","hovercraft"]:
		var only: String=""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--vehicle="):only=argument.trim_prefix("--vehicle=")
		if not only.is_empty() and only!=id:continue
		var view:=CarShowroom.new();view.vehicle_id=id;view.simple_model=true;view.read_only=true;view.size=Vector2(1000,760);view.livery=VehicleLivery.defaults(id)
		var hits: int=Base.hits;root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready:await process_frame
		check(Base.hits==hits+1,"actual prepared distance model "+id)
		var old: Node3D=view.car.duplicate();old.set_script(null);view.car.get_parent().add_child(old)
		var removed: int=0;var bytes_added: int=0
		for part: MeshInstance3D in old.find_children("*","MeshInstance3D",true,false):
			if not part.mesh.has_meta("car_mechanics_added_levels"):continue
			var source: ArrayMesh=part.mesh;var packets: Array=source.get("_surfaces").duplicate(true)
			for entry: Array in source.get_meta("car_mechanics_added_levels"):
				var levels: Array=packets[int(entry[0])].get("lods",[]);var retained: Array=[];var found: bool=false
				for at: int in range(0,levels.size(),2):
					if levels[at]==entry[1]:found=true;bytes_added+=levels[at+1].size();continue
					retained.append(levels[at]);retained.append(levels[at+1])
				check(found,"exact regional level available "+id)
				if retained.is_empty():packets[int(entry[0])].erase("lods")
				else:packets[int(entry[0])].lods=retained
				removed+=1
			var mesh:=ArrayMesh.new();mesh.set("_surfaces",packets);mesh.custom_aabb=source.custom_aabb;mesh.shadow_mesh=source.shadow_mesh
			check(preload("res://tests/support/car_refinement_lods.gd").new().master_key(mesh)==preload("res://tests/support/car_refinement_lods.gd").new().master_key(source),"distance control retains every master byte")
			part.mesh=mesh
		check(removed>0,"regional levels survive actual packing "+id)
		var best_saving: int=0
		for angle: float in [-0.70,2.45]:
			for zoom_value: float in [1.0,2.0,4.0,8.0,12.0]:
				view.yaw=angle;view.elevation=0.31;view.zoom=zoom_value;view._orbit()
				var label: String=id+"-"+str(angle)+"-"+str(zoom_value)
				var row: Dictionary=await pair(view,old,view.car,label,directory)
				row.merge({"vehicle":id,"zoom":zoom_value,"angle":angle,"regional_index_bytes":bytes_added})
				var before: Image=Image.load_from_file(directory.path_join(row.before_image));var after: Image=Image.load_from_file(directory.path_join(row.after_image))
				if zoom_value==1.0:check(before.get_data()==after.get_data(),"near rendering remains pixel exact "+label)
				best_saving=maxi(best_saving,int(row.visible_primitives_before)-int(row.visible_primitives_after))
				pairs.append(row)
		check(best_saving>0,"renderer actually submits fewer distant primitives "+id)
		print("MECHANICS_DISTANCE_NATIVE ",id," levels=",removed," index_bytes=",bytes_added," maximum_saved=",best_saving)
		old.free();view.free();await process_frame
	FileAccess.open(directory.path_join("comparisons.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pairs":pairs},"  "))
	print("MECHANICS_DISTANCE_NATIVE_COMPLETE ",checks," checks ",failures," failures");quit(1 if failures else 0)
