extends SceneTree
## Isolated visual evidence; no account, network or player records.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(960,280)
	root.content_scale_size = Vector2i(960,280)
	var panel := HBoxContainer.new()
	panel.position = Vector2(12,12)
	panel.size = Vector2(936,240)
	panel.theme = MenuStyle.theme()
	root.add_child(panel)
	for index: int in range(3):
		var tile := TrackTile.new()
		tile.entry = {"name":"Track", "creator":"Beat my track", "theme":"pine", "points":[[0,0],[100,0],[100,100],[0,100]]}
		tile.favorite = index == 1
		panel.add_child(tile)
	await process_frame
	await process_frame
	(panel.get_child(2).get_node("ToggleFavorite") as Button).grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/carousel-favorite-2026-10-10.png")
	print("FAVORITE_CAPTURE: ",root.get_texture().get_image().save_png(output))
	quit()
