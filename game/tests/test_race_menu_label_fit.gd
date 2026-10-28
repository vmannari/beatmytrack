extends SceneTree
## Check native label rectangles against their actual pause-menu button bounds.
var checks: int = 0
var failures: int = 0
var samples: Array[Dictionary] = []
var output: String
var resumes: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frames() -> void:
	for index: int in range(12): await process_frame

func run() -> void:
	output = OS.get_environment("BMT_RACE_MENU_LABEL_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var hud := PlaygroundHUD.new()
	hud.pause_requested.connect(func() -> void: resumes += 1)
	var menu: Control = load("res://ui/race_pause_menu.gd").new()
	menu.hud = hud
	root.add_child(menu)
	for locale: String in ["en","fi","de","ja","ko"]:
		GameFonts.configure(locale)
		TranslationServer.set_locale(locale)
		for dimensions: Vector2i in [Vector2i(1280,914),Vector2i(1024,768),Vector2i(1280,720),Vector2i(960,540)]:
			root.size = dimensions
			menu.show_main()
			await frames()
			for button: Node in menu.column.get_children():
				if not button is Button: continue
				var bounds: Rect2 = button.get_global_rect()
				var labels: Array[Dictionary] = []
				for label: Node in button.find_children("*","Label",true,false):
					var rect: Rect2 = label.get_global_rect()
					check(bounds.grow(0.5).encloses(rect),"%s %s %s label %s inside button" % [locale,dimensions,button.name,label.text])
					check(rect.position.y >= bounds.position.y+8 and rect.end.y <= bounds.end.y-8,"%s %s %s label retains vertical padding" % [locale,dimensions,button.name])
					labels.append({"text":label.text,"rect":str(rect)})
				samples.append({"locale":locale,"size":str(dimensions),"button":button.name,"bounds":str(bounds),"labels":labels})
			if not output.is_empty() and DisplayServer.get_name() != "headless" and dimensions == Vector2i(1280,914):
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("pause-"+locale+"-1280x914.png")) == OK,"capture "+locale)
		# The same race menu serves the parking hall, whose real subtitle wraps.
		hud.free_drive_mode = true
		menu.show_main()
		await frames()
		var restart: Button = menu.find_child("Restart",true,false)
		for label: Node in restart.find_children("*","Label",true,false):
			check(restart.get_global_rect().grow(0.5).encloses(label.get_global_rect()),"%s wrapped parking-hall subtitle inside Restart" % locale)
		hud.free_drive_mode = false
	# Taps on the text must still reach the native Button through its content.
	TranslationServer.set_locale("en")
	menu.show_main()
	await frames()
	var resume: Button = menu.find_child("Resume",true,false)
	var caption: Label = resume.find_children("*","Label",true,false)[0]
	for down: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = caption.get_global_rect().get_center()
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	check(resumes == 1,"touching Resume text activates the button once")
	menu._help()
	await frames()
	var back: Button = menu.find_child("Back",true,false)
	for label: Node in back.find_children("*","Label",true,false):
		check(back.get_global_rect().grow(0.5).encloses(label.get_global_rect()),"Help Back label inside button")
	menu.queue_free()
	hud.free()
	await process_frame
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"))
	print("RACE_MENU_LABEL_FIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
