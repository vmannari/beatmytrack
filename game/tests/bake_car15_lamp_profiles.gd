extends "res://tests/export_car15_proof.gd"
const Lamps=preload("res://vehicle/compact_front_lamps.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var source_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("retessellation-input.json")))
	var targets: Dictionary={}
	for key: String in catalog:
		var entry: Dictionary=catalog[key]
		if entry.vehicle!="compact" or entry.name not in ["FrontLampBezels","FrontLampOpticalShades","FrontLampGaskets"]: continue
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: float in [-1.0,1.0]:
			match str(entry.name):
				"FrontLampBezels": await Lamps._revolve(tool,side,[Vector2(0.119,-0.039),Vector2(0.126,-0.034),Vector2(0.128,-0.027),Vector2(0.125,-0.023),Vector2(0.119,-0.024)],20,true,true)
				"FrontLampOpticalShades":
					await Lamps._revolve(tool,side,[Vector2(0.109,-0.034),Vector2(0.117,-0.037),Vector2(0.118,-0.033),Vector2(0.110,-0.030)],18,true,true)
					await Lamps._revolve(tool,side,[Vector2(0.019,-0.038),Vector2(0.027,-0.034),Vector2(0.026,-0.028),Vector2(0.019,-0.028)],12,true,true)
				"FrontLampGaskets": await Lamps._revolve(tool,side,[Vector2(0.120,-0.026),Vector2(Lamps.RADIUS,-0.016),Vector2(Lamps.RADIUS,0.003),Vector2(0.120,0.003)],20,true,false)
		tool.index();tool.generate_tangents()
		var mesh: ArrayMesh=tool.commit()
		if mesh.get_faces().size()>=entry.source.get_faces().size(): continue
		var surfaces: Array=[]
		for surface: int in range(entry.source.get_surface_count()):
			var values: Dictionary=fields(entry.source,surface);values.vertices=vertices(entry.source,surface);values.indices=indices(entry.source,surface);values.attributes=attributes(entry.source,surface);surfaces.append(values)
		source_data[key]={"name":entry.name,"surfaces":surfaces}
		targets[key]={"vertices":vertices(mesh,0),"indices":indices(mesh,0)}
	FileAccess.open(WORK.path_join("retessellation-input.json"),FileAccess.WRITE).store_string(JSON.stringify(source_data))
	FileAccess.open(WORK.path_join("lamp-targets.json"),FileAccess.WRITE).store_string(JSON.stringify(targets))
	print("CAR15_REGULAR_LAMP_PROFILES ",targets.size());quit()
