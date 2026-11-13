extends "res://tests/profile_races_half.gd"
## Same-project control changes only the optional memory arbitration policy.
const BeforeMemory = preload("res://../docs/evidence/loading-half-2026-11-06/race/editor_memory.before.gd")
var policy_installed: bool = false

func observe() -> void:
	if not policy_installed and is_instance_valid(app):
		if "--control" in OS.get_cmdline_user_args(): app.editor_memory._policy = BeforeMemory.new()
		policy_installed = true
	super.observe()
