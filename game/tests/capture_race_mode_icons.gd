extends SceneTree
## Original production rail and challenge glyph at real logical display sizes.
var output: String
var captures: int = 0

func _initialize() -> void: run.call_deferred()

func capture(filename: String) -> void:
	for _frame: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(filename+".png")) != OK:
		push_error("Could not save icon review")
		quit(1)
	captures += 1

func run() -> void:
	output = OS.get_environment("BMT_RACE_ICON_OUTPUT")
	if output.is_empty():
		push_error("Set BMT_RACE_ICON_OUTPUT")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(640,440)
	root.content_scale_size = Vector2i(640,440)
	root.content_scale_factor = 1.0
	var panel := PanelContainer.new()
	panel.theme = MenuStyle.theme()
	panel.add_theme_stylebox_override("panel",MenuStyle.box(Color("101c26"),24))
	root.add_child(panel)
	MenuStyle.fill(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",22)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",54)
	column.add_child(row)
	for item: Array in [["free","Inactive"],["rivalry","Weekly Rivalry"],["challenges","Challenges"]]:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation",16)
		row.add_child(group)
		var title: Label = MenuStyle.label(item[1],18)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(title)
		var rail := RaceModeRail.new()
		rail.selected = item[0]
		rail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		group.add_child(rail)
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override("separation",18)
	column.add_child(small)
	small.add_child(MenuStyle.label("Shared Challenges glyph · 24 / 38 / 64",16,true))
	for extent: int in [24,38,64]:
		var glyph := TextureRect.new()
		glyph.texture = MenuIcon.texture("target",true)
		glyph.custom_minimum_size = Vector2(extent,extent)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		small.add_child(glyph)
	await capture("icons-actual-size")
	panel.queue_free()
	await process_frame
	# Full production page shows the shared rail and challenge empty-state glyph.
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var shell := PanelContainer.new()
	shell.theme = MenuStyle.theme()
	shell.add_theme_stylebox_override("panel",MenuStyle.box(Color("0a1620"),20))
	root.add_child(shell)
	MenuStyle.fill(shell)
	var page := ChallengesPage.new()
	shell.add_child(page)
	await capture("challenges-page")
	shell.queue_free()
	await process_frame
	print("RACE_ICON_CAPTURE: %d native views saved" % captures)
	quit(0)
