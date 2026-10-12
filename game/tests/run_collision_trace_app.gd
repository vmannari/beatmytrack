extends SceneTree
## Normal menu/game, with an explicit diagnostic title and bounded session.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_title("CIRCUIT / 01 - Collision timing")
	var app: Node = load("res://core/app.tscn").instantiate()
	root.add_child(app)
	print("COLLISION_TRACE_APP_READY pid=",OS.get_process_id())
	await create_timer(120.0).timeout
	app.free()
	await create_timer(.2).timeout
	quit()
