extends SceneTree
## Identical native side/rear/close cameras expose mount height and aft position.
var output: String = "res://../docs/evidence/compact-aero-variety-2026-10-14/compatibility"
var view: CarShowroom
func _initialize() -> void: _run.call_deferred()
func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
func picture(name: String, target: Vector3, offset: Vector3) -> void:
	var body: Transform3D = view.car.body.global_transform
	var focus: Vector3 = body*target
	view.camera.look_at_from_position(focus+offset,focus)
	view.reflections.sync()
	await settle()
	assert(view.showroom_viewport.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root=" ): output = arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1440,900)
	root.content_scale_size = root.size
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	view = CarShowroom.new()
	view.garage_mode = true
	host.add_child(view)
	MenuStyle.fill(view)
	await settle()
	for option: Array in VehicleCustomisation.OPTIONS.aero:
		var next: Dictionary = VehicleCustomisation.defaults()
		next.aero = option[0]
		view.apply_customisation(next)
		await picture(str(option[0])+"-side",Vector3(0,0.93,0.45),Vector3(6.8,0.70,0.10))
		await picture(str(option[0])+"-rear",Vector3(0,1.12,1.30),Vector3(4.6,1.25,5.6))
		await picture(str(option[0])+"-mount",Vector3(0,1.35,1.88),Vector3(2.4,0.72,2.6))
	# Readable contact sheet built from the shipping actual-model thumbnails.
	view.hide()
	root.size = Vector2i(1200,880)
	root.content_scale_size = root.size
	var panel := PanelContainer.new()
	root.add_child(panel)
	MenuStyle.fill(panel)
	panel.add_theme_stylebox_override("panel",MenuStyle.card(16))
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(MenuStyle.label("REAR AERO · 13 fitted choices",24))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	column.add_child(grid)
	for option: Array in VehicleCustomisation.OPTIONS.aero:
		var card: CompactKitThumbnail = CompactKitThumbnail.make("aero",option,false,func() -> void: pass)
		card.custom_minimum_size = Vector2(380,150)
		grid.add_child(card)
	await settle()
	assert(root.get_texture().get_image().save_png(output.path_join("catalog.png"))==OK)
	panel.queue_free()
	host.queue_free()
	await process_frame
	print("AERO_VARIETY_CAPTURES: 39 native close views and 13-choice sheet")
	quit()
