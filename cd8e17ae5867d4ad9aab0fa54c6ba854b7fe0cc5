extends "res://tests/test_modular_car_assets.gd"
func props(material: Material)->Dictionary:
	var values: Dictionary={}
	for property: Dictionary in material.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"):
			var value: Variant=material.get(property.name)
			values[property.name]=[value.get_class(),value.resource_path,value.get_image().get_data().hex_encode().sha256_text()] if value is Texture2D else value_key(value)
	return values
func run()->void:
	var a: CarVisual=await make_car("kart",true,false,VehicleCustomisation.defaults(),false)
	var b: CarVisual=await make_car("kart",true,false,VehicleCustomisation.defaults(),true)
	var left: Dictionary={};var right: Dictionary={}
	for pair: Array in [[a,left],[b,right]]:
		for mesh: MeshInstance3D in TriangleCompare.meshes(pair[0]):
			for surface: int in range(mesh.mesh.get_surface_count()):
				var material: Material=mesh.get_active_material(surface)
				var tris: int=mesh.mesh.surface_get_array_index_len(surface)/3 if mesh.mesh.surface_get_array_index_len(surface)>0 else mesh.mesh.surface_get_array_len(surface)/3
				if tris in [92,269,40]:pair[1][tris]=props(material)
	for count: int in left:
		for key: Variant in left[count]:
			if left[count][key]!=right[count].get(key):print("MATERIAL_PROPERTY ",count," ",key," SOURCE ",left[count][key]," PREPARED ",right[count].get(key))
	a.free();b.free();quit()
