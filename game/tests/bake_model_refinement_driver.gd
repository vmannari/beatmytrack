extends SceneTree
const SOURCE = "res://../docs/evidence/car-model-refinement-2026-11-12/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
func _initialize() -> void:
	preload("res://tests/support/kart_driver_finish.gd").save(load(SOURCE))
	quit()
