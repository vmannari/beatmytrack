extends SceneTree
func _initialize() -> void:
	var values: Array=[]
	for z: float in [-2.35,-2.22,-2.15,-2.0,-1.85,-1.73,-1.65,-1.6,-1.53,-1.4]:
		for x: float in [-.92,-.7,-.4,0,.4,.7,.92]:
			values.append([x,z,SuperRallyModel._nose_plan_x(x,z)])
	var f:=FileAccess.open("res://../docs/evidence/challenger-nose-curve-2026-11-13/runtime-plan.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(values));f.close();print("PLAN_RUNTIME: 70 stations");quit()
