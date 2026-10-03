extends SceneTree
## Desktop evidence contains fictional identities, scores and isolated files.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var canvas: Control
var folder: String

class FixtureClient extends Client:
	var unavailable: bool = false
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if unavailable: return _failure("NETWORK_ERROR")
		var lower: bool = path.contains("cursor=")
		var items: Array = []
		for index: int in range(8): items.append({"rank":10001+index if lower else index+1,"display_name":"Fixture racer "+str(index+1),"time_ticks":12000+index*10})
		return {"ok":true,"status":200,"error":"","data":{"population":10101,"board_id":"fixture-board","items":items,"next_cursor":"fixture-page","next_offset":10020}}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	folder = ProjectSettings.globalize_path("res://../build/review-followups-capture-"+TrackLibrary.unique_id())
	canvas = Control.new()
	canvas.theme = MenuStyle.theme()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = MenuStyle.INK
	MenuStyle.fill(background)
	canvas.add_child(background)
	var client := FixtureClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client._access_token = "fictional-access"
	client.player = {"id":"fixture-player"}
	var board := preload("res://ui/cloud_leaderboard.gd").new()
	board.client = client
	board.version = "fixture-version"
	board.vehicle = "compact"
	canvas.add_child(board)
	board.popup_centered()
	board.next.pressed.emit()
	await capture("scores-cursor-1280x720")
	client.unavailable = true
	await board.load_page()
	await capture("scores-retry-1280x720")
	board.free()
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder
	root.add_child(cloud)
	var directory: String = cloud.outbox_path().get_base_dir().path_join("runs")
	for index: int in range(103):
		var ticket_id: String = "fixture-history-"+str(index)
		cloud._write(directory.path_join(ticket_id.sha256_text()+".job.json"),{"ticket":ticket_id,"key":"fictional-key","failure":"invalid_replay","publish":""})
	await cloud.show_uploads(canvas)
	for frame: int in range(3): await process_frame
	for child: Node in canvas.get_children():
		if child is AcceptDialog:
			for body: Node in child.get_children():
				if body is ScrollContainer: body.scroll_vertical = int(body.get_v_scroll_bar().max_value)
	await capture("uploads-history-page-1280x720")
	for child: Node in canvas.get_children():
		if child is AcceptDialog: child.free()
	var app := preload("res://tests/review_pass3_probes.gd").ReviewApp.new()
	root.add_child(app)
	app.root_ui = canvas
	app._confirm_delete_draft("fictional_draft","Fixture draft")
	await capture("delete-draft-1280x720")
	app.free()
	canvas.free(); cloud.free(); client.free()
	print("REVIEW_FOLLOWUPS_CAPTURE: %d screenshots, disposable fixtures" % checks)
	quit(0)

func capture(label: String) -> void:
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://../docs/evidence/code-review-repairs-2026-10-03")
	DirAccess.make_dir_recursive_absolute(directory)
	if root.get_texture().get_image().save_png(directory.path_join(label+".png")) != OK: quit(1); return
	checks += 1
