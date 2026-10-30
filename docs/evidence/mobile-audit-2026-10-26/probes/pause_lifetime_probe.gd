extends SceneTree
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var hud := PlaygroundHUD.new()
	var pause := preload("res://ui/race_pause_menu.gd").new()
	pause.hud = hud
	root.add_child(pause)
	print("PAUSE_LIFETIME created menu; disposing before deferred fits")
	pause.free()
	await process_frame
	await process_frame
	print("PAUSE_LIFETIME completed")
	hud.free()
	quit()
