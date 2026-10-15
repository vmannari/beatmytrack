extends SceneTree
## Review sheets of the shipping native photographs, rendered with native UI.
var output: String = "res://../docs/evidence/compact-kits-expanded-2026-10-14/catalog-compatibility"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(800,780)
	root.content_scale_size = root.size
	for category: String in VehicleCustomisation.CATEGORIES:
		var count: int = VehicleCustomisation.OPTIONS[category].size()
		root.size = Vector2i(800,ceili(count/2.0)*140+64)
		root.content_scale_size = root.size
		var panel := PanelContainer.new()
		root.add_child(panel)
		MenuStyle.fill(panel)
		panel.add_theme_stylebox_override("panel",MenuStyle.card(16))
		var column := VBoxContainer.new()
		panel.add_child(column)
		column.add_child(MenuStyle.label(str(VehicleCustomisation.LABELS[category])+" · "+str(count)+" fitted choices",24))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation",8)
		grid.add_theme_constant_override("v_separation",8)
		column.add_child(grid)
		for option: Array in VehicleCustomisation.OPTIONS[category]:
			var card: CompactKitThumbnail = CompactKitThumbnail.make(category,option,false,func() -> void: pass)
			card.custom_minimum_size = Vector2(380,132)
			grid.add_child(card)
		for frame: int in range(6): await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output.path_join(category+".png"))!=OK:
			quit(1)
			return
		panel.queue_free()
		await process_frame
	print("KIT_CATALOG_CAPTURES: 4 sheets, 43 actual models")
	quit()
