extends SceneTree
func _initialize() -> void: run.call_deferred()
func props(node: Object) -> Dictionary:
	var result: Dictionary={}
	for property: Dictionary in node.get_property_list():
		if not int(property.usage)&PROPERTY_USAGE_STORAGE or property.name in ["name","owner","multimesh"]: continue
		var value: Variant=node.get(property.name)
		result[property.name]=value.get_instance_id() if value is Object else value
	if node is MeshInstance3D: result["bounds"]=node.get_aabb()
	if node is MultiMeshInstance3D:
		result["multimesh_data"]=[node.multimesh.mesh,node.multimesh.custom_aabb,node.multimesh.instance_count,node.multimesh.visible_instance_count,node.multimesh.buffer]
	return result
func run() -> void:
	var doc: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json")); doc.theme="winter"
	var track: NativeTrack=TrackCompiler.compile(doc)
	var a:=NativeTrackVisual.new(); a.cache_race_world=true; root.add_child(a)
	await a.build(track,BridgePresentation.new(track),true)
	var b:=NativeTrackVisual.new(); b.cache_race_world=true; root.add_child(b)
	await b.build(track,BridgePresentation.new(track),true)
	var differences: Array=[]
	for index: int in range(a.get_child_count()):
		var x: Dictionary=props(a.get_child(index)); var y: Dictionary=props(b.get_child(index))
		for key: String in x:
			if x[key]!=y.get(key): differences.append({"index":index,"name":a.get_child(index).name,"property":key,"before":str(x[key]).left(200),"after":str(y.get(key)).left(200)})
	print("CLONE_DIFFERENCES ",JSON.stringify(differences))
	a.free(); b.free(); preload("res://track/prepared_world_cache.gd").trim_cache()
	quit()
