extends "res://tests/test_editor_practice.gd"
## Current creator-document control. Original assertions remain inherited unchanged.
func run() -> void:
	root.size = Vector2i(1280,720)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var track: NativeTrack = TrackCompiler.compile(fixture.document)
	track.spawn = Vector2(fixture.document.start_line.position[0],fixture.document.start_line.position[1])
	track.spawn_heading = PI*0.5-deg_to_rad(float(fixture.document.start_line.heading))
	print("PRACTICE_CONTROL current compiled creator document; original ellipse test remains failed")
	await _check_practice(track)
	await _check_creator_proof()
	await _check_normal_race(track)
	_finish()
