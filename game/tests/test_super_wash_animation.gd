extends SceneTree
## Exercise real Garage cleaning and bounded feedback with isolated local records.
var checks: int = 0
var failures: int = 0
var output: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func settle() -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func capture(page: GaragePage, label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	page.showroom.invalidate_render()
	for index: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)

func check_brush_front(showroom: CarShowroom, before: Dictionary, id: String) -> void:
	var effect: Node3D = showroom.super_wash_effect
	var weather: VehicleWeathering = showroom.weathering
	var front: float = weather._body.to_local(effect.gantry.global_position).z
	var wash: PackedByteArray = weather.wash_image.get_data()
	var slow: PackedByteArray = weather.slow_wash_image.get_data()
	var original: PackedByteArray = Marshalls.base64_to_raw(before.wash)
	var original_slow: PackedByteArray = Marshalls.base64_to_raw(before.slow_wash)
	var behind_clean: bool = true
	var ahead_exact: bool = true
	var behind: int = 0
	var ahead: int = 0
	for z: int in range(VehicleCondition.GRID):
		var along: float = weather.bounds.position.z + weather.bounds.size.z * float(z) / 15.0
		for y: int in range(VehicleCondition.GRID):
			for x: int in range(VehicleCondition.GRID):
				var index: int = y*256+z*16+x
				if along < front-0.4:
					behind += 1
					behind_clean = behind_clean and wash[index]==255 and slow[index]==255
				elif along > front+0.4:
					ahead += 1
					ahead_exact = ahead_exact and wash[index]==original[index] and slow[index]==original_slow[index]
	check(behind>0 and behind_clean,id+" both layers clean behind the actual brushes")
	check(ahead>0 and ahead_exact,id+" both layers remain exact ahead of the actual brushes")
	check(weather.dirt_amount==before.dirt and weather.slow_dirt_amount==before.slow_dirt,id+" deposits retain their strength on untouched panels")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_SUPER_WASH_OUTPUT").path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://super_wash_animation_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	var dirty: Dictionary = VehicleWeathering.new().snapshot()
	for field: String in ["dirt","slow_dirt","mud","smudge"]: dirty[field] = 0.95
	# Preserve earlier manual strokes in the two independent deposit layers.
	var old_wash: PackedByteArray = Marshalls.base64_to_raw(dirty.wash)
	var old_slow: PackedByteArray = old_wash.duplicate()
	old_wash[14*16+8] = 200
	old_slow[14*16+8] = 90
	dirty.wash = Marshalls.raw_to_base64(old_wash)
	dirty.slow_wash = Marshalls.raw_to_base64(old_slow)
	for id: String in VehicleCatalog.IDS: VehicleCondition.save(records,id,dirty)
	root.size = Vector2i(1280,720)
	var page := GaragePage.new()
	page.records = records
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	await settle()
	if OS.has_environment("BMT_SUPER_WASH_MOTION"):
		page._show_section("care")
		await settle()
		page.showroom.set_process(false)
		page._super_wash()
		DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
		for frame: int in range(55):
			await capture(page,"motion/frame-%03d" % frame)
			page.showroom.super_wash_effect.advance(1.0/15.0)
		page.queue_free()
		await process_frame
		print("SUPER_WASH_MOTION: %d checks, %d failures; 55 native frames at stepped 15 Hz" % [checks,failures])
		quit(1 if failures else 0)
		return
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		page.open_car(index)
		page._show_section("care")
		await settle()
		var showroom: CarShowroom = page.showroom
		showroom.set_process(false)
		var paint: Dictionary = showroom.livery.duplicate(true)
		var parts: Dictionary = showroom.customisation.duplicate(true)
		var before: Dictionary = showroom.weathering.snapshot()
		await capture(page,id+"-dirty")
		page.preview.get_node("GarageWashTools/GarageSuperWash").pressed.emit()
		var effect: Node3D = showroom.super_wash_effect
		check(is_instance_valid(effect) and effect.visible,id+" starts automatic wash from its real button")
		check(effect.get_parent()==showroom.car,id+" rig follows actual selected car")
		check(showroom.weathering.snapshot()==before,id+" starting the machine preserves the dirty car")
		check(VehicleCondition.read(records,id)==before,id+" start does not save a clean result")
		check(not showroom.wash_mode and not showroom.washing,id+" manual washing ends")
		check(effect.rollers.size()==3,id+" three powered brushes")
		check(effect.water.multimesh.instance_count==96,id+" fixed spray pool")
		check(effect.travel.x<effect.bounds.position.z and effect.travel.y>effect.bounds.end.z,id+" complete nose-to-tail pass")
		effect.advance(0.7)
		var start: Vector3 = effect.gantry.position
		var spin: Vector3 = effect.rollers[0].rotation
		await capture(page,id+"-start")
		effect.advance(1.1)
		check(effect.gantry.position.z>start.z and effect.rollers[0].rotation!=spin,id+" machine travels and brushes rotate")
		check_brush_front(showroom,before,id)
		var middle: Dictionary = showroom.weathering.snapshot()
		page._super_wash()
		check(is_equal_approx(effect.elapsed,1.8) and showroom.weathering.snapshot()==middle,id+" repeated press preserves the running pass")
		await capture(page,id+"-middle")
		var node_count: int = effect.get_child_count()
		effect.advance(1.0)
		await capture(page,id+"-rinse")
		effect.advance(0.9)
		check(not effect.visible and effect.water.multimesh.visible_instance_count==0,id+" completion leaves no active spray")
		check(VehicleCondition.read(records,id).dirt==0.0 and not showroom.weathering.installed,id+" completion restores and saves clean original materials")
		check(showroom.livery==paint and showroom.customisation==parts,id+" retains equipped paint and fittings")
		showroom.play_super_wash()
		check(showroom.super_wash_effect==effect and effect.get_child_count()==node_count,id+" repeats reuse the same rig")
		var clean: Dictionary = showroom.weathering.snapshot()
		effect.advance(1.8)
		showroom.set_wash_mode(true)
		check(not effect.visible,id+" manual wash cancels automatic feedback")
		check(showroom.weathering.snapshot()==clean and VehicleCondition.read(records,id)==clean,id+" a clean car stays exact during a repeated or cancelled pass")
		showroom.set_wash_mode(false)
		showroom.play_super_wash()
		page._show_section("cars")
		check(not effect.visible,id+" section navigation cancels feedback")
		page._show_section("care")
		await settle()
		showroom.play_super_wash()
		page.hide()
		check(not effect.visible,id+" hiding clears feedback")
		page.show()
		VehicleCondition.save(records,id,dirty)
		page._save_condition()
		page._super_wash()
		effect.advance(1.8)
		var partial: Dictionary = showroom.weathering.snapshot()
		page._show_section("cars")
		check(not effect.visible and VehicleCondition.read(records,id)==partial,id+" cancelling saves only the brushed portion")
		var reopened := LocalRecords.new(records.path)
		reopened.load_records()
		check(VehicleCondition.read(reopened,id)==partial,id+" partial cleaning survives local reload")
		check(partial.dirt>0.0 and Marshalls.base64_to_raw(partial.wash).count(0)>0,id+" cancellation leaves untouched dirt")
		page._show_section("care")
		await settle()
		page._super_wash()
		effect.advance(0.6)
		VehicleCondition.save(records,id,dirty)
		page._process(0.0)
		effect.advance(4.0)
		check(not effect.visible and showroom.weathering.snapshot()==dirty and VehicleCondition.read(records,id)==dirty,id+" newer wear cancels the stale pass")
		showroom.set_process(true)
	await settle()
	page._show_section("care")
	await settle()
	page.showroom.set_process(false)
	page._super_wash()
	var stepped: Node3D = page.showroom.super_wash_effect
	stepped.advance(1.8)
	var skipped_frames: Dictionary = page.showroom.weathering.snapshot()
	stepped.reset()
	page.showroom.weathering.restore(dirty)
	page.showroom.play_super_wash()
	for index: int in range(18): stepped.advance(0.1)
	check(page.showroom.weathering.snapshot()==skipped_frames,"cleaning at the same brush position is independent of frame size")
	stepped.advance(4.0)
	page.showroom.set_process(true)
	page._super_wash()
	var outgoing: Node3D = page.showroom.super_wash_effect
	page.open_car(0)
	check(not is_instance_valid(page.showroom.super_wash_effect),"car replacement discards previous rig")
	await settle()
	check(not is_instance_valid(outgoing),"outgoing rig freed with old model")
	page._show_section("care")
	await settle()
	page._super_wash()
	await create_timer(4.0).timeout
	check(not page.showroom.super_wash_effect.visible,"normal process completes the animation")
	await settle()
	var requests: int = page.showroom.render_requests
	await create_timer(0.5).timeout
	check(page.showroom.render_requests==requests,"completed wash resumes retained idle drawing")
	page.queue_free()
	await process_frame
	print("SUPER_WASH_ANIMATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
