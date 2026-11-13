extends SceneTree
## Audit actual fail-closed cache decisions; misses are findings, not waived checks.
const Base=preload("res://vehicle/modular_car_base.gd")
const Sources=preload("res://vehicle/prepared_asset_sources.gd")
var rows: Array=[]
func _initialize()->void:run.call_deferred()
func run()->void:
	for id: String in VehicleCatalog.IDS:
		var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=true
		var path: String=Base.path_for(car)
		var row: Dictionary={"type":"car_base","vehicle":id,"path":path,"exists":ResourceLoader.exists(path),"eligible":Base._eligible(car)}
		if row.exists:
			var packed: PackedScene=load(path);var holder: Node=packed.instantiate()
			var data: Dictionary=holder.get_meta("modular_car_base",{})
			row.key_matches=data.get("key",[])==Base.key_for(car)
			row.runtime_sources_match=Sources.runtime_projection(data.get("sources",{}))==Sources.runtime_hashes(car.model_id)
			row.key_differences=[]
			var actual: Array=data.get("key",[]);var expected: Array=Base.key_for(car)
			for index: int in range(mini(actual.size(),expected.size())):
				if actual[index]!=expected[index]:row.key_differences.append({"field":index,"stored":actual[index],"current":expected[index]})
			holder.free()
		rows.append(row);car.free()
	for theme: String in TrackTheme.IDS:
		for kind: String in SceneryMeshLods.KINDS:
			CreatorPropVisual.trim_cache()
			var packet: Dictionary=CreatorPropVisual.warm(Callable(),kind,theme)
			var published: bool=CreatorPropVisual.publish_warm(packet)
			var source: ArrayMesh=CreatorPropVisual.meshes.get(CreatorPropVisual._key(kind,theme,-1.0,""))
			var asset: Resource=load(SceneryMeshLods.ROOT+kind+".res")
			rows.append({"type":"scenery_plan","theme":theme,"kind":kind,"published":published,"source_present":source!=null,"accepted_plan":source!=null and source.has_meta("scenery_lod_plan"),"current_signature":SceneryMeshLods.signature(source) if source!=null else "","stored_signature":asset.get_meta("signature","")})
	var folder: String="res://../docs/evidence/asset-review-2026-11-08"
	FileAccess.open(folder.path_join("cache-guards.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"notes":"Actual editor/source-checkout diagnostics only; no cache guard changed, no assets rebaked, no installed build conclusion."},"\t")+"\n")
	print("ASSET_GUARD_REVIEW ",rows.size()," observations")
	quit()
