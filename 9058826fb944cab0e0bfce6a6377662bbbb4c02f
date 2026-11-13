extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		var car:=CarVisual.new();car.vehicle_id=id;car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready:await process_frame
		var exact: Dictionary={};var colours: Dictionary={};var count: int=0
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null or part.mesh.get_surface_count()!=1 or part.get_child_count()!=0:continue
			var material: Material=part.get_active_material(0)
			if not material is StandardMaterial3D or material.next_pass!=null:continue
			var values: Array=[];var colour_values: Array=[]
			for property: Dictionary in material.get_property_list():
				if not (int(property.usage)&PROPERTY_USAGE_STORAGE) or str(property.name).begins_with("resource_"):continue
				values.append([property.name,material.get(property.name)])
				if property.name not in ["albedo_color","vertex_color_use_as_albedo","vertex_color_is_srgb"]:colour_values.append([property.name,material.get(property.name)])
			var common: Array=[part.get_parent().get_instance_id(),part.transform,part.cast_shadow,part.layers]
			var key: String=var_to_bytes([common,values]).hex_encode();exact[key]=int(exact.get(key,0))+1
			key=var_to_bytes([common,colour_values]).hex_encode();colours[key]=int(colours.get(key,0))+1;count+=1
		var savings: int=0;var colour_savings: int=0
		for value: int in exact.values():savings+=maxi(0,value-1)
		for value: int in colours.values():colour_savings+=maxi(0,value-1)
		print("BATCH_POTENTIAL ",id," parts=",count," exact=",savings," colour=",colour_savings)
		car.free();await process_frame
	quit()
