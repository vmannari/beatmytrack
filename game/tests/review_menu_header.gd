extends "res://tests/test_shared_menu_header.gd"
## MHR01: compare real header geometry before choosing a shared control height.
var measurements: Array[Dictionary] = []

func set_height(height: int) -> void:
	var header: Control = app.root_ui.find_child("MenuHeader",true,false)
	var brand: Control = header.get_child(0)
	brand.custom_minimum_size.y = height
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tabs: Control = header.get_node("MenuNavigation")
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var buttons: Array[Button] = []
	for tab: Button in tabs.get_children(): buttons.append(tab)
	buttons.append(app.account_button)
	buttons.append(header.get_node("MenuSettings"))
	for button: Button in buttons:
		button.custom_minimum_size.y = height
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for state: String in ["normal","hover","pressed","disabled","focus"]:
			var source: StyleBox = button.get_theme_stylebox(state)
			if not source is StyleBoxFlat: continue
			var style: StyleBoxFlat = source.duplicate()
			style.content_margin_top = (height-36)*0.5
			style.content_margin_bottom = (height-36)*0.5
			button.add_theme_stylebox_override(state,style)
	header.get_node("MenuSettings").custom_minimum_size.x = height
	var picture: Control = app.account_button.get_node("MenuProfileCar")
	picture.offset_top = -minf(24,height*0.5-4)
	picture.offset_bottom = minf(24,height*0.5-4)

func record(label: String) -> void:
	var header: Control = app.root_ui.find_child("MenuHeader",true,false)
	var nodes: Dictionary = {"header":header,"logo":header.get_child(0),"account":app.account_button,"settings":header.get_node("MenuSettings"),"wallet":header.get_node("GarageHeaderWallet"),"car":app.account_button.get_node("MenuProfileCar")}
	for tab: Button in header.get_node("MenuNavigation").get_children(): nodes[tab.name] = tab
	var item: Dictionary = {"label":label,"viewport":var_to_str(root.size),"components":{}}
	for key: String in nodes:
		var control: Control = nodes[key]
		var rect: Rect2 = control.get_global_rect()
		item.components[key] = {"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y,"center_y":rect.get_center().y}
	measurements.append(item)
	if DisplayServer.get_name() != "headless":
		var picture: Image = root.get_texture().get_image().get_region(Rect2i(0,0,root.size.x,110))
		check(picture.save_png(output.path_join(label+".png")) == OK,"header comparison "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = "res://../docs/evidence/top-menu-sizing-2026-11-15/review"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = "user://menu-header-review-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings = {"music_enabled":false,"selected_car":"compact","tutorial_complete":true}
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.race_area_mode = "free"
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		app._show_screen("tracks")
		app._finish_menu_page_slide()
		await settle(12)
		record("before-"+str(dimensions.x))
		for height: int in [52,56,60,64]:
			set_height(height)
			await settle(4)
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(2,root.size.y-2)
			root.push_input(motion,true)
			await settle(2)
			check_header("tracks",str(height)+"px/"+str(dimensions.x))
			record(str(height)+"px-"+str(dimensions.x))
		if dimensions.x == 960:
			var account_text: String = app.account_button.text
			var wallet: Control = app.root_ui.find_child("GarageHeaderWallet",true,false)
			app.account_button.text = "LongDriverName_123456789012345678901234567"
			wallet._amount.text = "1,234,567"
			set_height(56)
			await settle(4)
			record("long-name-balance-960")
			app.account_button.text = account_text
			wallet._balance()
	FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	app.queue_free()
	await settle(20)
	print("MENU_HEADER_HEIGHT_REVIEW ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
