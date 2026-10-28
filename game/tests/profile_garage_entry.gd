extends SceneTree
## Isolated cold construction attribution; no owner data or network.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	var began: int = Time.get_ticks_usec()
	var car := CarVisual.new()
	car.editable_kits = true
	world.add_child(car)
	print("PROFILE_CAR_MS ", (Time.get_ticks_usec()-began)/1000.0)
	began = Time.get_ticks_usec()
	GarageEnvironment.build(world,car,false)
	print("PROFILE_ROOM_MS ", (Time.get_ticks_usec()-began)/1000.0)
	world.free()
	began = Time.get_ticks_usec()
	var page := GaragePage.new()
	page.records = LocalRecords.new("user://garage-entry-profile-"+TrackLibrary.unique_id()+"/records.json")
	page.cached_carousel = true
	page.size = Vector2(1180,570)
	root.add_child(page)
	print("PROFILE_PAGE_MS ",(Time.get_ticks_usec()-began)/1000.0)
	for _frame: int in range(8): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../docs/evidence/garage-entry-carousel-2026-10-26/before.png")
	print("PROFILE_TOTAL_WITH_DRAW_MS ",(Time.get_ticks_usec()-began)/1000.0)
	page.free()
	quit()
