extends SceneTree
const Links = preload("res://platform/track_links.gd")
const Base = preload("res://tests/test_publication_notifications.gd")
const Menu = preload("res://ui/garage_news_menu.gd")
const VERSION: String = "11111111-2222-4333-8444-555555555555"
var app: Node
var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/publication-news-share-2026-10-18/headless"

class LinkClient extends Base.PublishingClient:
	signal release_metadata
	var calls: Array[String] = []
	var hold_metadata: bool = false
	var waiting: bool = false
	var remote_items: Array = []
	var creator_queries: Array[Dictionary] = []
	func request_discovery(body: Dictionary, _owner: int, _random_choice: bool = false) -> Dictionary:
		creator_queries.append(body.duplicate(true))
		var second: Dictionary = receipt.duplicate(true)
		second.track_id = "fixture-second"
		second.version_id = "11111111-2222-4333-8444-666666666666"
		second.theme = "winter"
		second.name = "Snow Circuit"
		var other: Dictionary = receipt.duplicate(true)
		other.track_id = "fixture-other"
		other.version_id = "11111111-2222-4333-8444-777777777777"
		other.creator = "Another Driver"
		other.creator_id = "fixture-other-owner"
		other.name = str(receipt.creator)+" Circuit"
		var items: Array = [receipt.duplicate(true),second,other]
		items = items.filter(func(item: Dictionary) -> bool: return str(item.creator if int(body.get("search_kind",0)) == 2 else item.name).contains(str(body.get("search",""))))
		for index: int in range(items.size()): items[index].discovery_index = index
		await get_tree().process_frame
		return {"ok":true,"data":{"items":items,"total":items.size(),"offset":0,"snapshot":"11111111-2222-4333-8444-888888888888","page_cursor":"creator-fixture","next_cursor":null}}
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", authenticated: bool = false) -> Dictionary:
		calls.append(path)
		if path == "/track-versions/"+str(receipt.get("version_id","")):
			waiting = true
			if hold_metadata: await release_metadata
			waiting = false
			return {"ok":true,"data":receipt.duplicate(true)}
		if path == "/news" or path.begins_with("/news?cursor="): return {"ok":true,"data":{"items":remote_items,"tracks":{},"next_cursor":"","refreshing":false,"checked_day":server_now()/86400}}
		return await super.request_api(path,method,body,key,authenticated)

class ShareBridge extends "res://platform/challenge_links.gd":
	var text: String = ""
	var sends: int = 0
	func share_track(value: String) -> bool:
		text = value
		sends += 1
		return true

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func settle(count: int = 6) -> void:
	for frame: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func touch(button: Button) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func wait_detail() -> TrackBrowser:
	var browser: TrackBrowser
	for tick: int in range(180):
		await process_frame
		browser = app.root_ui.find_child("TrackBrowser",true,false)
		if browser != null and not browser.list_open and browser.selected_track.metadata.get("cloud_version","") == VERSION: break
	while browser != null and browser._view_motion != null: await process_frame
	while app.menu_page_motion != null: await process_frame
	await settle()
	return browser

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	create_timer(150).timeout.connect(func() -> void: print("FAIL: publication share deadline"); quit(1))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	for link: String in ["beatmytrack://track/"+VERSION,"https://fixture.invalid/t/"+VERSION,"https://fixture.invalid/v1/track-versions/"+VERSION,"http://127.0.0.1:8080/t/"+VERSION+"?from=share"]:
		check(Links.version_from(link) == VERSION,"shared/custom/legacy link resolves exact version: "+link)
	for link: String in ["beatmytrack://challenge/AB12CD34EF56AB78","beatmytrack://track/no-version","https://fixture.invalid/t/"+VERSION+"/document","https://user@fixture.invalid/t/"+VERSION,"https://fixture.invalid/t/"+VERSION+"\n", "javascript://track/"+VERSION]:
		check(Links.version_from(link).is_empty(),"malformed or unrelated link is rejected")
	check(Links.share_url({"version_id":VERSION,"share_url":"https://public.invalid/v1/track-versions/"+VERSION},"https://fixture.invalid") == "https://public.invalid/t/"+VERSION,"old API share URLs become browser/native track links")
	var previous_host: String = OS.get_environment("BMT_CHALLENGE_LINK_HOST")
	OS.set_environment("BMT_CHALLENGE_LINK_HOST","fixture.invalid")
	var manifest: String = preload("res://addons/bmt_challenges/export_plugin.gd").ChallengeExport.activity_filters()
	check(manifest.contains('android:host="track"') and manifest.contains('android:pathPrefix="/t/"') and manifest.contains('android:pathPrefix="/v1/track-versions/"'),"Android export handles custom, web and legacy track links")
	check(manifest.contains('android:host="challenge"') and manifest.contains('android:pathPrefix="/c/"'),"existing challenge intent filters remain")
	OS.set_environment("BMT_CHALLENGE_LINK_HOST",previous_host)
	root.size = Vector2i(1280,720)
	var folder: String = "user://publication_share_"+TrackLibrary.unique_id()
	app = Base.NotificationApp.new()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var client := LinkClient.new()
	client.configure("https://fixture.invalid")
	root.add_child(client)
	client.player = {"id":"fixture-owner"}
	client._access_token = "isolated-fixture"
	client._capabilities = {"garage_news_version":1}
	var cloud := Base.HeldCloud.new()
	cloud.client = client
	cloud.hold = false
	cloud.root_override = folder.path_join("shared-cloud")
	root.add_child(cloud)
	app.online.client = client
	app.cloud = cloud
	app.lifecycle.changed.disconnect(app._lifecycle_changed)
	var flow := TrackLifecycle.new()
	flow.library = app.library
	flow.records = app.records
	flow.cloud = cloud
	app.add_child(flow)
	app.lifecycle = flow
	flow.changed.connect(app._lifecycle_changed)
	var bridge := ShareBridge.new()
	app.add_child(bridge)
	app.challenge_links = bridge
	var routed: Dictionary = {"track":0,"challenge":0}
	bridge.track_received.connect(func(_value: String) -> void: routed.track += 1)
	bridge.invitation_received.connect(func(_value: String) -> void: routed.challenge += 1)
	bridge._received("beatmytrack://track/"+VERSION)
	bridge._received("beatmytrack://challenge/AB12CD34EF56AB78")
	check(routed.track == 1 and routed.challenge == 1,"platform routes track and challenge links separately")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	document.name = "Mountain Run"
	var receipt: Dictionary = {"track_id":"fixture-track","version_id":VERSION,"name":document.name,"creator":"Fixture Author","creator_id":"fixture-owner","content_hash":JSON.stringify(document).sha256_text(),"points":document.points,"theme":"grass","state":"published","published_at":int(Time.get_unix_time_from_system()),"rating_count":0,"rating_average":null,"share_url":"https://fixture.invalid/t/"+VERSION}
	receipt = JSON.parse_string(JSON.stringify(receipt))
	client.receipt = receipt
	var staged: Dictionary = flow.stage(document)
	var job: Dictionary = staged.job
	job.state = "finishing"
	job.receipt = receipt
	job.publication_notification = true
	job.publication_name = document.name
	check(flow._save(staged.path,job),"accepted receipt is saved before local finalization")
	var calls_before: int = client.calls.size()
	app._lifecycle_changed()
	check(client.news.items.size() == 1 and client.news.items[0].kind == "track_published","accepted publication immediately becomes an owner headline")
	check(client.calls.size() == calls_before,"publication headline adds no request or background News job")
	app._show_screen("drafts")
	await settle()
	var unread: int = flow.publication_notifications().size()
	var before_share: int = bridge.sends
	await touch(app.publication_notification.share_button)
	check(bridge.sends == before_share+1 and bridge.text.ends_with("/t/"+VERSION),"real banner share touch sends the confirmed track link")
	check(flow.publication_notifications().size() == unread,"sharing does not dismiss the unread acceptance")
	await capture("publication-banner-share")
	check(flow.acknowledge_publication(VERSION,flow.scope()),"publication banner can be dismissed independently")
	check(client.news.items.size() == 1,"banner dismissal retains the newspaper story")
	client.news._fetched_at = Time.get_ticks_msec()
	app._show_screen("garage")
	var garage: GaragePage = app._retained_garage
	garage.news_client = client.news
	garage._show_section("news")
	while garage._menu_motion != null: await process_frame
	await settle(18)
	var menu: Control = garage.find_child("GarageNewsMenu",true,false)
	var share: Button = menu.find_child("GarageNewsShare",true,false)
	check(share != null and share.size.y >= 52,"publication article has an accessible share icon")
	share.pressed.emit()
	check(bridge.text.ends_with("https://fixture.invalid/t/"+VERSION),"newspaper share sends a track link")
	await capture("publication-news")
	client.remote_items = []
	await client.news.refresh(true)
	check(client.news.items.size() == 1,"older server feed cannot erase the locally confirmed publication headline")
	client.remote_items = [{"id":"server-story","kind":"track_published","version_id":VERSION,"created_at":receipt.published_at,"track_name":document.name}]
	client.news.next_cursor = "page-two"
	await client.news.more()
	check(client.news.items.size() == 1 and client.news.items[0].id == "server-story","later feed pages deduplicate the local publication by immutable version")
	await client.news.refresh(true)
	check(client.news.items.size() == 1 and client.news.items[0].id == "server-story","server-confirmed headline replaces rather than duplicates the local story")
	app.browser_state = {"section":"favorites","theme":"desert","search":"missing"}
	await app._receive_track_link("https://untrusted.invalid/t/"+VERSION)
	var browser: TrackBrowser = await wait_detail()
	check(app.screen == "tracks" and app.race_area_mode == "free" and not browser.list_open,"share link opens Free Race detail directly")
	check(browser.selected_track.metadata.get("cloud_version","") == VERSION and app.game == null,"link selects the exact version and never starts a race")
	check(not client.calls.any(func(path: String) -> bool: return path.contains("untrusted.invalid")),"incoming link cannot redirect API traffic to its host")
	share = browser.find_child("ShareTrackLink",true,false)
	check(share != null and root.get_visible_rect().encloses(share.get_global_rect()),"Free Race detail retains a visible share icon")
	share.pressed.emit()
	check(bridge.text.ends_with("/t/"+VERSION),"Free Race detail can share the selected version again")
	await capture("shared-free-race-detail")
	var creator: Button = browser.hero.find_child("HeroCreatorLink",true,false)
	check(creator != null and creator.get_theme_color("font_color") == MenuStyle.ACCENT and creator.size.y >= 48,"creator name is a colored link with a full touch target")
	client._capabilities.discovery_paging_version = 2
	browser.state.merge({"section":"favorites","theme":"desert","minimum_rating":5.0,"search":"missing","name":"stale","creator":"stale","race_history":"raced","pinned_version":VERSION},true)
	var favorites: Array = app.records.settings.get("favorites",[]).duplicate()
	await touch(creator)
	while browser._view_motion != null or cloud.discovery_pages.loading: await process_frame
	await settle()
	check(browser.list_open and browser.state.search == receipt.creator and browser.state.search_kind == 2,"creator link opens the track list with creator-only search")
	check(browser.state.theme == "all" and browser.state.section == "all" and browser.state.minimum_rating == 0.0 and browser.state.race_history == "any" and not browser.state.has("pinned_version") and not browser.state.has("name") and not browser.state.has("creator"),"unrelated filters and pinned selection cannot hide creator tracks")
	check(client.creator_queries.size() == 1 and client.creator_queries[0].search_kind == 2 and client.creator_queries[0].search == receipt.creator,"creator link issues one bounded server creator search")
	check(browser.matches.size() == 2 and browser.matches.all(func(entry: Dictionary) -> bool: return entry.creator == receipt.creator),"creator results span biomes and exclude tracks matching only by title")
	check(app.records.settings.get("favorites",[]) == favorites and app.game == null,"creator navigation preserves favorites and does not start a race")
	await capture("creator-track-results")
	client._capabilities.erase("discovery_paging_version")
	await app._receive_track_link("beatmytrack://track/"+VERSION)
	browser = await wait_detail()
	var revised: Dictionary = receipt.duplicate(true)
	revised.version_id = "11111111-2222-4333-8444-999999999999"
	cloud.entries.clear()
	cloud.entries.append(revised)
	cloud.changed.emit()
	await settle()
	check(browser.selected_track.metadata.get("cloud_version","") == VERSION,"later catalogue revision cannot replace the version explicitly opened from a link")
	cloud.remember_publication(receipt)
	# Delivery during loading/startup waits for the real app readiness gate.
	app.startup_complete = false
	app._receive_track_link("beatmytrack://track/"+VERSION)
	await settle()
	check(app._queued_track_link != "","cold-start link waits until app startup completes")
	app.startup_complete = true
	await wait_detail()
	var race := Node.new()
	app.add_child(race)
	app.game = race
	app._receive_track_link("beatmytrack://track/"+VERSION)
	await settle()
	check(app.game == race and app._queued_track_link != "","link arriving during racing is queued without leaving the race")
	app.game = null
	race.queue_free()
	app._leave_race()
	await wait_detail()
	check(app._queued_track_link.is_empty() and app.screen == "tracks","queued link opens after leaving the race")
	client.hold_metadata = true
	app._receive_track_link("beatmytrack://track/"+VERSION)
	while not client.waiting: await process_frame
	app._show_screen("garage")
	client.release_metadata.emit()
	await settle()
	check(app.screen == "garage","late link response cannot override newer navigation")
	client.hold_metadata = false
	client.hold_metadata = true
	app._receive_track_link("beatmytrack://track/"+VERSION+"?first")
	while not client.waiting: await process_frame
	var newer_race := Node.new()
	app.add_child(newer_race)
	app.game = newer_race
	var newest: String = "beatmytrack://track/"+VERSION+"?latest"
	app._receive_track_link(newest)
	client.release_metadata.emit()
	await settle()
	check(app._queued_track_link == newest,"older in-flight reply cannot replace a newer link queued during a race")
	client.hold_metadata = false
	app.game = null
	newer_race.queue_free()
	app._leave_race()
	await wait_detail()
	client.player = {"id":"another-owner"}
	client.news.identity_changed()
	app._remember_publication_news()
	check(client.news.items.is_empty(),"owner headlines cannot leak to another account")
	client.player = {"id":"fixture-owner"}
	client.news.identity_changed()
	app._remember_publication_news()
	check(client.news.items.size() == 1,"durable workflow receipt restores the owner's headline after an identity reset")
	app.queue_free()
	client.queue_free()
	cloud.queue_free()
	await process_frame
	print("PUBLICATION_SHARE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
