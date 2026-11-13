extends SceneTree
## Isolated geometry, native raster and lifecycle checks for the tiny podium cars.
const Preview = preload("res://ui/rivalry_simple_car.gd")
const IDS: Array[String] = ["compact","super_rally","electric","kart","forklift","hovercraft"]
var checks: int = 0
var failures: int = 0
var evidence: String = OS.get_environment("BMT_SIMPLE_CARS_EVIDENCE")
var measurements: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",label)

func run() -> void:
	root.size = Vector2i(1200,610)
	var backdrop := ColorRect.new()
	backdrop.color = Color("172b3b")
	backdrop.size = Vector2(1200,610)
	root.add_child(backdrop)
	var baseline_draws: int = 0
	if DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		baseline_draws = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var shapes: Array[String] = []
	var views: Array[Control] = []
	for index: int in range(IDS.size()):
		var preview: Control = Preview.new()
		preview.vehicle_id = IDS[index]
		preview.position = Vector2(20+(index%3)*400,40+(index/3)*300)
		preview.size = Vector2(360,230)
		preview.livery = {"colors":{"body":"be4d32","accent":"d8c9a6","detail":"a0adb3"}}
		var original: Dictionary = preview.livery.duplicate(true)
		var began: int = Time.get_ticks_usec()
		root.add_child(preview)
		var built_us: int = Time.get_ticks_usec()-began
		check(preview.presentation_ready,IDS[index]+" prepares synchronously")
		check(preview.triangle_count > 24 and preview.triangle_count <= 600,IDS[index]+" bounded tiny model")
		check(preview.canvas_triangle_count<1600,IDS[index]+" bounded canvas fill and antialias geometry")
		check(preview.get_child_count()==0 and not preview.is_processing(),IDS[index]+" needs no 3D resources or frame processing")
		check(preview.livery==original,IDS[index]+" preserves appearance data")
		var signature: String = var_to_bytes(preview.faces).hex_encode().sha256_text()
		check(signature not in shapes,IDS[index]+" has a distinct silhouette")
		shapes.append(signature)
		measurements.append({"vehicle":IDS[index],"triangles":preview.triangle_count,"canvas_triangles":preview.canvas_triangle_count,"visible_faces":preview.faces.size(),"build_us":built_us})
		var label := Label.new()
		label.text = IDS[index].to_upper()
		label.position = preview.position+Vector2(120,225)
		root.add_child(label)
		views.append(preview)
	for _frame: int in range(4): await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)-baseline_draws
		print("SIMPLE_CAR_DRAW_WORK ",JSON.stringify({"six_models_and_labels":draws}))
		check(draws>0 and draws<=18,"six models and labels retain bounded canvas draw work")
		var picture: Image = root.get_texture().get_image()
		for preview: Control in views:
			var colored: int = 0
			var paint: int = 0
			var crop: Image = picture.get_region(Rect2i(preview.get_global_rect()))
			for y: int in range(crop.get_height()):
				for x: int in range(crop.get_width()):
					var pixel: Color = crop.get_pixel(x,y)
					if pixel.r>pixel.b*1.4 and pixel.r>0.25: paint += 1
					if absf(pixel.r-backdrop.color.r)+absf(pixel.g-backdrop.color.g)+absf(pixel.b-backdrop.color.b)>0.15: colored += 1
			check(colored>1000 and paint>100,preview.vehicle_id+" renders a visible coloured model")
		if not evidence.is_empty():
			DirAccess.make_dir_recursive_absolute(evidence)
			check(picture.save_png(evidence.path_join("models-"+RenderingServer.get_current_rendering_method()+".png"))==OK,"save six-model native gallery")
	for preview: Control in views:
		var original: String = var_to_bytes(preview.faces).hex_encode().sha256_text()
		preview.size = Vector2(160,88)
		check(preview.presentation_ready and original==var_to_bytes(preview.faces).hex_encode().sha256_text(),"resizing fits retained geometry")
		preview.hide()
		preview.free()
	await process_frame
	print("SIMPLE_CAR_METRICS ",JSON.stringify(measurements))
	print("RIVALRY_SIMPLE_CARS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
