extends "res://tests/test_profile_redesign.gd"
## Isolate the production row builder; synthetic data, no IO/network/layout time.
func run() -> void:
	var host := ProfileHost.new()
	var fake_client := ProfileClient.new(); fake_client.signed = false
	var page: Control = load("res://ui/own_profile_page.gd").new()
	page.app = host
	page.client = fake_client
	page.records = LocalRecords.new("user://review-profile/records.json")
	page.track_grid = GridContainer.new()
	root.add_child(page.track_grid)
	page.track_action = Button.new()
	page.track_status = Label.new()
	page.track_mode = "drafts"
	var rows: Array = []
	for count: int in [12,100,500]:
		page.drafts.clear()
		for index: int in range(count):
			page.drafts.append({"id":"fixture-"+str(index),"document":{"name":"Draft "+str(index),"theme":"pine","points":[[0,0],[20,0],[20,20],[0,20]]}})
		var values: Array[float] = []
		for repeat: int in range(3):
			page._clear(page.track_grid)
			for frame: int in range(4): await process_frame
			var began: int = Time.get_ticks_usec()
			page._render_tracks()
			values.append((Time.get_ticks_usec()-began)/1000.0)
		check(page.track_grid.get_child_count()==count,"production builder creates every supplied row")
		values.sort()
		rows.append({"rows":count,"build_ms":values,"median_ms":values[1],"descendant_nodes":page.track_grid.find_children("*","",true,false).size()})
	page.track_grid.free(); page.track_action.free(); page.track_status.free()
	page.free(); fake_client.free(); host.free()
	for frame: int in range(12): await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"checks":checks,"failures":failures},"  "))
	print("REVIEW_PROFILE_ROWS ",JSON.stringify(rows))
	quit(1 if failures else 0)
