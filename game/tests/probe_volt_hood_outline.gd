extends SceneTree
const B=preload("res://vehicle/electric_reference_body.gd")
const M=preload("res://vehicle/electric_reference_mesh.gd")
func _initialize() -> void:
	var result: Dictionary={"samples":[],"meshes":{}}
	for u: float in [0.09,0.50,0.91]:
		for v: float in [0.045,0.5,0.97]:result.samples.append({"u":u,"v":v,"p":B.hood_point(u,v)})
	for simple: bool in [true,false]:
		var key: String="SportBonnetShutLine_fitted_v2"+("_simple" if simple else "")
		var file: String=key.sha256_text().left(24)+".res"
		var car:=CarVisual.new();car.simple_model=simple
		var parent:=Node3D.new()
		B.build_hood(car,parent,CompactFinish.paint(Color.WHITE),CompactFinish.rubber(Color.BLACK))
		var mesh: Mesh=M.meshes[key]
		result.meshes[key]={"cached":ResourceLoader.exists(M.ASSET_ROOT.path_join(file)),"file":file,"triangles":mesh.get_faces().size()/3,"key":preload("res://vehicle/car_detail_reduction.gd").mesh_key(mesh)}
		parent.free();car.free()
	FileAccess.open("res://../docs/evidence/volt-hood-outline-2026-11-16/probe.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));quit()
