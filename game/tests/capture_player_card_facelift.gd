extends "res://tests/test_rivalry_player_profile.gd"

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/player-card-facelift-2026-10-24/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280,720)
	var client := ProfileClient.new()
	root.add_child(client)
	client._capabilities = {"world_ranking_version":1}
	for empty: bool in [false,true]:
		client.empty = empty
		var row: Dictionary = fixture().standings[0].duplicate(true)
		row.id = "driver_0"
		row.name = "Kai Rowan"
		row.country_code = "ES"
		row.rank = 2
		row.appearance = preload("res://ui/artificial_driver_appearance.gd").create("facelift","compact")
		var sheet: Node = Profile.open(root,client,row,"compact")
		await settle()
		check(root.get_visible_rect().encloses(Rect2(sheet.position,sheet.size)),"profile fits visible area")
		check(sheet.track_status.size.y > 100 if empty else sheet.tracks.size.x >= sheet.tracks.get_combined_minimum_size().x,"empty and populated library layout")
		await shot("empty" if empty else "published")
		sheet.queue_free()
		await settle()
	client.queue_free()
	print("PLAYER_CARD_FACELIFT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

