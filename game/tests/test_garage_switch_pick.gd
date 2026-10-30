extends SceneTree
## Garage picks build from the current model after replacement or a kit change.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func run() -> void:
	root.size = Vector2i(960,540)
	var view := CarShowroom.new()
	view.garage_mode = true
	view.vehicle_id = "compact"
	view.livery = VehicleLivery.defaults("compact")
	view.customisation = VehicleCustomisation.defaults()
	root.add_child(view)
	view.size = Vector2(960,540)
	while not view.showroom_ready: await process_frame
	var timings: Array = []
	for id: String in VehicleCatalog.IDS:
		var started: int = Time.get_ticks_usec()
		view.replace_car(id,VehicleLivery.defaults(id),{},VehicleCustomisation.defaults())
		var switch_ms: float = (Time.get_ticks_usec()-started)/1000.0
		check(view.car.vehicle_id==id and view.car.model_ready,"actual car ready "+id)
		var eager: int = view.pick_meshes.size()
		view.finish_car_transition()
		# A central ray may miss a particular body, but must populate pick geometry.
		started = Time.get_ticks_usec()
		view.pick_body_surface(view.size/2.0)
		var pick_ms: float = (Time.get_ticks_usec()-started)/1000.0
		check(not view.pick_meshes.is_empty(),"first pick builds geometry "+id)
		check(view.pick_meshes.all(func(entry: Dictionary) -> bool: return view.car.is_ancestor_of(entry.node)),"pick geometry belongs to current car "+id)
		timings.append({"car":id,"switch_ms":switch_ms,"eager":eager,"first_pick_ms":pick_ms})
		await process_frame
	view.replace_car("compact",VehicleLivery.defaults("compact"),{},VehicleCustomisation.defaults())
	view.finish_car_transition()
	view.pick_body_surface(view.size/2.0)
	var parts: Dictionary = VehicleCustomisation.defaults()
	parts.hood = VehicleCustomisation.OPTIONS.hood[1][0]
	view.apply_customisation(parts)
	check(view.pick_meshes.is_empty(),"kit change invalidates old pick geometry")
	view.yaw = -PI * 0.5
	view.elevation = 0.12
	view.set_zoom(0.85)
	var target: Vector3 = Vector3(-0.9,0.50,0.1)
	var pixel: Vector2 = view.camera.unproject_position(view.car.body.global_transform*target)*view.size/Vector2(view.showroom_viewport.size)
	check(not view.pick_body_surface(pixel).is_empty(),"first pick after kit change hits actual body")
	check(not view.pick_meshes.is_empty() and view.pick_meshes.all(func(entry: Dictionary) -> bool: return view.car.is_ancestor_of(entry.node)),"first pick after kit change uses current car")
	check(view.wash_at(pixel,0.2),"wash works at the current body after kit change")
	view.replace_car("pickup",VehicleLivery.defaults("pickup"),{},VehicleCustomisation.defaults())
	view.replace_car("kart",VehicleLivery.defaults("kart"),{},VehicleCustomisation.defaults())
	check(view.car.vehicle_id=="kart" and view.car.model_ready,"interrupted transition retains the last car")
	view.finish_car_transition()
	check(view.turntable.visible and view.outgoing_pedestal==null,"interrupted transition settles its last pedestal")
	view.pick_body_surface(view.size/2.0)
	check(not view.pick_meshes.is_empty() and view.pick_meshes.all(func(entry: Dictionary) -> bool: return view.car.is_ancestor_of(entry.node)),"first pick after rapid replacements uses the last car")
	print("GARAGE_SWITCH_PICK ",JSON.stringify({"checks":checks,"failures":failures,"timings":timings}))
	view.queue_free()
	await process_frame
	quit(1 if failures else 0)
