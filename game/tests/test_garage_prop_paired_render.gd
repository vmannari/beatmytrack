extends "res://tests/test_garage_mesh_paired_render.gd"
## Compare only the revised room around the same car; include turned-prop close views.
func _initialize() -> void:
	var candidate: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--candidate-room="): candidate = argument.trim_prefix("--candidate-room=")
	if candidate.is_empty():
		printerr("FAIL: --candidate-room must name the room being reviewed")
		quit(1); return
	GarageEnvironment.architecture_scene = load(candidate)
	super._initialize()

func capture(view: CarShowroom, label: String) -> void:
	await super.capture(view,label)
	if label != "overhead": return
	var original: Transform3D = view.camera.transform
	for pose: Array in [
		["compressor-detail",Vector3(5.05,1.12,5.8),Vector3(5.4,0.48,7.1)],
		["shelf-stock",Vector3(-6.9,3.1,6.0),Vector3(-6.9,3.2,7.7)],
		["hand-tools",Vector3(5.9,2.15,6.5),Vector3(5.9,1.9,8.1)],
		["speaker-detail",Vector3(8.45,1.25,4.05),Vector3(9.8,1.08,4.7)],
		["vice-detail",Vector3(5.2,1.65,6.3),Vector3(5.2,1.2,7.6)]
	]:
		view.camera.position = pose[1]
		view.camera.look_at(pose[2])
		await super.capture(view,pose[0])
	view.camera.transform = original
