extends "res://tests/test_challenge_cards.gd"
## Reload exact task-start sources only in this disposable process's memory.
func _initialize() -> void:
	for path: String in ["ui/challenge_format_card.gd","ui/challenge_create.gd"]:
		var script: GDScript = load("res://"+path)
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/translation-gaps-2026-10-25/before/game__"+path.replace("/","__"))
		if script.reload(true) != OK:
			quit(2)
			return
	super._initialize()
