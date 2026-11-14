extends SceneTree
func _initialize() -> void:
	var candidate: String="res://../build/challenger-corner-roll-2026-11-13/native/"
	var manifest: Dictionary=(load(candidate+"manifest.json") as JSON).data
	var checks: int=0;var failures: Array=[];var resources: int=0
	for tier: String in ["simple","full"]:
		for item: Dictionary in manifest.tiers[tier]:
			var path: String=str(item.mesh)
			var a: Mesh=ResourceLoader.load(candidate+path,"",ResourceLoader.CACHE_MODE_IGNORE)
			var b: Mesh=ResourceLoader.load(SuperRallyModel.ROOT+path,"",ResourceLoader.CACHE_MODE_IGNORE)
			resources+=1;checks+=1
			if a.get_surface_count()!=b.get_surface_count():failures.append(path+" surfaces");continue
			for i: int in range(a.get_surface_count()):
				var aa: Array=a.surface_get_arrays(i);var bb: Array=b.surface_get_arrays(i)
				for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_INDEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:
					checks+=1
					if aa[attribute]!=bb[attribute]:failures.append(path+" attribute "+str(attribute))
	var receipt: Dictionary={"resources":resources,"checks":checks,"failures":failures,"native_geometry_exact":failures.is_empty()}
	var file:=FileAccess.open("res://../docs/evidence/challenger-corner-roll-2026-11-13/candidate-live-comparison.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"\t"));file.close()
	print("CANDIDATE_LIVE_COMPARE: ",JSON.stringify(receipt));quit(0 if failures.is_empty() else 1)
