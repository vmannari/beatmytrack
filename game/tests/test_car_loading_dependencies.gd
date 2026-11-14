extends SceneTree
## A prepared-load consumer must not compile the five optional source factories.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var visual: Script=load("res://vehicle/car_visual.gd")
	var failures: int=0
	for name: String in ["vehicle_models","kart_model","electric_car_model","hovercraft_model","forklift_model","compact_coachwork"]:
		if ResourceLoader.has_cached("res://vehicle/"+name+".gd"):
			failures+=1; printerr("LOADING_DEPENDENCY_FAIL eager factory ",name)
	for name: String in ["driver.res","helmet_static.res"]:
		if ResourceLoader.has_cached("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/"+name):
			failures+=1; printerr("LOADING_DEPENDENCY_FAIL eager driver asset ",name)
	assert(visual!=null)
	print("CAR_LOADING_DEPENDENCIES 8 checks, ",failures," failures")
	quit(1 if failures else 0)
