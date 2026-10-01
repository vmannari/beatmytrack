extends SceneTree
## Wait for actual asynchronous startup instead of assuming a frame count.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+45000
	while not app.get("startup_complete"):
		if Time.get_ticks_msec() >= deadline:
			push_error("Application startup did not complete within 45 seconds.")
			quit(1)
			return
		await process_frame
	quit(0)
