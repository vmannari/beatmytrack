extends "res://tests/test_publishing_slots.gd"
## Saved publication journals drive the actual Load track tiles and details.

func run() -> void:
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/publication-wait-status-2026-10-18/"+RenderingServer.get_current_rendering_method())
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	var client := SlotClient.new(); root.add_child(client)
	client.configure("http://127.0.0.1:1"); client.player = {"id":"badge-owner"}; client._access_token = "isolated-fixture"; client.slots = 1
	var cloud := Cloud.new(); cloud.client = client; root.add_child(cloud)
	var flow := TrackLifecycle.new(); flow.cloud = cloud
	var folder: String = ProjectSettings.globalize_path("res://../build/publication-badges/"+str(Time.get_ticks_usec()))
	flow.library = TrackLibrary.new(folder.path_join("tracks")); flow.records = LocalRecords.new(folder.path_join("records.json")); root.add_child(flow)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	doc.name = "Winter loop"; doc.theme = "winter"; doc.creator = "Driver"
	check(flow.library.save_document(doc) == OK,"saved draft fixture")
	var staged: Dictionary = flow.stage(doc,[],"compact",null,"",{"schema":"bmt-race-proof-v1","samples":[[0,0,0,0,0,0,0,0],[120,1,0,0,0,0,0,0]]})
	check(not staged.is_empty(),"real local journal and recording")
	var host := MarginContainer.new(); root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: host.add_theme_constant_override("margin_"+side,24)
	var browser := preload("res://ui/draft_browser.gd").new(); browser.library = flow.library; browser.lifecycle = flow; host.add_child(browser)
	await wait_browser(browser)
	var labels: Dictionary = {"local_ready":"TESTED","publishing":"PUBLISHING","queued":"QUEUED","verifying":"CHECKING","failed":"FAILED","finishing":"PUBLISHED"}
	for state: String in labels:
		var job: Dictionary = flow.status_for(doc)
		job.state = state; job.publish_requested = state != "local_ready"
		check(flow._save(staged.path,job),"persist "+state+" journal")
		flow.changed.emit(); await wait_browser(browser)
		var card: TrackTile = browser.gallery.get_child(0).get_child(0)
		check(card.draft_badge_text() == labels[state],"actual gallery badge follows "+state+" journal")
		check(browser.selection.lifecycle.state == state,"scan retains exact "+state+" presentation state")
		if state == "queued":
			check(not card.entry.tested and card.draft_badge_text() != "DRAFT","in-progress upload does not become Draft when ready is false")
			check(browser.find_child("PublishDraft",true,false).disabled,"queued publication cannot submit again")
			var retained: Node = browser.gallery.get_child(0)
			flow._retry_deadlines[str(job.upload_key)] = 0
			await flow.process_jobs(); await settle()
			check(browser.gallery.get_child(0) == retained and not browser.scanning,"identical queued poll retains existing cards")
			await capture("queued-1280x720")
		if state == "verifying": await capture("checking-1280x720")
	# Older journals can retain a progress state alongside a terminal failure.
	var failed_job: Dictionary = flow.status_for(doc)
	failed_job.state = "verifying"
	failed_job.failure = "Publication verification failed"
	check(flow._save(staged.path,failed_job),"persist historical failure with checking state")
	flow.changed.emit(); await wait_browser(browser)
	check(browser.gallery.get_child(0).get_child(0).draft_badge_text() == "FAILED","terminal failure overrides an old checking badge")
	# A server failure arriving while the browser is open must refresh the badge.
	failed_job.erase("failure")
	failed_job.publication_id = "slot-intent"
	failed_job.state = "verifying"
	failed_job.publish_workflow = 2
	check(flow._save(staged.path,failed_job),"persist active verification")
	flow.changed.emit(); await wait_browser(browser)
	client.remote = {"publication_id":"slot-intent","state":"failed","retryable":true,"detail":"Verification failed"}
	flow._retry_deadlines[str(failed_job.upload_key)] = 0
	await flow.process_jobs(); await wait_browser(browser)
	check(browser.gallery.get_child(0).get_child(0).draft_badge_text() == "FAILED","server failure refreshes checking badge")
	check(browser.find_child("RetryPublication",true,false) != null,"retryable server failure offers retry")
	failed_job = flow.status_for(doc)
	failed_job.erase("failure")
	failed_job.erase("publication_id")
	failed_job.state = "verifying"
	failed_job.proof_file = "missing-proof.json"
	check(flow._save(staged.path,failed_job,true),"persist incomplete local evidence")
	flow._retry_deadlines[str(failed_job.upload_key)] = 0
	await flow.process_jobs(); await wait_browser(browser)
	check(flow.status_for(doc).state == "failed","incomplete local evidence saves terminal failure state")
	check(browser.gallery.get_child(0).get_child(0).draft_badge_text() == "FAILED","local failure refreshes checking badge")
	var fallback := TrackTile.new(); fallback.entry = {"tested":false}
	check(fallback.draft_badge_text() == "DRAFT","untested unpublished track keeps Draft")
	fallback.entry.tested = true
	check(fallback.draft_badge_text() == "TESTED","tested unpublished track keeps Tested")
	fallback.free()
	host.free(); flow.free(); cloud.free(); client.free()
	print("PUBLICATION_BADGES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
