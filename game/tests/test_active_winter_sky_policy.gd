extends "res://tests/test_winter_sky_reuse.gd"
## The shell's lazy boundary activates when a real native view exists. This
## fixture constructs the environment outside App, so activate that boundary.
func _initialize() -> void:
	root.child_entered_tree.connect(func(node: Node) -> void:
		if node.has_method("_prepare_selected_track"): node.editor_memory.activate())
	super._initialize()
