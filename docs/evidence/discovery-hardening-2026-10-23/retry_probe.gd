extends "res://tests/test_discovery_windows.gd"

func run() -> void:
	root.size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	var folder: String = "user://discovery-hardening-review"
	var client := CursorClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client._capabilities = {"discovery_paging_version":3}
	client.document = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/starter_circuit.json"))
	client.hash_value = JSON.stringify(client.document).sha256_text()
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	await cloud.query_discovery({"sort":"name"})
	var pages: Node = cloud.discovery_pages
	cloud._write(cloud.cache_root().path_join(client.hash_value+".json"),client.document)
	var library := TrackLibrary.new(folder.path_join("drafts"))
	var catalog := TrackCatalog.new(library)
	cloud.add_to_catalog(catalog)
	var entry: Dictionary = cloud.entry_from_metadata(client.metadata(0))
	if not await cloud.download(entry): quit(2); return
	var native_track: NativeTrack = cloud.compile_entry(entry)
	if native_track == null: quit(3); return
	catalog.remember_track(entry,native_track)
	var browser := TrackBrowser.new()
	browser.library = library
	browser.catalog = catalog
	browser.cloud = cloud
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.selected_track = native_track
	browser.state = {"sort":"name"}
	browser.size = root.get_visible_rect().size
	root.add_child(browser)
	for _frame: int in range(6): await process_frame
	browser._set_list_open(false)
	for _frame: int in range(6): await process_frame
	# Every attempted page now fails; ordinary browser change signals remain live.
	pages.changed.connect(func() -> void:
		if pages.loading: client.busy_once = true)
	var initial_count: int = client.requests.size()
	var high: int = int(pages.pages.keys().max())
	browser.gallery.scroll_horizontal = (high*20+10)*browser.tile_stride
	browser._render_tiles(true)
	for _frame: int in range(24): await process_frame
	var result: Dictionary = {"scope":"Native headless real TrackBrowser, fixture HTTP 503 responses", "frames":24,
		"failed_page_requests_without_user_retry":client.requests.size()-initial_count,
		"error":pages.error,"cached_pages":pages.pages.size(),"list_open":browser.list_open,
		"desired_index":pages.desired_index,"scroll":browser.gallery.scroll_horizontal}
	print("DISCOVERY_RETRY_REVIEW "+JSON.stringify(result))
	var output := FileAccess.open("res://../docs/evidence/discovery-hardening-2026-10-23/retry-result.json",FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(result,"\t")+"\n"); output.close()
	browser.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame
	quit(0)
