extends "audit.gd"
func run() -> void:
	mode = "interactions"
	out = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-audit-2026-10-23").simplify_path()
	root.size = Vector2i(1280,720)
	app = load("res://core/app.tscn").instantiate(); app.library = TrackLibrary.new(out+"/interaction-fixtures"); app.records = LocalRecords.new(out+"/interaction-fixtures/records.json"); app.cloud_root_override = out+"/interaction-fixtures/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var doc: Dictionary = circuit(96); doc.objects = objects(95)
	await show(doc,"open")
	await drag_road(false); await drag_road(true); await drag_object()
	app.queue_free(); await process_frame; await process_frame
	record("final",{"failures":failures,"memory":memory()}); quit(1 if not failures.is_empty() else 0)
