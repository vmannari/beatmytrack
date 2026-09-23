extends SceneTree

var checks: int = 0
var failures: int = 0


func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _initialize() -> void:
	var camera := FollowCamera.new()
	check(camera.shake_offset(1.0 / 60.0) == Vector2.ZERO, "settled camera has no shake")
	camera.add_collision_impact(Vector2(4.0, 0.0))
	var light: float = camera.impact_velocity.length()
	camera.clear_shake()
	camera.add_collision_impact(Vector2(16.0, 0.0))
	check(camera.impact_velocity.length() > light, "harder resolved impact produces stronger kick")
	var first: Vector2 = camera.shake_offset(1.0 / 60.0)
	check(first.x > absf(first.y), "collision kick is predominantly in resolved impulse direction")
	var peak: float = first.length()
	for frame: int in range(90):
		peak = maxf(peak, camera.shake_offset(1.0 / 60.0).length())
	check(camera.impact_offset.length() < 0.001 and peak <= FollowCamera.MAX_IMPACT_METRES, "impact kick is bounded and settles")
	camera.set_off_track_rumble(0.25)
	for frame: int in range(20): camera.shake_offset(1.0 / 60.0)
	var mild: float = camera.surface_strength
	camera.set_off_track_rumble(1.0)
	for frame: int in range(20): camera.shake_offset(1.0 / 60.0)
	var strong: float = camera.surface_strength
	check(strong > mild, "faster or rougher off-track travel produces stronger rumble")
	check(FollowCamera.SURFACE_PRIMARY_FREQUENCY < 70.0 and FollowCamera.SURFACE_SECONDARY_FREQUENCY < 50.0, "off-track rumble uses the lower-frequency terrain profile")
	camera.clear_shake()
	check(camera.impact_offset == Vector2.ZERO and camera.surface_strength == 0.0, "camera snap clears impulse and surface state")
	print("CAMERA_SHAKE_TESTS checks=%d failures=%d" % [checks, failures])
	camera.free()
	quit(1 if failures > 0 else 0)
