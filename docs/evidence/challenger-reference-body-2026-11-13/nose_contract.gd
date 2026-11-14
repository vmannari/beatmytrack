extends SceneTree
func _initialize() -> void:
	var rows: Array = []
	for x: float in [0.0,0.4,0.6,0.7,0.9]:
		for distance: float in [1.60,1.72,1.75,1.80,1.85,1.88,1.92,1.96,2.04,2.1171,2.15]:
			rows.append([x,-distance,SuperRallyModel._nose_z(-distance,x)])
	var file := FileAccess.open("res://../docs/evidence/challenger-reference-body-2026-11-13/nose-runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"));file.close()
	print("NOSE_RUNTIME: ",rows.size()," mapping stations written")
	quit()
