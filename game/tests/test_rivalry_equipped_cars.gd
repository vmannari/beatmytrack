extends SceneTree
## Same pigments with different wraps/stickers/kits must produce different cars.
const Preview = preload("res://ui/rivalry_simple_car.gd")
var checks: int = 0
var failures: int = 0
var evidence: String
var metrics: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",label)
func drawn() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func difference(a: Image,b: Image) -> int:
	var count: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var first: Color = a.get_pixel(x,y)
			var second: Color = b.get_pixel(x,y)
			if absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b)+absf(first.a-second.a)>0.12: count += 1
	return count

func render(id: String,value: Dictionary,parts: Dictionary) -> Control:
	var preview: Control = Preview.new()
	preview.vehicle_id = id
	preview.livery = value.duplicate(true)
	preview.customisation = parts.duplicate(true)
	preview.size = Vector2(320,200)
	root.add_child(preview)
	var began: int = Time.get_ticks_msec()
	while not preview.presentation_ready and Time.get_ticks_msec()-began<15000: await process_frame
	check(preview.presentation_ready,id+" actual equipped model becomes ready")
	# The forklift's sticker is on its rear engine cover, behind the mast view.
	if id=="forklift":
		preview.car.rotation.y = 0
		preview._refresh()
	for _frame: int in range(3): await drawn()
	check(preview.car.livery==value and preview.car.customisation==parts,id+" renders the complete normalized appearance")
	check(preview.find_children("*","Light3D",true,false).is_empty() and preview.find_children("*","WorldEnvironment",true,false).is_empty(),id+" needs no light or radiance world")
	check(preview.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,id+" freezes after its first draw")
	check(not preview.is_processing() and not preview.is_physics_processing(),id+" has no ongoing frame callback")
	for binding: Dictionary in preview.car.graphics.bindings:
		var active: ShaderMaterial = binding.node.get_active_material(binding.index) as ShaderMaterial
		check(active != null and active.shader==Preview.FINISH,id+" uses the bounded preview finish")
		if not VehicleLivery.decorated(value,id): continue
		for uniform: String in ["mesh_to_body","pattern_enabled","livery_mask","livery_body","livery_accent","livery_detail","hood_emblem","roof_emblem","hood_sticker","roof_sticker","graphic_bounds","panel_levels","rear_sticker"]:
			check(active.get_shader_parameter(uniform)==binding.finish.get_shader_parameter(uniform),id+" retains production livery uniform "+uniform)
	return preview

func run() -> void:
	evidence = OS.get_environment("BMT_RIVALRY_CARS_EVIDENCE_DIR")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	if DisplayServer.get_name()=="headless": quit(1); return
	for id: String in VehicleCatalog.IDS:
		var plain: Dictionary = VehicleLivery.defaults(id)
		var stock: Dictionary = VehicleCustomisation.defaults()
		var equipped: Dictionary = stock.duplicate(true)
		for category: String in VehicleCustomisation.CATEGORIES:
			var options: Array = VehicleCustomisation.options(category,id)
			equipped[category] = options[mini(3,options.size()-1)][0]
		# Carbon is deliberately unpainted in production and has no hood decal.
		if id=="electric": equipped.hood = "volt_centre"
		var decorated: Dictionary = plain.duplicate(true)
		decorated.pattern = "apex_twin"
		var sticker: Dictionary = plain.duplicate(true)
		sticker.stickers.hood.id = str(LiveryCatalog.stickers[3].id)
		sticker.stickers.hood.size = 0.95
		sticker.stickers.roof.id = str(LiveryCatalog.stickers[4].id)
		sticker.stickers.roof.size = 0.95
		var views: Array[Control] = []
		var images: Array[Image] = []
		for appearance: Array in [[plain,stock],[plain,equipped],[decorated,equipped],[sticker,equipped]]:
			var preview: Control = await render(id,appearance[0],appearance[1])
			images.append(preview.viewport.get_texture().get_image())
			preview.position.x = views.size()*320
			views.append(preview)
		var kit_pixels: int = difference(images[0],images[1])
		var wrap_pixels: int = difference(images[1],images[2])
		var sticker_pixels: int = difference(images[1],images[3])
		check(kit_pixels>100,id+" fitted kits visibly replace stock geometry")
		check(wrap_pixels>100,id+" wrap visibly changes the same paints and kits")
		if id=="electric":
			# The reference fastback was lowered below the existing production
			# sticker cutoffs. Preserve the real mapping, rather than inventing
			# a Rivalry-only decal position that disagrees with Garage/races.
			var projection: Dictionary = LiveryCatalog.projection(id)
			var maximum: float = 0.0
			for u: int in range(21):
				for v: int in range(21): maximum = maxf(maximum,preload("res://vehicle/electric_kits.gd").formed_hood_point(1,u/20.0,v/20.0).y)
			check(maximum<projection.levels.x and preload("res://vehicle/electric_reference_cabin.gd").roof_height(0.5)<projection.levels.y,"Electric current production surfaces remain below their existing sticker cutoffs")
			check(sticker_pixels==0,"Electric preview retains the production decal clipping; uniforms are checked separately")
		else: check(sticker_pixels>10,id+" stickers visibly change the same paints and kits")
		views[0]._refresh()
		for _frame: int in range(3): await drawn()
		check(difference(images[0],views[0].viewport.get_texture().get_image())==0,id+" later players cannot alter an existing player's car")
		await drawn()
		check(root.get_texture().get_image().get_region(Rect2i(0,0,1280,200)).save_png(evidence.path_join(id+"-stock-kit-wrap-sticker.png"))==OK,id+" save native appearance comparison")
		metrics.append({"vehicle":id,"parts":equipped,"kit_pixels":kit_pixels,"wrap_pixels":wrap_pixels,"sticker_pixels":sticker_pixels})
		for view: Control in views: view.free()
		await process_frame
	print("EQUIPPED_CAR_METRICS ",JSON.stringify(metrics))
	print("RIVALRY_EQUIPPED_CARS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
