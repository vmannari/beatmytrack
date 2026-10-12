extends SceneTree
## Opt-in analysis of current discovery behavior. Synthetic public metadata;
## no HTTP, credentials, production writes or full-track geometry compilation.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var observations: Dictionary = {}

class ScaleClient extends Client:
	var count: int = 5000
	var catalog_requests: int = 0
	var search_requests: int = 0
	var template: Dictionary
	func page(path: String) -> Dictionary:
		var offset: int = 0
		if path.contains("cursor="): offset = int(path.get_slice("cursor=",1).get_slice("&",0))
		var items: Array = []
		for position: int in range(offset,mini(count,offset+20)):
			var number: int = count-position
			var item: Dictionary = template.duplicate(true)
			item.track_id = "fixture-track-"+str(number)
			item.version_id = "00000000-0000-4000-8000-"+str(number).pad_zeros(12)
			item.name = "Circuit %04d" % number
			item.published_at = number
			items.append(item)
		return {"ok":true,"data":{"items":items,"next_cursor":str(offset+20) if offset+20 < count else null},"error":""}
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		catalog_requests += 1
		return page(path)
	func request_public(path: String, _owner: int) -> Dictionary:
		search_requests += 1
		return page(path)

class MemoryCloud extends Cloud:
	# Exercise production paging/caps without repeatedly rewriting large cache files.
	func _write(_path: String, _value: Dictionary) -> bool: return true

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func adapter(client: ScaleClient, suffix: String) -> Node:
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	var cloud := MemoryCloud.new()
	cloud.client = client
	cloud.root_override = ProjectSettings.globalize_path("res://../build/discovery-scale/"+suffix)
	root.add_child(cloud)
	cloud.load_cached()
	return cloud

func run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Scale analysis deadline"); quit(1))
	var points: Array = []
	for index: int in range(96): points.append([cos(index*TAU/96.0)*100.0,sin(index*TAU/96.0)*100.0])
	var template: Dictionary = {"track_id":"fixture","version_id":"00000000-0000-4000-8000-000000000001","name":"Circuit","creator":"Fixture Author","creator_id":"fixture-owner","content_hash":"a".repeat(64),"points":points,"theme":"pine","rating_count":0,"rating_average":null,"created_at":1,"published_at":1}
	var client := ScaleClient.new()
	client.template = template
	var cloud: Node = adapter(client,"catalog")
	var catalog := TrackCatalog.new(TrackLibrary.new(ProjectSettings.globalize_path("res://../build/discovery-scale/drafts")))
	var discovery := TrackDiscoveryProvider.new()
	await cloud.refresh(true)
	cloud.add_to_catalog(catalog,discovery)
	var first: Array[Dictionary] = discovery.query(catalog,{},[])
	check(first.size() == 20,"initial load has twenty preview records")
	observations.initial_alphabetical_first = first.front().name
	var original_first: String = str(first.front().id)
	await cloud.refresh(true)
	cloud.add_to_catalog(catalog,discovery)
	var second: Array[Dictionary] = discovery.query(catalog,{},[])
	observations.after_second_page_first = second.front().name
	observations.original_first_new_index = second.find_custom(func(item: Dictionary) -> bool: return item.id == original_first)
	check(int(observations.original_first_new_index) == 20,"appending older server records moves existing alphabetical cards twenty places")
	var started: int = Time.get_ticks_usec()
	while not cloud.next_cursor.is_empty():
		await cloud.refresh(true)
		if client.catalog_requests % 20 == 0: await process_frame
	observations.mock_catalog_pages = client.catalog_requests
	observations.final_cached_records = cloud.entries.size()
	observations.newest_published_still_cached = cloud.entries.any(func(item: Dictionary) -> bool: return item.track_id == "fixture-track-5000")
	observations.final_record_number_range = [int(str(cloud.entries.back().track_id).get_slice("fixture-track-",1)),int(str(cloud.entries.front().track_id).get_slice("fixture-track-",1))]
	observations.in_memory_paging_ms = (Time.get_ticks_usec()-started)/1000.0
	check(client.catalog_requests == 250 and cloud.entries.size() == 1000,"5000 publications produce 250 pages and a 1000-record cache")
	check(not observations.newest_published_still_cached and observations.final_record_number_range == [1,1000],"completed scan retains oldest thousand and drops newest four thousand")
	var search_client := ScaleClient.new()
	search_client.template = template
	var search_cloud: Node = adapter(search_client,"search")
	await search_cloud.search({"search":"Circuit"})
	search_cloud.load_more()
	await process_frame
	observations.search_matching_total = 5000
	observations.search_loaded_records = search_cloud.entries.size()
	observations.search_requests_after_load_more = search_client.search_requests
	observations.saved_search_cursor = search_cloud._search_cursor
	check(search_cloud.entries.size() == 20 and search_client.search_requests == 1,"server search continuation is not stored; load_more performs no second request")
	var random_pool: Array[Dictionary] = discovery.query(catalog,{},[])
	observations.random_loaded_candidates_before_resync = random_pool.size()
	cloud.add_to_catalog(catalog,discovery)
	observations.discovery_stat_records_after_resync = discovery.track_stats.size()
	print("DISCOVERY_SCALE_OBSERVATIONS: "+JSON.stringify(observations))
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/discovery-scale-2026-10-07")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("observations.json"),FileAccess.WRITE)
	check(file != null,"analysis output opens inside workspace")
	if file != null:
		file.store_string(JSON.stringify({"observations":observations,"checks":checks,"failures":failures},"\t"))
		file.close()
	cloud.queue_free()
	client.queue_free()
	search_cloud.queue_free()
	search_client.queue_free()
	await process_frame
	print("DISCOVERY_SCALE_ANALYSIS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
