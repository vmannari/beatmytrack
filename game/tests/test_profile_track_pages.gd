extends "res://tests/test_profile_redesign.gd"
## Bounded controls, complete navigation and asynchronous publication fences.
class PagedClient extends ProfileClient:
	var total: int = 29
	var skip_first: int = 0
	func request_api(path: String, method: int, payload: Dictionary, key: String, auth: bool) -> Dictionary:
		if not path.begins_with("/me/tracks?"): return await super.request_api(path,method,payload,key,auth)
		requests.append(path)
		if delayed: await reply
		if fail_tracks: return {"ok":false}
		var offset: int = int(path.get_slice("offset=",1))
		var items: Array = [{"creator_id":"other","track_id":"other","name":"Other"},{"creator_id":"owner","track_id":"deleted","state":"deleted"}]
		for index: int in range(maxi(0,offset-1),mini(offset+12,total)):
			if index < skip_first: continue
			items.append({"creator_id":"owner","track_id":"published-"+str(index),"name":"Publication "+str(index),"theme":"pine","verified_races":index+1,"state":"published"})
		return {"ok":true,"data":{"items":items,"next_offset":offset+12 if offset+12 < total else null}}

func _draft(index: int) -> Dictionary:
	return {"id":"draft-"+str(index),"load_id":"load-"+str(index),"document":{"name":"Draft "+str(index),"theme":"pine","points":[[0,0],[20,0],[20,20],[0,20]]}}

func _descendants(node: Node) -> int:
	var total: int = 0
	for child: Node in node.get_children(): total += 1+_descendants(child)
	return total

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var host := ProfileHost.new()
	root.add_child(host)
	var client := PagedClient.new()
	client.signed = false
	client._capabilities = {}
	host.add_child(client)
	var account := Account.new()
	account.client = client
	host.online = account
	host.add_child(account)
	var awards := Awards.new()
	host.achievements = awards
	host.add_child(awards)
	host.records = LocalRecords.new("user://profile-track-pages/records.json")
	host.root_ui = host
	var page: Control = make_page(host)
	await settle()
	check(not page.track_pager.visible,"empty drafts need no pager")
	var measurements: Array[Dictionary] = []
	for count: int in [12,100,500]:
		page.drafts.clear()
		for index: int in range(count): page.drafts.append(_draft(index))
		var samples: Array[float] = []
		for sample: int in range(3):
			page._clear(page.track_grid)
			await settle()
			var started: int = Time.get_ticks_usec()
			page._render_tracks()
			samples.append((Time.get_ticks_usec()-started)/1000.0)
		samples.sort()
		check(page.track_grid.get_child_count() == 12,"only twelve draft rows built for "+str(count))
		check(_descendants(page.track_grid) == 156,"control count stays fixed for "+str(count))
		check(page.track_pager.visible == (count > 12),"pager only appears when needed")
		measurements.append({"count":count,"median_ms":samples[1],"samples_ms":samples,"descendant_nodes":_descendants(page.track_grid)})
	await settle()
	check(page.track_previous.disabled and not page.track_next.disabled,"first page navigation bounds")
	check(page.track_grid.get_child(0).name == "ProfileTrack_draft-0","first creation stays first")
	var first_row: Button = page.track_grid.get_child(0)
	page._select_tracks("drafts")
	check(page.track_grid.get_child(0) == first_row,"selected tab does not rebuild rows")
	await capture("profile-draft-first-page")
	page.scroll.ensure_control_visible(page.track_pager)
	await settle()
	await capture("profile-draft-navigation")
	await tap(page.track_next)
	check(page.track_pages.drafts == 1,"pointer input reaches next draft page")
	await tap(page.track_previous)
	check(page.track_pages.drafts == 0,"pointer input reaches previous draft page")
	var seen: Dictionary = {}
	for number: int in range(42):
		check(page.track_grid.get_child_count() == mini(12,500-number*12),"every draft page has the exact remaining rows")
		for row: Button in page.track_grid.get_children():
			check(not seen.has(row.name),"draft is shown on exactly one page")
			seen[row.name] = true
		page.track_grid.get_child(0).pressed.emit()
		check(host.action == "draft:load-"+str(number*12),"draft row preserves exact load id")
		if number < 41: page.track_next.pressed.emit()
		await process_frame
	check(seen.size() == 500,"all 500 drafts remain reachable")
	check(page.track_next.disabled and not page.track_previous.disabled,"last page navigation bounds")
	check(page.track_page_status.text == "42 / 42","last partial page count")
	await settle()
	await capture("profile-draft-last-page")
	page._change_track_page(1)
	check(page.track_pages.drafts == 41,"cannot navigate past last draft")
	page._select_tracks("published")
	page._select_tracks("drafts")
	check(page.track_pages.drafts == 41,"tabs retain independent page positions")
	page.drafts = page.drafts.slice(0,2)
	page._render_tracks()
	check(page.track_pages.drafts == 0 and page.track_grid.get_child_count() == 2 and not page.track_pager.visible,"smaller refreshed draft list clamps safely")

	client.signed = true
	page.scope = page._scope()
	page._select_tracks("published")
	await page._load_tracks()
	check(page.published.size() == 12 and page.track_grid.get_child_count() == 12,"initial published page filters foreign and deleted tracks")
	check(page.track_pages.published == 0 and page.next_offset == 12,"initial publication page remains first")
	check(page.track_action.visible and not page.track_pager.visible,"More tracks remains available after first server page")
	await page._load_tracks()
	check(page.published.size() == 24 and page.track_grid.get_child_count() == 12,"published history remains bounded and deduplicated")
	check(page.track_pages.published == 1 and page.track_grid.get_child(0).name == "ProfileTrack_published-12","More tracks reveals newly loaded page")
	check(page.track_grid.get_child(0).find_child("TrackRaceCount",true,false).text == "13","verified finish count survives pagination")
	page.track_grid.get_child(0).pressed.emit()
	check(host.action == "published-12","published row opens exact entry")
	var requests: int = client.requests.size()
	page.track_previous.pressed.emit()
	check(not page.track_action.visible,"load-more action belongs to last cached page")
	page.track_next.pressed.emit()
	check(client.requests.size() == requests,"cached page navigation performs no requests")
	client.delayed = true
	first_row = page.track_grid.get_child(0)
	page._load_tracks()
	check(page.track_busy and page.track_action.disabled,"pending server page cannot be requested twice")
	check(page.track_grid.get_child(0) == first_row,"request status preserves visible row controls")
	page._load_tracks()
	check(client.requests.size() == requests+1,"duplicate pending request suppressed")
	page.track_previous.pressed.emit()
	client.reply.emit()
	await settle()
	check(page.published.size() == 29 and page.track_pages.published == 0,"pending reply preserves a newer back navigation")
	check(page.next_offset == -1,"server pagination terminates exactly")
	page._change_track_page(2)
	check(page.track_grid.get_child_count() == 5 and page.track_next.disabled and not page.track_action.visible,"final partial publication page has no fetch action")
	check(page.track_grid.get_child(4).name == "ProfileTrack_published-28","last publication reachable")
	await capture("profile-published-last-page")
	requests = client.requests.size()
	await page._load_tracks()
	check(client.requests.size() == requests,"exhausted source does not fetch offset minus one")

	client.delayed = false
	client.skip_first = 7
	page.published.clear()
	page.next_offset = 0
	await page._load_tracks()
	check(page.published.size() == 5,"filtered server response can leave a partial page")
	await page._load_tracks()
	check(page.published.size() == 17 and page.track_pages.published == 0,"new rows fill a partial page without skipping them")
	check(page.track_grid.get_child(5).name == "ProfileTrack_published-12","first new row is on the selected page after filtering")
	page.track_next.pressed.emit()
	check(page.track_grid.get_child_count() == 5 and page.track_grid.get_child(4).name == "ProfileTrack_published-23","filtered remaining rows stay reachable")
	client.skip_first = 0
	client.fail_tracks = true
	page.published.clear()
	page.next_offset = 0
	await page._load_tracks()
	check(page.track_action.visible and page.track_action.text == "Retry","failed page retains retry")
	client.fail_tracks = false
	await page._load_tracks()
	check(page.published.size() == 12 and page.track_pages.published == 0,"retry recovers the same server page")
	client.delayed = true
	page._load_tracks()
	client.player.id = "different"
	client.identity_changed.emit()
	client.reply.emit()
	await settle()
	check(not page.visible and page.published.size() == 12,"late page cannot cross account epoch")
	page.queue_free()
	host.queue_free()
	await settle()
	var destination: String = OS.get_environment("BMT_LOADING_OUTPUT")
	if not destination.is_empty():
		var file := FileAccess.open(destination,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":measurements},"\t")+"\n")
	print("Profile track pages: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
