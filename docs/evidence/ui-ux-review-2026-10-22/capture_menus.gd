extends SceneTree
## Disposable, offline inspection of production menus for the design review.
const OUT = "res://../docs/evidence/ui-ux-review-2026-10-22/current"
var app: Node

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	await create_timer(0.65).timeout
	await process_frame
	await RenderingServer.frame_post_draw

func shot(caption: String) -> void:
	await settle()
	var path: String = ProjectSettings.globalize_path(OUT).path_join(caption + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	print("DESIGN_CAPTURE ", caption, " ", error)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	var isolated: String = "user://ui_ux_review_" + TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(isolated.path_join("tracks"))
	app.records = LocalRecords.new(isolated.path_join("records.json"))
	app.cloud_root_override = isolated.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await shot("account-first-launch-1280")
	app._show_screen("tracks")
	await settle()
	var browser: TrackBrowser = app.root_ui.find_child("TrackBrowser",true,false)
	if browser.cloud != null:
		browser.cloud.changed.disconnect(browser._cloud_changed)
		browser.cloud = null
	var fixture := TrackCatalog.new(app.library)
	fixture.add_builtin(BuiltinTracks.ids()[0])
	browser.catalog.entries.assign(fixture.entries)
	browser._refresh()
	browser._select(fixture.entries[0])
	await create_timer(1.0).timeout
	browser._open_track_view()
	await shot("free-race-detail-offline-1280")
	app._show_screen("settings")
	await shot("settings-controls-1280")
	var settings: SettingsPage = app.root_ui.find_child("SettingsPage",true,false)
	var saved_before: float = float(app.records.settings.get("camera_speed_zoom_strength",CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH))
	settings.draft_speed_zoom_strength = 0.11
	app._show_screen("garage")
	await settle()
	app._show_screen("settings")
	await settle()
	settings = app.root_ui.find_child("SettingsPage",true,false)
	print("SETTINGS_DEPARTURE ",JSON.stringify({"saved_before":saved_before,"draft_before_departure":0.11,"draft_after_return":settings.draft_speed_zoom_strength,"save_value":app.records.settings.get("camera_speed_zoom_strength",CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH),"screen":app.screen}))
	app._show_screen("profile")
	await shot("profile-guest-1280")
	app._show_screen("store")
	await shot("store-offline-1280")
	app._show_screen("biome")
	await shot("create-entry-1280")
	root.size = Vector2i(960,540)
	app._show_screen("settings")
	await shot("settings-controls-960")
	app.queue_free()
	await process_frame
	await process_frame
	print("DESIGN_REVIEW_CAPTURE_COMPLETE")
	quit()
