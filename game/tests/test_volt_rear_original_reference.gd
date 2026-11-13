extends "res://tests/test_volt_reference_redesign.gd"
## Archived task-start geometry under the unchanged historical reference gates.
func run() -> void:
	var body: GDScript=load("res://vehicle/electric_reference_body.gd")
	body.source_code=FileAccess.get_file_as_string("res://../docs/evidence/volt-rear-smoothing-2026-11-08/task-start/game/vehicle/electric_reference_body.gd")
	assert(body.reload()==OK)
	var mesh: GDScript=load("res://vehicle/electric_reference_mesh.gd")
	mesh.source_code=mesh.source_code.replace("res://assets/vehicles/electric_rear_lamp_gaps_v1","res://../docs/evidence/volt-rear-smoothing-2026-11-08/task-start/game/assets/vehicles/electric_rear_lamp_gaps_v1")
	assert(mesh.reload()==OK)
	await super.run()
