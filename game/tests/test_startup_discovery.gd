extends "res://tests/test_discovery_pages.gd"
## Startup cards remain visible while independent, scoped refreshes are held.

func run() -> void:
	root.size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	folder = "user://startup_discovery_"+TrackLibrary.unique_id()
	var client := PagedClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client._capabilities = {"discovery_paging_version":2}
	client.document = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/starter_circuit.json"))
	client.hash_value = JSON.stringify(client.document).sha256_text()
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	cloud.load_cached()
	var app: Node = load("res://core/app.gd").new()
	app.cloud = cloud
	app.records = LocalRecords.new(folder.path_join("records.json"))
	client.hold_once = true
	app._prefetch_discovery()
	check(cloud.discovery_pages.loading and cloud.discovery_pages.total == -1,"cold startup remains unresolved while first page is held")
	var browser := TrackBrowser.new()
	browser.library = TrackLibrary.new(folder.path_join("drafts"))
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.catalog = TrackCatalog.new(browser.library)
	browser.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	browser.cloud = cloud
	browser.state = {}
	root.add_child(browser)
	MenuStyle.fill(browser)
	await process_frame
	await process_frame
	check(client.requests.size() == 1,"startup preload and opening Free Race share one pending request")
	app._prefetch_discovery()
	check(client.requests.size() == 1,"account/startup notifications coalesce discovery before menu activation")
	check(not _text(browser).contains("No tracks found"),"first unresolved frame never claims no tracks exist")
	check(_text(browser).contains("Loading tracks"),"uncached discovery uses the existing loading area")
	await _capture("cold-start-loading")
	client.release_read.emit()
	await settle(cloud.discovery_pages)
	check(browser.grid.get_child_count() > 0 and browser.grid.get_child(0) is TrackTile,"response replaces the loading control with real track cards")
	check(not _text(browser).contains("Loading tracks") and not _text(browser).contains("No tracks found"),"no stale empty-state control survives the page response")
	var first: Dictionary = cloud.discovery_pages.entry_at(0).duplicate(true)
	browser.queue_free()
	app.free()
	cloud.queue_free()
	await process_frame
	# Fresh adapter/app process: cached page is usable before the first reply.
	var reopened := Cloud.new()
	reopened.client = client
	reopened.root_override = folder.path_join("cloud")
	root.add_child(reopened)
	reopened.load_cached()
	client.hold_once = true
	var before: int = client.requests.size()
	reopened.query_discovery({})
	check(reopened.discovery_pages.total == 5000 and reopened.discovery_pages.loading,"restart restores the original total while fetching a fresh page")
	check(JSON.stringify(reopened.discovery_pages.entry_at(0)) == JSON.stringify(JSON.parse_string(JSON.stringify(first))),"restart exposes every cached metadata value immediately after its JSON round trip")
	check(not client.requests[-1].has("cursor"),"restart never reuses the cached server cursor")
	reopened.query_discovery({})
	check(client.requests.size() == before+1,"duplicate startup requests are coalesced even with cached cards")
	var warm := TrackBrowser.new()
	warm.library = browser.library if is_instance_valid(browser) else TrackLibrary.new(folder.path_join("drafts"))
	warm.records = LocalRecords.new(folder.path_join("records.json"))
	warm.catalog = TrackCatalog.new(warm.library)
	warm.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	warm.cloud = reopened
	warm.state = {}
	root.add_child(warm)
	MenuStyle.fill(warm)
	await process_frame
	await process_frame
	check(warm.grid.get_child(0) is TrackTile,"first reopened menu frames have their cached cards")
	check(not _text(warm).contains("No tracks found") and not _text(warm).contains("Loading tracks"),"warm cards need no loading or false-empty caption")
	await _capture("warm-start-cards")
	client.release_read.emit()
	await settle(reopened.discovery_pages)
	client.hold_once = true
	reopened.query_discovery({"search":"does-not-exist"})
	await process_frame
	check(not _text(warm).contains("No tracks found"),"new filtered query cannot claim emptiness before its response")
	check(reopened.entries.is_empty(),"cached default cards never appear in a different filtered query")
	client.release_read.emit()
	await settle(reopened.discovery_pages)
	check(reopened.discovery_pages.total == 0,"server-confirmed empty query is retained as empty")
	# Match the UI's applied query and expose its confirmed empty state.
	warm.state = {"search":"does-not-exist"}
	warm._refresh()
	check(_text(warm).contains("No tracks found"),"only the completed empty query shows No tracks found")
	await _capture("confirmed-empty-search")
	client.player = {"id":"another-account"}
	client.hold_once = true
	reopened.query_discovery({})
	check(reopened.discovery_pages.total == -1 and reopened.discovery_pages.pages.is_empty(),"another account cannot hydrate the previous scoped page")
	client.release_read.emit()
	await settle(reopened.discovery_pages)
	warm.queue_free()
	reopened.queue_free()
	client.queue_free()
	await process_frame
	print("STARTUP_DISCOVERY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _text(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree(): return ""
	var result: String = node.text if node is Label else ""
	for child: Node in node.get_children(): result += "\n"+_text(child)
	return result

func _capture(label: String) -> void:
	var destination: String = OS.get_environment("BMT_STARTUP_EVIDENCE")
	if destination.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(destination)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(destination.path_join(label+".png")) == OK,"capture "+label)
