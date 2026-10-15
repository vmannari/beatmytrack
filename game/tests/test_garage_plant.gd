extends SceneTree
## Geometry/render safety and resource reuse for the decorative Garage prop.
const Plant = preload("res://ui/garage_plant.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func _run() -> void:
	var room := Node3D.new()
	root.add_child(room)
	Plant.build(room)
	var plant: Node3D = room.get_node("GarageDisplayPlant")
	check(plant.position == Vector3(-9.55,0,-2.1),"placement retained")
	check(Plant.meshes.size() == 5 and Plant.finishes.size() == 5,"bounded five immutable geometry/finish groups")
	var total: int = 0
	var inverted: int = 0
	var degenerate: int = 0
	var bounds := AABB()
	var facts: Array[Dictionary] = []
	for mesh: ArrayMesh in Plant.meshes:
		var previous_inverted: int = inverted
		var previous_degenerate: int = degenerate
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var finite: bool = true
		var unit: bool = true
		for index: int in range(vertices.size()):
			finite = finite and vertices[index].is_finite() and normals[index].is_finite() and uv[index].is_finite()
			unit = unit and absf(normals[index].length()-1.0)<0.002
		for triangle: int in range(0,indices.size(),3):
			var a: int = indices[triangle]
			var b: int = indices[triangle+1]
			var c: int = indices[triangle+2]
			var cross_product: Vector3 = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
			if cross_product.length_squared()<1e-19: degenerate += 1
			elif cross_product.dot(normals[a]+normals[b]+normals[c])>1e-9:
				inverted += 1
		check(finite,"finite geometry and UVs")
		check(unit,"unit smooth normals")
		check(mesh.get_surface_count() == 1,"each material has one batched surface")
		total += indices.size()/3
		bounds = bounds.merge(mesh.get_aabb())
		facts.append({"vertices":vertices.size(),"triangles":indices.size()/3,"inverted":inverted-previous_inverted,"degenerate":degenerate-previous_degenerate})
	check(inverted == 0,"all nondegenerate faces wind toward their authored normals")
	check(degenerate == 0,"collapsed leaf/lathe pole triangles omitted")
	check(total<20000,"whole prop stays below 20000 triangles")
	check(bounds.position.x> -0.75 and bounds.end.x<0.75 and bounds.position.z> -0.75 and bounds.end.z<0.75,"crown clears side wall and stays within furnishing footprint")
	check(bounds.end.y>1.9 and bounds.end.y<2.3 and bounds.position.y>=0,"natural height, no geometry below floor")
	for finish: Material in Plant.finishes:
		check(not finish is StandardMaterial3D or finish.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,"opaque leaf/soil/shell: no alpha layers")
	var second := Node3D.new()
	root.add_child(second)
	Plant.build(second)
	var second_plant: Node3D = second.get_node("GarageDisplayPlant")
	for index: int in range(5):
		var first: MeshInstance3D = plant.get_child(index)
		var reused: MeshInstance3D = second_plant.get_child(index)
		check(first.mesh == reused.mesh and first.material_override == reused.material_override,"repeated showroom reuses exact mesh/material resources")
	check(not plant.is_processing() and not second_plant.is_processing(),"static furnishing has no frame callback")
	print("PLANT_GEOMETRY ",JSON.stringify({"parts":facts,"triangles":total,"inverted":inverted,"degenerate_pole_faces":degenerate,"bounds_position":str(bounds.position),"bounds_size":str(bounds.size)}))
	room.free()
	second.free()
	print("GARAGE_PLANT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
