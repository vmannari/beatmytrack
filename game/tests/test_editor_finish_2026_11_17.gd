extends "res://tests/test_editor_space_2026_11_17.gd"

func bounds() -> void:
	super.bounds()
	var dock: Control = app.root_ui.find_child("EditorToolDock",true,false)
	var header: Control = app.root_ui.find_child("EditorTopBar",true,false)
	var rail: Control = app.root_ui.find_child("EditorRailPanel",true,false)
	check((header.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == (dock.get_theme_stylebox("panel") as StyleBoxFlat).bg_color,"header and footer share one shell colour")
	check((rail.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == (dock.get_theme_stylebox("panel") as StyleBoxFlat).bg_color,"rail shares the shell colour")
	if not app.object_browser.visible:
		var body: Control = dock.find_child("EditorDockBody",true,false)
		check(absf(body.get_global_rect().get_center().x-dock.get_global_rect().get_center().x) <= 1,"active bottom group is centred: "+app.canvas.mode)
		var samples: Array[BaseButton] = []
		for child: Control in app.editor_context.get_children():
			if child is BaseButton and child.is_visible_in_tree(): samples.append(child)
		for child: Control in app.object_controls.get_children():
			if child is BaseButton and child.is_visible_in_tree(): samples.append(child)
		for item: BaseButton in samples:
			var idle: StyleBoxFlat = item.get_theme_stylebox("normal")
			check(idle.bg_color == (app.editor_mode_buttons.road.get_theme_stylebox("normal") as StyleBoxFlat).bg_color,"card fill matches navigation: "+str(item.name))
			check(idle.shadow_size == 0,"cards have no floating shadows")
			if item is EditorButton and not item.caption.is_empty():
				var caption: Label = item.find_child("ToolCaption",true,false)
				check(caption != null and caption.is_visible_in_tree() and not caption.text.is_empty(),"tool caption uses a visible native label")
				if caption != null: check(contrast(caption.get_theme_color("font_color"),idle.bg_color) >= 4.5,"tool caption contrast is readable")
	else:
		var children: Array[Node] = app.object_browser.tiles.get_children()
		if not children.is_empty() and children[0] is BaseButton:
			var first: Control = children[0]; var last: Control = children.back()
			var middle: float = (first.get_global_rect().position.x+last.get_global_rect().end.x)*0.5
			check(absf(middle-(app.object_browser.tiles.get_parent() as Control).get_global_rect().get_center().x) <= 1,"object page cards are centred")
			var fill: Color = (first.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
			for item: BaseButton in children: check((item.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == fill,"selected and inactive object cards share the fill")

func menu_reviews() -> void:
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions; root.content_scale_size = dimensions
		await fixture()
		var retained: EditorButton = app.editor_context.get_child(0)
		var old_caption: Label = retained.find_child("ToolCaption",true,false)
		retained.remove_child(old_caption); old_caption.queue_free(); retained.set("_caption_label",null)
		retained.queue_redraw(); await frames(5)
		var restored: Label = retained.find_child("ToolCaption",true,false)
		check(restored != null and restored.is_visible_in_tree() and not restored.text.is_empty(),"an existing tool recovers a missing caption after redraw")
		var legacy: ScrollContainer = app.editor_map_panel.find_child("EditorMenuScroll",true,false)
		legacy.name = "LegacyMenuScroll"
		var unchanged: Dictionary = app.document.duplicate(true)
		preload("res://editor/editor_layout.gd").refresh(app,"road")
		preload("res://editor/editor_layout.gd").arrange(app)
		check(app.document == unchanged and app.canvas.is_inside_tree(),"partial reload tolerates an older menu tree without changing the track")
		legacy.name = "EditorMenuScroll"
		app.editor_map_panel.show(); await frames(8); await shot("12-document-menu-"+str(dimensions.x))
		check(app.editor_map_panel.get_global_rect().end.y <= (app.root_ui.find_child("EditorToolDock",true,false) as Control).get_global_rect().position.y-8,"document menu clears the footer")
		var commands: ScrollContainer = app.editor_map_panel.find_child("EditorMenuScroll",true,false)
		commands.scroll_vertical = 10000; await frames(5); await shot("22-document-menu-scrolled-"+str(dimensions.x))
		var publish_caption: Label = app.publish_button.find_child("ToolCaption",true,false)
		check(publish_caption != null and contrast(publish_caption.get_theme_color("font_color"),EditorStyle.TILE) >= 4.5,"disabled Publish label stays readable")
		app.editor_map_panel.hide()
		app._editor_category("paint"); app.editor_tools_panel.show(); await frames(8)
		await shot("13-brush-options-"+str(dimensions.x))
		check(root.get_visible_rect().encloses(app.editor_tools_panel.get_global_rect()),"brush options stay inside viewport")
		check(app.editor_tools_panel.get_global_rect().end.y <= (app.root_ui.find_child("EditorToolDock",true,false) as Control).get_global_rect().position.y-8,"brush menu clears the footer")
		app.canvas.paint_mode = "area"; app._build_editor_tools(); app.editor_tools_panel.show(); await frames(8)
		await shot("14-area-options-"+str(dimensions.x))
		check(root.get_visible_rect().encloses(app.editor_tools_panel.get_global_rect()),"area options stay inside viewport")
		check(app.editor_tools_panel.get_global_rect().end.y <= (app.root_ui.find_child("EditorToolDock",true,false) as Control).get_global_rect().position.y-8,"area menu clears the footer")
		var options_scroll: ScrollContainer = app.editor_tools_panel.find_child("EditorMenuScroll",true,false)
		options_scroll.scroll_vertical = 10000; await frames(5)
		await shot("21-area-options-scrolled-"+str(dimensions.x))
		app.editor_tools_panel.hide()
		app._editor_category("objects"); await frames(6); (app.root_ui.find_child("ObjectSnap",true,false) as OptionButton).show_popup(); await frames(6)
		check((app.root_ui.find_child("ObjectSnap",true,false) as OptionButton).get_popup().visible,"snap dropdown is visibly open")
		check((app.root_ui.find_child("ObjectSnap",true,false) as OptionButton).get_popup().get_theme_color("font_color").a == 1,"snap menu text is opaque")
		await shot("15-snap-menu-"+str(dimensions.x)); (app.root_ui.find_child("ObjectSnap",true,false) as OptionButton).get_popup().hide()
		app.object_browser.choose("rock"); await frames(6); (app.root_ui.find_child("ObjectVariant",true,false) as OptionButton).show_popup(); await frames(6)
		check((app.root_ui.find_child("ObjectVariant",true,false) as OptionButton).get_popup().visible,"variant dropdown is visibly open")
		await shot("16-object-variants-"+str(dimensions.x)); (app.root_ui.find_child("ObjectVariant",true,false) as OptionButton).get_popup().hide()
		app.object_browser.choose("container"); await frames(6)
		var colour: ColorPickerButton = app.root_ui.find_child("ContainerColour",true,false)
		var caption: Label = colour.find_child("ToolCaption",true,false)
		check(caption != null and caption.is_visible_in_tree() and not caption.text.is_empty(),"Colour has a visible native caption")
		var surface: StyleBox = colour.get_theme_stylebox("normal")
		var preview := Rect2(surface.get_offset(),colour.size-surface.get_minimum_size())
		check(not preview.intersects(caption.get_rect()),"native colour swatch cannot paint over its caption")
		check(not colour.accessibility_name.is_empty(),"colour selector retains its accessible name")
		await shot("23-colour-caption-"+str(dimensions.x))
		await click_named("ContainerColour"); await frames(8)
		await shot("17-container-colours-"+str(dimensions.x)); (app.root_ui.find_child("ContainerColour",true,false) as ColorPickerButton).get_popup().hide()
		await fixture(); app._open_object_population(); await frames(8)
		var population: ObjectPopulationPanel = app.object_population_panel
		check(population != null,"population menu opens")
		if population != null:
			var deadline: int = Time.get_ticks_msec()+10000
			while not population.ready_to_apply and Time.get_ticks_msec()<deadline: await frames(3)
			await shot("18-population-"+str(dimensions.x)); population.cancel_requested.emit(); await frames(6)
		app._editor_help(); await frames(8); await shot("19-editor-help-"+str(dimensions.x)); close_review_dialogs(); await frames(6)
		app._share_dialog(); await frames(8); await shot("20-share-menu-"+str(dimensions.x)); close_review_dialogs(); await frames(6)
		app._export_file(); await frames(8); dialog_bounds("export"); await shot("24-export-dialog-"+str(dimensions.x)); close_review_dialogs(); await frames(6)
		app._import_dialog(); await frames(8); dialog_bounds("import"); await shot("25-import-dialog-"+str(dimensions.x)); close_review_dialogs(); await frames(6)
		app._request_editor_exit(); await frames(8); await shot("26-unsaved-exit-"+str(dimensions.x)); close_review_dialogs(); await frames(6)

func dialog_bounds(context: String) -> void:
	var found: bool = false
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog and child.visible:
			found = true
			check(root.get_visible_rect().encloses(Rect2(Vector2(child.position),Vector2(child.size))),context+" dialog stays inside the short viewport")
			if child is FileDialog: check(child.display_mode == FileDialog.DISPLAY_LIST,"file names use the readable list layout")
	check(found,context+" review dialog is visibly open")

func close_review_dialogs() -> void:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: child.queue_free()

func contrast(a: Color, b: Color) -> float:
	var first: Color = a.srgb_to_linear(); var second: Color = b.srgb_to_linear()
	var x: float = first.r*0.2126+first.g*0.7152+first.b*0.0722
	var y: float = second.r*0.2126+second.g*0.7152+second.b*0.0722
	return (maxf(x,y)+0.05)/(minf(x,y)+0.05)

func run() -> void:
	out = ProjectSettings.globalize_path("res://../docs/evidence/editor-finish-2026-11-17/"+("before" if "--before" in OS.get_cmdline_user_args() else RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(out)
	OS.set_environment("BMT_API_URL",""); OS.set_environment("BMT_DEV_AUTH_KEY","")
	root.size=Vector2i(1280,720); root.content_scale_size=root.size; root.gui_embed_subwindows=true
	app=load("res://core/app.tscn").instantiate()
	var storage: String = ProjectSettings.globalize_path("res://../build/editor-finish-2026-11-17/"+str(OS.get_process_id()))
	app.library=TrackLibrary.new(storage.path_join("tracks")); app.records=LocalRecords.new(storage.path_join("records.json")); app.cloud_root_override=storage.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+90000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"isolated offline App starts")
	if app.startup_complete:
		if "--menus-only" in OS.get_cmdline_user_args(): await menu_reviews()
		else:
			await captures(); await menu_reviews(); await document_flow(); await object_flow()
	await settle(); app.queue_free(); await frames(8)
	if is_instance_valid(GameSoundtrack.instance()): GameSoundtrack.instance().queue_free()
	await frames(3); await create_timer(0.3).timeout
	var file := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":fixture_checks,"failures":fixture_failures,"renderer":RenderingServer.get_current_rendering_method(),"measurements":measurements},"\t")); file.close()
	print("EDITOR_FINISH ",fixture_checks," checks / ",fixture_failures," failures")
	quit(0 if fixture_failures == 0 else 1)
