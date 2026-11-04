extends SceneTree
## Real production preview service: saved cosmetics, gated capture, bounded views.
const Studio = preload("res://ui/garage_thumbnail_studio.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var output: String
var measuring: bool = false
var last_frame: int = 0
var largest_frame: int = 0

class MeasuredService extends "res://ui/garage_preview_cache.gd":
	var captured_us: int = 0
	var audit_us: int = 0
	var metrics: Dictionary = {}
	var deliveries: Array = []
	func _capture() -> void:
		var view: CarShowroom = renderer
		super._capture()
		if not is_instance_valid(view) or renderer != null: return
		captured_us = Time.get_ticks_usec()
		var began: int = Time.get_ticks_usec()
		metrics = {"dedicated":view.get_script()==Studio,"workshop":view.find_child("GarageWorkshop",true,false)!=null,"reflections":view.reflections!=null,"size":str(view.showroom_viewport.size),"aa":view.showroom_viewport.msaa_3d,"nodes":view.find_children("*","Node",true,false).size(),
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
	create_timer(180).timeout.connect(func() -> void: printerr("THUMBNAIL_TIMEOUT"); quit(1))
	process_frame.connect(observe)
	var old := GDScript.new()
	old.source_code=FileAccess.get_file_as_string("res://../docs/evidence/thumbnail-studio-enabled-2026-11-03/before/game/ui/garage_preview_cache.gd")
	check(old.reload()==OK,"task-start cache loads for old-picture identity control")
	var old_cache: Node=old.new()
	var current := MeasuredService.new()
	var thumbnail := CarShowroom.new()
	thumbnail.vehicle_id="compact"
	thumbnail.livery=VehicleLivery.defaults("compact")
	thumbnail.customisation=VehicleCustomisation.defaults()
	check(current.identity(thumbnail)!=old_cache.identity(thumbnail),"workshop pictures cannot reuse the new studio cache key")
	thumbnail.free();old_cache.free();current.free()
	await batch([true],1 if "--quick" in OS.get_cmdline_user_args() else 3)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"  "))
	print("PRODUCTION_THUMBNAIL_STUDIO ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func batch(order: Array[bool], rounds: int) -> void:
	for round_index: int in range(rounds):
		for candidate: bool in order:
			var label: String = ("studio" if candidate else "original")+"-batch-"+str(round_index)
			var service := MeasuredService.new()
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
			var paused: bool = false
			while not service.pictures_ready() and Time.get_ticks_msec() < deadline:
				if not paused and service.renderer!=null and service.renderer.showroom_ready:
					service.can_render=func() -> bool: return false
					service._process(0)
					check(service.renderer.showroom_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"foreground/input gate parks the reflection-free studio")
					service.can_render=Callable()
					paused=true
				await process_frame
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
				check(delivery.metrics.viewports == 1 and delivery.metrics.dedicated and not delivery.metrics.reflections,"dedicated single-view studio "+label+"/"+id)
				check(delivery.metrics.size == "(2048, 512)" and delivery.metrics.aa == Viewport.MSAA_4X,"full resolution and 4x AA retained "+id)
				if round_index == 0:
					var image: Image = service.ready_pictures[id].texture.get_image()
					check(image.save_png(output.path_join(("studio-" if candidate else "original-")+id+".png")) == OK,"native batch view "+id)
			var row: Dictionary = {"batch":true,"round":round_index,"candidate":candidate,"picture_ms":(delivered-began)/1000.0,
				"persisted_ms":(persisted-began)/1000.0,"largest_frame_ms":largest_frame/1000.0,"deliveries":service.deliveries}
			rows.append(row)
			print("THUMBNAIL_BATCH ",JSON.stringify(row))
			service.queue_free()
			for _frame: int in range(8): await process_frame
