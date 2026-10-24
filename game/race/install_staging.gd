extends Node
## Own an unattached cache snapshot while its builder yields or is canceled.
var staged: Node
func _exit_tree() -> void:
	if is_instance_valid(staged): staged.free()
	staged = null
