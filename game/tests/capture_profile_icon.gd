extends SceneTree
## Offline native capture of the actual public player profile and shared icon.
const Profile = preload("res://ui/player_profile.gd")
const Fixture = preload("res://tests/test_rivalry_player_profile.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280,900)
	var client := Fixture.ProfileClient.new()
	client.empty = true
	root.add_child(client)
	var row: Dictionary = {
		"driver_id":"driver_0", "name":"Kai Lake", "country_code":"SE",
		"rank":3, "points":80,
		"appearance":{"vehicle_id":"compact", "livery":VehicleLivery.defaults("compact")}
	}
	var sheet: Node = Profile.open(root,client,row,"compact")
	for frame: int in range(30): await process_frame
	await RenderingServer.frame_post_draw
	var output: String = "res://../docs/evidence/profile-icon-2026-10-25"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var symbol: TextureRect = sheet.get_node("PopupStyle").symbol
	print("PROFILE_ICON: person=",symbol.texture == MenuIcon.texture("person",true)," color=",symbol.modulate)
	var result: Error = root.get_texture().get_image().save_png(output.path_join("player-profile-person.png"))
	print("PROFILE_ICON_CAPTURE: ",error_string(result))
	sheet.queue_free()
	client.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
