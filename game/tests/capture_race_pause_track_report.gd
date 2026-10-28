extends SceneTree
## Local visual evidence for the pause menu; never submits a report.
const OUTPUT: String = "res://../docs/evidence/race-pause-track-report-2026-10-26"

class CaptureClient extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"pause-menu-fixture"}
	func base_url() -> String: return "fixture://pause-menu"
	func signed_in() -> bool: return true

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for _frame: int in range(12): await RenderingServer.frame_post_draw

func capture(filename: String) -> void:
	await settle()
	var result: Error = root.get_texture().get_image().save_png(OUTPUT.path_join(filename))
	print("PAUSE_REPORT_CAPTURE: ",filename," error=",result)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(fixture.document)
	game.production_mode = true
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false)
	game.countdown_ticks = 0
	var client := CaptureClient.new()
	root.add_child(client)
	game.hud.community_client = client
	game.hud.map_track = game.initial_track
	game.hud.map_track.metadata.merge({"cloud_version":"pause-version","cloud_track_id":"pause-track","cloud_creator_id":"pause-creator","title":"Pause menu capture"},true)
	await settle()
	if not game.paused: game.hud.menu_button.pressed.emit()
	game.hud.pause_menu.show_main()
	await capture("pause-1280x720.png")
	print("PAUSE_REPORT_ROWS: ",game.hud.pause_menu.column.get_children().map(func(child: Node) -> String: return child.name))
	root.size = Vector2i(960,540)
	await capture("pause-960x540.png")
	game.hud.pause_menu.find_child("Reporttrack",true,false).pressed.emit()
	await capture("report-track-960x540.png")
	for child: Node in game.hud.pause_menu.get_children():
		if child is AcceptDialog:
			print("PAUSE_REPORT_DIALOG: ",child.title," target=",JSON.stringify(child.target))
	game.queue_free()
	client.queue_free()
	await process_frame
	quit()
