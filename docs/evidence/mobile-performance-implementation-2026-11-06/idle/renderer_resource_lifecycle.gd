extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var loader: Node = load("res://core/feature_resource_loader.gd").new()
	root.add_child(loader)
	var entry: Dictionary = loader.request("res://ui/profile_car_renderer.gd")
	while not entry.done: await process_frame
	print("HEADER_RESOURCE_LIFECYCLE ",not entry.failed)
	entry = {}
	loader.queue_free()
	loader = null
	for _i: int in range(24): await process_frame
	quit()
