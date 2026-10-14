extends SceneTree
## Old stored ghosts also pass this guard before Vector3 conversion.
const Adapter = preload("res://backend/weekly_rivalry_client.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	var valid: Dictionary = {"ticks":10,"poses":[[0,0,0,0,0,0,0],[10,1,2,0,0,0,0]]}
	check(not Adapter._validate_ghost(valid).is_empty(),"normal ghost remains available")
	for coordinate: float in [1.0e300,-1.0e300,100001.0]:
		for component: int in range(1,7):
			var invalid: Dictionary = valid.duplicate(true)
			invalid.poses[0][component] = coordinate
			check(Adapter._validate_ghost(invalid).is_empty(),"unrenderable component %d is rejected"%component)
	var edge: Dictionary = valid.duplicate(true)
	edge.poses[0][1] = -100000.0
	edge.poses[0][2] = 100000.0
	check(not Adapter._validate_ghost(edge).is_empty(),"presentation bound remains inclusive")
	print("BACKEND_SECOND_PASS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures == 0 else 1)
