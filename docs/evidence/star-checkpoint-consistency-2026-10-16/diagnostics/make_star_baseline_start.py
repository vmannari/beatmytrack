from pathlib import Path
source = Path("game/tests/test_start_line.gd").read_text()
source = source.replace("var capture: bool = false", "var capture: bool = false\nvar old_rules: GDScript")
source = source.replace("func run() -> void:", '''func run() -> void:
\told_rules = GDScript.new()
\told_rules.source_code = FileAccess.get_file_as_string("res://../docs/evidence/star-checkpoint-consistency-2026-10-16/before/game/race/track_session.gd").replace("\\r\\n","\\n").replace("class_name TrackSession\\n","")
\tcheck(old_rules.reload() == OK,"task-start checkpoint rules load")''')
source = source.replace("var session := TrackSession.new(120,5)", "var session: RefCounted = old_rules.new(120,5)")
Path("game/tests/probe_start_line_original_gates.gd").write_text(source)
