extends "res://tests/test_device_race_preparation.gd"
## Keep every retained assertion; substitute only the task-start controllers.
const BeforeSelection=preload("res://../docs/evidence/selected-events-retention-2026-11-04/before/game/core/features/selected_track.gd")
const BeforeMemory=preload("res://../docs/evidence/selected-events-retention-2026-11-04/before/game/editor/editor_memory.gd")
func _initialize() -> void:
	root.child_entered_tree.connect(func(node: Node) -> void:
		if not node.has_method("_prepare_selected_track"): return
		var controller: Node=BeforeSelection.new()
		node._feature_resources["res://core/features/selected_track.gd"]=controller
		node.add_child(controller)
		node.editor_memory=BeforeMemory.new())
	super._initialize()
