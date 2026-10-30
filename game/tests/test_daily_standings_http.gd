extends SceneTree
## Production client over real loopback HTTP to the owned backend fixture.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	root.size = Vector2i(1280,720)
	var client := preload("res://backend/backend_client.gd").new()
	client._base_url = OS.get_environment("BMT_DAILY_HTTP_ORIGIN")
	client._access_token = OS.get_environment("BMT_DAILY_HTTP_TOKEN")
	client.player = {"id":OS.get_environment("BMT_DAILY_HTTP_PLAYER")}
	root.add_child(client)
	var dialog := preload("res://ui/daily_standings.gd").new()
	dialog.client = client
	dialog.version = OS.get_environment("BMT_DAILY_HTTP_VERSION")
	dialog.vehicle = "compact"
	dialog.track_name = "Owned HTTP daily fixture"
	dialog.day = int(OS.get_environment("BMT_DAILY_HTTP_DAY"))
	dialog.server_now = int(OS.get_environment("BMT_DAILY_HTTP_NOW"))
	dialog.ends_at = (dialog.day+1)*86400
	root.add_child(dialog)
	dialog.popup_centered()
	var began: int = Time.get_ticks_msec()
	while dialog.busy and Time.get_ticks_msec()-began < 15000: await process_frame
	for _frame: int in range(6): await process_frame
	check(not dialog.busy,"real HTTP read completes")
	check(dialog._rows.get_child_count() == 3,"real endpoint returns three independently accepted fixture results")
	check(dialog._own.find_child("DailySelfRow",true,false) != null,"authenticated real HTTP response identifies the player")
	check(dialog._population == 3,"public daily population is exact")
	dialog.queue_free()
	await process_frame
	client._access_token = ""
	client.player = {}
	client.queue_free()
	await process_frame
	print("DAILY_STANDINGS_HTTP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
