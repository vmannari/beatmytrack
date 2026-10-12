extends SceneTree
func _initialize() -> void:
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string("res://editor/track_compiler.gd").replace("class_name TrackCompiler","").replace("CreatorScenery.generate(","load(\"res://../build/procedural-placement-2026-10-11/baseline_scenery.gd\").generate(")
	if baseline.reload() != OK: quit(1); return
	var failures: int = 0
	for theme: String in TrackDocument.THEMES:
		var doc: Dictionary = TrackDocument.create_default()
		doc.theme = theme
		if theme == "desert": doc.surface = "dirt"; doc.layout.surface = "dirt"
		var before: NativeTrack = baseline.compile(doc)
		var after: NativeTrack = TrackCompiler.compile(doc)
		var exact: bool = before.content_hash == after.content_hash and before.cells == after.cells and before.deck_cells == after.deck_cells and before.route == after.route and before.metadata.scenery_objects == after.metadata.scenery_objects
		print("ORDINARY_BASELINE theme=",theme," exact=",exact," hash=",before.content_hash)
		if not exact: failures += 1
	print("ORDINARY_BASELINE failures=",failures)
	quit(0 if failures == 0 else 1)
