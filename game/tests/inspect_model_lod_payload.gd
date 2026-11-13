extends SceneTree
func _initialize() -> void:
	for id: String in ["compact","forklift"]:
		var scene: PackedScene = load("res://assets/vehicles/modular_car_bases_v1/"+id+"_simple_fixed.scn")
		var holder: Node = scene.instantiate()
		var rows: Array = []
		for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
			if not part.mesh is ArrayMesh: continue
			var vertex_bytes: int = 0
			var index_bytes: int = 0
			var lod_bytes: int = 0
			var levels: int = 0
			for packet: Dictionary in part.mesh.get("_surfaces"):
				vertex_bytes += packet.vertex_data.size()+packet.get("attribute_data",PackedByteArray()).size()
				index_bytes += packet.get("index_data",PackedByteArray()).size()
				var lods: Array = packet.get("lods",[])
				levels += lods.size()/2
				for index: int in range(1,lods.size(),2): lod_bytes += lods[index].size()
			rows.append({"part":str(holder.get_path_to(part)),"vertices":vertex_bytes,"indices":index_bytes,"lod_bytes":lod_bytes,"levels":levels})
		rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.vertices+a.indices+a.lod_bytes>b.vertices+b.indices+b.lod_bytes)
		print("LOD_PAYLOAD ",id," ",JSON.stringify(rows.slice(0,8)))
		holder.free()
	quit()
