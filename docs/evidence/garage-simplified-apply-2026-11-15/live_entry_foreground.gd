extends "res://tests/test_garage_live_entry.gd"
func _initialize() -> void:
	# The task-owned offscreen App is logically foreground for input tests.
	process_frame.connect(func() -> void:
		for child: Node in root.get_children():
			if "_publishing_slots_foreground" in child: child._publishing_slots_foreground=true)
	super._initialize()
