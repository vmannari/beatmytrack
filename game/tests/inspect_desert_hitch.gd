extends SceneTree
## Read-only exact-track geometry around the captured phone event; no player records.
func _initialize() -> void:
	var file: String = ProjectSettings.globalize_path("res://../build/desert-hitch-2026-10-13/original-desert-document.json")
	var document: Dictionary = TrackLibrary.new().import_document(file)
	if document.is_empty():
		push_error("Original desert fixture is invalid")
		quit(1)
		return
	var track: NativeTrack = TrackCompiler.compile(document)
	var nearby: Array[Dictionary] = []
	for index: int in range(160,171):
		var point: Vector2 = track.route[index]
		var layer: Array[Dictionary] = []
		for bridge: Dictionary in track.creator_bridges:
			layer.append({"height":CreatorBridges.height(bridge,point),"contains":CreatorBridges.contains(bridge,point)})
		nearby.append({"index":index,"position":[point.x,point.y],"bridges":layer})
	var kinds: Dictionary = {}
	for object: Dictionary in document.get("objects",[]):
		var kind: String = str(object.get("kind","unknown"))
		kinds[kind] = int(kinds.get(kind,0))+1
	print("DESERT_HITCH_GEOMETRY ",JSON.stringify({"track_hash":track.content_hash,"matches_captured_phone":track.content_hash=="3c4040753a9955a17cab387bd18b5a1bb0912d361e6a1d7501ce71d95cfcbe75","route_count":track.route.size(),"bridge_count":track.creator_bridges.size(),"object_kinds":kinds,"nearby":nearby}))
	quit()
