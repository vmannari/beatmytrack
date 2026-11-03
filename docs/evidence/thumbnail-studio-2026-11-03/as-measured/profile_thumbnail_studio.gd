extends SceneTree
## Real preview-service misses. Same car, resolution, AA, read/write and settling.
const Cache = preload("res://ui/garage_preview_cache.gd")
const Candidate = preload("res://ui/garage_thumbnail_studio.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var output: String
var measuring: bool = false
var last_frame: int = 0
var largest_frame: int = 0

class MeasuredService extends "res://ui/garage_preview_cache.gd":
	var candidate: bool = false
	var captured_us: int = 0
	var audit_us: int = 0
	var metrics: Dictionary = {}
	var deliveries: Array = []
	func _make_renderer() -> CarShowroom:
		# Concrete retained control remains the old renderer after integration.
		return Candidate.new() if candidate else preload("res://ui/garage_preview_renderer.gd").new()
	func _capture() -> void:
		var view: CarShowroom = renderer
		super._capture()
		if not is_instance_valid(view) or renderer != null: return
		captured_us = Time.get_ticks_usec()
		var began: int = Time.get_ticks_usec()
		metrics = {"nodes":view.find_children("*","Node",true,false).size(),
			"meshes":view.find_children("*","GeometryInstance3D",true,false).size(),
			"scene_bytes_estimate":preload("res://track/prepared_world_cache.gd")._resource_bytes(view,{}),
			"viewports":view.find_children("*","SubViewport",true,false).size(),"viewport_pixels":0,
			"vehicle":view.car.vehicle_id,"livery":view.car.livery.duplicate(true),"parts":view.car.customisation.duplicate(true),
			"body_color":view.car.paint_materials.body.albedo_color.to_html(false),"dirt":view.weathering.dirt_amount}
		for viewport: SubViewport in view.find_children("*","SubViewport",true,false): metrics.viewport_pixels += viewport.size.x*viewport.size.y
		audit_us = Time.get_ticks_usec()-began
		deliveries.append({"us":captured_us,"audit_us":audit_us,"metrics":metrics.duplicate(true)})

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("THUMBNAIL_STUDIO_FAIL ",label)
func observe() -> void:
	var now: int = Time.get_ticks_usec()
	if measuring and last_frame > 0: largest_frame = maxi(largest_frame,now-last_frame)
	last_frame = now
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_THUMBNAIL_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	process_frame.connect(observe)
	var order: Array[bool] = [false,true]
	if "--candidate-first" in OS.get_cmdline_user_args(): order.reverse()
	if "--only-original" in OS.get_cmdline_user_args(): order = [false]
	if "--only-studio" in OS.get_cmdline_user_args(): order = [true]
	var rounds: int = 3
	if "--quick" in OS.get_cmdline_user_args(): rounds = 1
	if "--batch" in OS.get_cmdline_user_args():
		await batch(order,rounds)
		finish()
		return
	for round_index: int in range(rounds):
		for id: String in VehicleCatalog.IDS:
			var paint: Dictionary = VehicleLivery.defaults(id)
			paint.colors.body = "32b5d7"
			paint.pattern = "offset_gt"
			var parts: Dictionary = VehicleCustomisation.defaults()
			if id in ["compact","kart","forklift","electric"]:
				var choices: Array = VehicleCustomisation.options("aero",id)
				if choices.size() > 1: parts.aero = choices[1][0]
			var wear: Dictionary = VehicleWeathering.new().snapshot()
			wear.dirt = 0.12
			for candidate: bool in order:
				var label: String = ("studio" if candidate else "original")+"-"+id+"-"+str(round_index)
				var service := MeasuredService.new()
				service.candidate = candidate
				service.idle_ms = 0
				service.directory = "user://thumbnail-benchmark/"+label
				root.add_child(service)
				var tile: CarShowroom = preload("res://ui/garage_cached_thumbnail.gd").new()
				tile.preview_service = service
				tile.vehicle_id = id
				tile.livery = paint.duplicate(true)
				tile.customisation = parts.duplicate(true)
				tile.condition = wear.duplicate(true)
				tile.position = Vector2(20,20)
				tile.size = Vector2(300,140)
				largest_frame = 0
				last_frame = Time.get_ticks_usec()
				var began: int = last_frame
				measuring = true
				root.add_child(tile)
				var deadline: int = Time.get_ticks_msec()+90000
				while tile._image.texture == null and Time.get_ticks_msec() < deadline: await process_frame
				measuring = false
				check(tile._image.texture != null,"actual picture delivered "+label)
				if tile._image.texture == null: quit(1); return
				while (service.worker != null or not service.pending_writes.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
				var persisted: int = Time.get_ticks_usec()
				check(service.worker == null and service.pending_writes.is_empty(),"PNG write completed "+label)
				check(service.metrics.vehicle == id and service.metrics.livery == paint and service.metrics.parts == parts,"saved model/paint/kits preserved "+label)
				check(service.metrics.body_color == paint.colors.body,"actual paint material preserved "+label)
				check(service.metrics.viewports == (1 if candidate else 3),"expected capture views "+label)
				var image: Image = tile._image.texture.get_image()
				check(image.get_size() == Vector2i(2048,512),"unchanged native picture dimensions "+label)
				if round_index == 0: check(image.save_png(output.path_join(label+".png")) == OK,"native capture "+label)
				var row: Dictionary = {"round":round_index,"vehicle":id,"candidate":candidate,
					"picture_ms":(service.captured_us-began)/1000.0,"persisted_ms":(persisted-began-service.audit_us)/1000.0,
					"largest_frame_ms":largest_frame/1000.0,"audit_us":service.audit_us,"metrics":service.metrics}
				rows.append(row)
				print("THUMBNAIL_SAMPLE ",JSON.stringify(row))
				tile.queue_free()
				service.queue_free()
				for _frame: int in range(6): await process_frame
			order.reverse()
	finish()

func finish() -> void:
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"  "))
	file.close()
	print("THUMBNAIL_STUDIO_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func batch(order: Array[bool], rounds: int) -> void:
	for round_index: int in range(rounds):
		for candidate: bool in order:
			var label: String = ("studio" if candidate else "original")+"-batch-"+str(round_index)
			var service := MeasuredService.new()
			service.candidate = candidate
			service.idle_ms = 0
			root.add_child(service)
			var records := LocalRecords.new("user://thumbnail-batch/"+label+"/records.json")
			var paints: Dictionary = {}
			var kits: Dictionary = {}
			var conditions: Dictionary = {}
			for id: String in VehicleCatalog.IDS:
				var paint: Dictionary = VehicleLivery.defaults(id)
				paint.colors.body = "32b5d7"
				paint.pattern = "offset_gt"
				paints[id] = paint
				var parts: Dictionary = VehicleCustomisation.defaults()
				if id != "hovercraft":
					var choices: Array = VehicleCustomisation.options("aero",id)
					if choices.size() > 1: parts.aero = choices[1][0]
				kits[id] = parts
				var wear: Dictionary = VehicleWeathering.new().snapshot()
				wear.dirt = 0.12
				conditions[id] = wear
			records.settings = {"vehicle_liveries":paints,"vehicle_customisation":kits,"vehicle_conditions":conditions}
			var began: int = Time.get_ticks_usec()
			largest_frame = 0
			last_frame = began
			measuring = true
			service.warm_records(records,false)
			var deadline: int = Time.get_ticks_msec()+150000
			while not service.pictures_ready() and Time.get_ticks_msec() < deadline: await process_frame
			measuring = false
			check(service.pictures_ready(),"all five actual pictures delivered "+label)
			if not service.pictures_ready(): quit(1); return
			var delivered: int = service.captured_us
			while (service.worker != null or not service.pending_writes.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
			var persisted: int = Time.get_ticks_usec()
			check(service.worker == null and service.pending_writes.is_empty(),"all five PNG writes completed "+label)
			check(service.deliveries.size() == VehicleCatalog.IDS.size(),"one capture per actual car "+label)
			for delivery: Dictionary in service.deliveries:
				var id: String = delivery.metrics.vehicle
				check(delivery.metrics.livery == paints[id] and delivery.metrics.parts == kits[id],"exact saved appearance "+label+"/"+id)
				check(delivery.metrics.body_color == paints[id].colors.body,"actual paint preserved "+label+"/"+id)
				check(is_equal_approx(delivery.metrics.dirt,0.12),"saved condition preserved "+label+"/"+id)
				check(delivery.metrics.viewports == (1 if candidate else 3),"bounded views "+label+"/"+id)
				if round_index == 0:
					var image: Image = service.ready_pictures[id].texture.get_image()
					check(image.save_png(output.path_join(("studio-" if candidate else "original-")+id+".png")) == OK,"native batch view "+id)
			var row: Dictionary = {"batch":true,"round":round_index,"candidate":candidate,"picture_ms":(delivered-began)/1000.0,
				"persisted_ms":(persisted-began)/1000.0,"largest_frame_ms":largest_frame/1000.0,"deliveries":service.deliveries}
			rows.append(row)
			print("THUMBNAIL_BATCH ",JSON.stringify(row))
			service.queue_free()
			for _frame: int in range(8): await process_frame
		order.reverse()
