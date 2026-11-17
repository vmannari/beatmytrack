extends "res://../docs/evidence/challenger-convex-fenders-2026-11-16/panel_candidate_inputs.gd"
const Model=preload("res://vehicle/super_rally_model.gd")

func run() -> void:
	var prefix: String="res://../build/challenger-convex-fenders-2026-11-16/native/"
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prefix+"manifest.json"))
	(load(Model.ROOT+"manifest.json") as JSON).data=manifest
	(load(Model.ROOT+"bonnet_contour.json") as JSON).data=JSON.parse_string(FileAccess.get_file_as_string(prefix+"bonnet_contour.json"))
	Model.hood_profile=JSON.parse_string(FileAccess.get_file_as_string(prefix+"hood_profile.json"))
	Model._asset_revision = Model.KEY
	for tier: String in ["simple","full"]:
		for entry: Dictionary in manifest.tiers[tier]:
			var mesh: ArrayMesh=load(prefix+str(entry.mesh))
			mesh.take_over_path(Model.ROOT+str(entry.mesh))
			Model.assets[Model.ROOT+str(entry.mesh)]=mesh
	await super.run()

