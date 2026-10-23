extends SceneTree
## Capture the actual initial editor while detailed preview work is held back.
## All persistence is redirected to disposable local storage.

class CaptureApp extends "res://core/app.gd":
	func _ready() -> void:
		capture_path = "editor-start-background"
		super._ready()
	func _capture() -> void: pass
	func _queue_editor_preview() -> void: pass

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/editor-start-background-2026-10-18").simplify_path().path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder)
	var storage: String = "user://editor-start-background-"+TrackLibrary.unique_id()
	var app := CaptureApp.new()
	app.library = TrackLibrary.new(storage)
	app.records = LocalRecords.new(storage.path_join("records.json"))
	app.cloud_root_override = storage.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var observations: Array[Dictionary] = []
	for biome: String in TrackTheme.IDS:
		app._start_new_document()
		app._select_creation_biome(biome)
		for frame: int in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var world: EditorWorld = app.editor_world
		var path: String = folder.path_join(biome+"-start.png")
		var error: Error = root.get_texture().get_image().save_png(path)
		observations.append({"biome":biome,"ground":world.ground_material.albedo_color.to_html(),"background":world.environment.background_color.to_html(),"preview_pending":world.visual == null and app.canvas.native_preview == null,"capture_error":error})
		print("EDITOR_START_CAPTURE: ",JSON.stringify(observations.back()))
	var file := FileAccess.open(folder.path_join("observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t"))
	file.close()
	app.queue_free()
	await process_frame
	quit()
