extends SceneTree

const ImpactCracksEffect = preload("res://camera/impact_cracks.gd")

var checks: int = 0
var failures: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	var cracks = ImpactCracksEffect.new()
	cracks.show_impact(Vector2(4.0, 0.0))
	check(cracks.strength == 0.0, "small scrape does not crack the screen")
	cracks.show_impact(Vector2(10.0, 0.0))
	var light: float = cracks.strength
	check(light > 0.0 and cracks.visible and cracks.texture != null, "meaningful collision shows the glass texture")
	check(cracks.side_damage.x > 0.0 and cracks.side_damage.y == 0.0, "impact kicked right fractures the struck left side only")
	cracks.show_impact(Vector2(20.0, 0.0))
	check(cracks.strength > light and cracks.side_damage.x > light, "stronger impacts gradually accumulate denser local damage")
	var retained: float = cracks.strength
	check(cracks.visible and cracks.strength == retained, "fracture remains for the rest of the race")
	for impact: int in range(4): cracks.show_impact(Vector2(20.0, 0.0))
	check(cracks.side_damage.x == 1.0 and maxf(cracks.side_damage.y, maxf(cracks.side_damage.z, cracks.side_damage.w)) > 0.0, "completed struck side spills later damage onto another side")
	check(cracks.strength <= 1.0, "repeated crashes remain capped and readable")
	for impact: int in range(100): cracks.show_impact(Vector2(20.0, 0.0))
	check(cracks.side_damage == Vector4.ONE and cracks.strength == 1.0, "saturated glass accepts repeated impacts without hanging or exceeding capacity")
	cracks.clear_effect()
	check(not cracks.visible and cracks.strength == 0.0 and cracks.side_damage == Vector4.ZERO, "restart clears all fracture zones")
	cracks.free()
	print("IMPACT_CRACK_TESTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
