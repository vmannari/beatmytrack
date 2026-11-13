extends SceneTree
## A slower local lap must remain in its place on the final standings page.
var checks: int = 0
var failures: int = 0

class Service extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"owner","country_code":"FI"}
	var empty_cursor: bool = false
	func signed_in() -> bool: return true
	func base_url() -> String: return "http://daily-paging.invalid"
	func cancel_public_reads(_owner: int) -> void: pass
	func request_api(path: String, _method: int, _body: Dictionary, _key: String, _authenticated: bool) -> Dictionary:
		var items: Array[Dictionary] = []
		var last: bool = "cursor=last" in path
		for index: int in range(10,11) if last else range(10):
			items.append({"player_id":"driver%d" % index,"display_name":"Driver %d" % index,
				"rank":index+1,"time_ticks":1200+index*120,"gap_ticks":index*120})
		return {"ok":true,"status":200,"data":{"day":20764,"version_id":"paging-test","vehicle_id":"compact",
			"ends_at":20765*86400,"server_now":20764*86400+60,"tick_rate":120,"population":12,
			"items":items,"player":null,"next_cursor":("" if empty_cursor else null) if last else "last",
			"comparison":{"position":12,"population":12,"candidate_ticks":3600}}}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for _frame: int in range(8): await process_frame

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280,720)
	var service := Service.new()
	root.add_child(service)
	var dialog := preload("res://ui/daily_standings.gd").new()
	dialog.client = service
	dialog.day = 20764
	dialog.version = "paging-test"
	dialog.vehicle = "compact"
	dialog.ends_at = 20765*86400
	dialog.server_now = 20764*86400+60
	dialog.flying_laps = true
	dialog.best_seconds = 30.0
	root.add_child(dialog)
	dialog.popup_centered()
	await settle()
	check(dialog._rows.get_child_count() == 10,"slower comparison stays off the first page")
	check(dialog._own.find_child("DailyComparisonPosition",true,false) != null,"comparison position remains pinned")
	dialog._next.pressed.emit()
	await settle()
	check(dialog._page == 1 and dialog._next.disabled,"server cursor reaches the final page")
	check(dialog._rows.get_child_count() == 2,"final page includes the slower local comparison")
	check(dialog._rows.find_child("DailySelfRow",true,false) != null,"local driver is visible after all faster drivers")
	service.empty_cursor = true
	dialog.load_page()
	await settle()
	check(dialog._rows.get_child_count() == 2 and dialog._next.disabled,"empty terminal cursor also retains the slower local comparison")
	var output: String = OS.get_environment("BMT_DAILY_STANDINGS_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("last-page-local-result.png")) == OK,"capture the final page with the local result")
	dialog._previous.pressed.emit()
	await settle()
	check(dialog._rows.get_child_count() == 10,"returning to the first page does not duplicate the local comparison")
	dialog.queue_free()
	service.queue_free()
	await process_frame
	print("DAILY_COMPARISON_PAGING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
