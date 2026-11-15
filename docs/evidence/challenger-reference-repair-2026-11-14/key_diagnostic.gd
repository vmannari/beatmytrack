extends SceneTree
func _initialize() -> void:
	var out: Dictionary={}
	for id: String in ["compact","super_rally"]:
		var holder: Node=load("res://assets/vehicles/modular_car_bases_v1/"+id+"_simple_editable.scn").instantiate()
		var before: Dictionary=holder.get_meta("modular_car_base").sources
		var after: Dictionary=preload("res://vehicle/prepared_asset_sources.gd").hashes(id)
		var changed: Array=[]
		for path: String in before.keys()+after.keys():
			if before.get(path)!=after.get(path) and not path in changed:changed.append(path)
		out[id]={"changed":changed,"before":before,"after":after}
		holder.free()
	FileAccess.open("res://../build/challenger-reference-repair-2026-11-14/key-diagnostic.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("KEY_SOURCE_DIAGNOSTIC compact=",out.compact.changed," super_rally=",out.super_rally.changed)
	quit()
