extends SceneTree
## Explicit production bake; the full original remains an authoring reference.
const DIRECTORY: String="res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var source: ArrayMesh=load(DIRECTORY+"driver.res")
	var split: Dictionary=preload("res://tests/support/kart_driver_split.gd").new().save(source,DIRECTORY)
	print("KART_DRIVER_SPLIT ",split.before_bytes," -> ",split.after_bytes)
	quit()
