extends SceneTree
## Publication during snapshot pagination and actual Publish -> Free Race navigation.
## Fictional backend responses and all writes isolated inside build/.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var folder: String

class CatalogClient extends Client:
	signal release_read
	var head: Dictionary
	var tail: Dictionary
	var publication: Dictionary
	var published: bool = false
	var hold: bool = false
	var started: bool = false
	var requests: Array[String] = []
	var hold_search: bool = false
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if not path.begins_with("/tracks?"): return {"ok":false,"error":"offline fixture","data":{}}
		requests.append(path)
		var data: Dictionary
		if path.contains("cursor="): data = {"items":[tail],"next_cursor":null}
		elif published: data = {"items":[publication,head,tail],"next_cursor":null}
		else: data = {"items":[head],"next_cursor":"snapshot-before-publication"}
		started = true
		if hold:
			hold = false
			await release_read
		return {"ok":true,"data":data,"error":""}
	func request_public(path: String, _owner: int) -> Dictionary:
		if path.begins_with("/tracks?"):
			var data: Dictionary = {"items":[publication.duplicate(true)],"next_cursor":null}
			if hold_search: await release_read
			return {"ok":true,"data":data,"error":""}
		return {"ok":true,"data":{"items":[],"population":0,"next_cursor":null},"error":""}

class PublishedFlow extends TrackLifecycle:
	var receipt: Dictionary
	func request_publish(_document: Dictionary) -> bool:
		library.revision += 1
		return cloud.remember_publication(receipt)
	func status_for(_document: Dictionary) -> Dictionary:
		return {"state":"published","receipt":receipt}

class PublicationApp extends "res://core/app.gd":
	var browser: TrackBrowser
	var last_notice: String
	func _ready() -> void: pass
	func _notice(message: String) -> void: last_notice = message
	func _show_screen(next: String) -> void:
		screen = next
		browser = TrackBrowser.new()
		browser.library = library
		browser.records = records
		browser.catalog = TrackCatalog.new(library)
		browser.cloud = cloud
		browser.selected_track = selected_track
		browser.state = browser_state
		browser.size = get_viewport().get_visible_rect().size
		add_child(browser)

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func metadata(number: int, title: String, hash_value: String, points: Array) -> Dictionary:
	return {"track_id":"fixture-track-"+str(number),"version_id":"00000000-0000-4000-8000-"+str(number).pad_zeros(12),
		"name":title,"creator":"Fixture Author","creator_id":"fixture-owner","content_hash":hash_value,
		"points":points,"theme":"pine","rating_count":0,"rating_average":null,"published_at":number}

func make_cloud(label: String, hash_value: String, points: Array, baseline: bool = false) -> Node:
	var client := CatalogClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client.head = metadata(1,"Alpha",hash_value,points)
	client.tail = metadata(2,"Beta",hash_value,points)
	client.publication = metadata(50,"Star",hash_value,points)
	var script: Script = Cloud
	if baseline: script = load(ProjectSettings.globalize_path("res://../docs/evidence/published-track-2026-10-07/before/game/backend/cloud_tracks.gd"))
	var cloud: Node = script.new()
	cloud.client = client
	cloud.root_override = folder.path_join(label)
	root.add_child(cloud)
	cloud.load_cached()
	return cloud

func run() -> void:
	root.size = Vector2i(1280,720)
	create_timer(40).timeout.connect(func() -> void: push_error("Publication test deadline"); quit(1))
	folder = ProjectSettings.globalize_path("res://../build/publication-tests-"+str(Time.get_ticks_usec()))
	var document: Dictionary = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/starter_circuit.json"))
	document.name = "Star"
	var body: String = JSON.stringify(document)
	var hash_value: String = body.sha256_text()

	var old: Node = make_cloud("baseline",hash_value,document.points,true)
	await old.refresh(true)
	check(old.remember_publication(old.client.publication),"baseline acknowledges publication")
	old.client.published = true
	await old.refresh(true)
	check(not old.entries.any(func(item: Dictionary) -> bool: return item.name == "Star"),"task-start snapshot reproduces disappearance of Star")
	old.client.queue_free()
	old.queue_free()
	await process_frame

	var cloud: Node = make_cloud("paged",hash_value,document.points)
	await cloud.refresh(true)
	check(not cloud.next_cursor.is_empty(),"old catalog has an unfinished snapshot")
	check(cloud.remember_publication(cloud.client.publication),"publication indexed immediately")
	cloud.client.published = true
	await cloud.refresh() # Must bypass the ordinary one-minute refresh throttle.
	check(not cloud.client.requests[-1].contains("cursor="),"publication refresh starts a new snapshot immediately")
	check(cloud.entries.any(func(item: Dictionary) -> bool: return item.name == "Star"),"new publication survives completed pagination")
	cloud.load_cached()
	check(cloud.entries.size() == 3,"publication and public catalog survive restart")
	cloud.client.hold_search = true
	cloud.search({"search":"Star"})
	var revised: Dictionary = cloud.client.publication.duplicate(true)
	revised.version_id = "00000000-0000-4000-8000-000000000500"
	check(cloud.remember_publication(revised),"new immutable revision committed during search")
	cloud.client.release_read.emit()
	await process_frame
	var public_cards: Array = cloud.entries.filter(func(item: Dictionary) -> bool: return item.track_id == revised.track_id)
	check(public_cards.size() == 1 and public_cards[0].version_id == revised.version_id,"late search cannot replace newly published revision with old metadata")
	check(cloud._search_filters.is_empty() and not cloud._search_loading,"publication returns pagination to the unfiltered catalog")
	cloud.client.hold_search = false
	cloud.client.publication = revised

	var inflight: Node = make_cloud("inflight",hash_value,document.points)
	inflight.client.hold = true
	inflight.refresh(true)
	check(inflight.client.started and inflight.refreshing,"old catalog request is outstanding")
	check(inflight.remember_publication(inflight.client.publication),"publication committed while old request is outstanding")
	inflight.client.published = true
	inflight.client.release_read.emit()
	for _frame: int in range(5): await process_frame
	check(inflight.entries.size() == 3 and inflight.entries[0].name == "Star","late old response cannot overwrite publication; fresh snapshot loads automatically")
	check(inflight.client.requests.size() == 2 and not inflight.refreshing,"refresh recovers without duplicate request loop")
	# Fresh server removal still wins: a hidden/deleted card must not be pinned forever.
	inflight.client.publication = inflight.client.head
	await inflight.refresh(true)
	check(not inflight.entries.any(func(item: Dictionary) -> bool: return item.name == "Star"),"later complete server snapshot removes withdrawn publication")

	# Use the actual Publish handler with a committed backend receipt and real UI.
	var app := PublicationApp.new()
	app.library = TrackLibrary.new(folder.path_join("drafts"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	app.cloud = cloud
	app.online = preload("res://backend/account_controller.gd").new()
	app.online.client.free()
	app.online.client = cloud.client
	cloud.client.player = {"id":"fixture-owner"}
	cloud.client._access_token = "fictional-access-token"
	var flow := PublishedFlow.new()
	flow.cloud = cloud
	flow.library = app.library
	flow.receipt = cloud.client.publication
	app.lifecycle = flow
	root.add_child(flow)
	root.add_child(app)
	cloud._write(cloud.cache_root().path_join(hash_value+".json"),document)
	# Put Star beyond the initial twelve-card virtual window.
	cloud.entries.clear()
	for index: int in range(24): cloud.entries.append(metadata(100+index,"Circuit %02d" % index,hash_value,document.points))
	cloud.client.hold = true # Keep the catalog read pending while the visible card opens.
	app.browser_state = {"section":"favorites","feed":"rivals","search":"missing","theme":"desert","minimum_rating":4.5,"race_history":"raced","random_on_open":true}
	app.race_area_mode = "rivalry"
	check(app.library.save_wip(document) == OK,"save isolated draft before Publish")
	await app._publish_saved_draft("wip:"+str(document.id))
	for _frame: int in range(240):
		await process_frame
		if app.browser != null and not app.browser.loading and not app.browser.selecting and app.browser.selected_track.metadata.has("cloud_version"): break
	for _frame: int in range(4): await process_frame
	check(app.screen == "tracks" and app.race_area_mode == "free" and app.last_notice == "Track published.","Publish returns to Free Race with success acknowledgement")
	check(app.browser.matches.any(func(item: Dictionary) -> bool: return item.name == "Star"),"previous filters cannot hide just-published track")
	check(app.browser.selected_track.identity == "cloud_fixture-track-50" and not app.browser.race_button.disabled,"published immutable revision is selected and raceable")
	check(app.browser.matches.size() == 25 and app.browser.gallery.scroll_horizontal > 0,"publication opens beyond initial virtual window without waiting for refresh")
	var tile: Control = app.browser.grid.get_node_or_null("Track_cloud_fixture-track-50")
	check(tile != null and tile.get_global_rect().intersection(app.browser.gallery.get_global_rect()).size.x >= tile.size.x-1,"published card is fully visible beyond virtual carousel's initial window")
	check(not app.browser_state.has("focus_track"),"publication focus is consumed so later visits retain user's selection")
	cloud.client.release_read.emit()
	await process_frame
	app.online.free()
	app.queue_free()
	flow.queue_free()
	cloud.client.queue_free()
	cloud.queue_free()
	inflight.client.queue_free()
	inflight.queue_free()
	await process_frame
	await process_frame
	print("PUBLICATION_DISCOVERY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
