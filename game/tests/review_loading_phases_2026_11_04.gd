extends "res://tests/review_loading_2026_11_04.gd"
## Passive milestones and workload counters supplement the actual-App timings.
var phase: String = ""
func observe() -> void:
	super.observe()
	if not is_instance_valid(app): return
	var current: String = "startup" if not app.startup_complete else "menu"
	if is_instance_valid(app._retained_garage):
		var studio: Node = app._retained_garage.showroom
		current = "garage_waiting"
		if is_instance_valid(studio.car): current = "car_ready" if studio.car.model_ready else "car_build"
		if studio.showroom_ready: current = "showroom_built"
		if app._retained_garage.progressive_entry:
			if is_instance_valid(studio._first): current = "first_draws"
			if not studio.preparing: current = "live"
		else: current = "adopted_live"
		if current in ["live","adopted_live"] and current != phase:
			var keys: Dictionary = {}
			var materials: Dictionary = {}
			for node: GeometryInstance3D in studio.camera.get_parent().find_children("*","GeometryInstance3D",true,false):
				if not node.is_visible_in_tree(): continue
				var key: String = preload("res://race/world_render_preparation.gd")._key(node,materials)
				keys[key] = int(keys.get(key,0))+1
			var batches: int = 0
			var objects: int = 0
			for count: int in keys.values():
				batches += ceili(float(count)/8.0)
				objects += count
			print("GARAGE_WORKLOAD ",JSON.stringify({"visible_geometry":objects,"current_key_groups":keys.size(),"eight_object_batches":batches,"garage_template_hits":preload("res://ui/garage_car_cache.gd").hits,"modular_base_hits":preload("res://vehicle/modular_car_base.gd").hits,"header_template_hits":preload("res://ui/header_simple_cache.gd").hits}))
	if current != phase:
		phase = current
		print("LOADING_PHASE ",JSON.stringify({"phase":phase,"us":Time.get_ticks_usec()}))
