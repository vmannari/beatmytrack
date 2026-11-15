extends "res://tests/capture_garage_carousel_space.gd"
## G5K01-G5K02: real visible-card counts and native suit in stock/custom pictures.
const Renderer = preload("res://ui/header_icon_renderer.gd")
const PictureCache = preload("res://ui/header_car_appearance_cache.gd")
var _kart_reviewed: bool = false

func old_key(vehicle: String, records: LocalRecords) -> String:
	return JSON.stringify([Icons.VERSION,Icons._visual_revision,RenderingServer.get_current_rendering_method(),records.path,vehicle,VehicleLivery.for_car(records.settings,vehicle),VehicleCustomisation.for_car(records.settings,vehicle)],"",true).sha256_text()

func inspect_suit(cache: Node, state: Dictionary) -> void:
	if state.checked or not is_instance_valid(cache.studio) or not cache.studio.presentation_ready: return
	state.checked = true
	var native_code: String = Renderer.DRIVER_CLOTH.code
	var start: int = native_code.find("void fragment()")
	var end: int = native_code.find("ALBEDO =")
	var garment: String = native_code.substr(start,end-start)
	var count: int = 0
	for part: MeshInstance3D in cache.studio.car.find_children("*","MeshInstance3D",true,false):
		for surface: int in range(part.mesh.get_surface_count() if part.mesh!=null else 0):
			var material: Material = part.get_active_material(surface)
			if material!=null and material.resource_name=="RT_DriverSuit":
				count += 1
				check(material is ShaderMaterial and material.shader==Renderer.cloth_picture_shader(),"runtime picture binds the garment shader")
				check(material.shader.code.contains(garment),"all native suit pigment, panels, seams, zip, weave and relief retained exactly")
	check(count>0,"actual customised capture contains the driver garment")
	state.surfaces = count

func shot(label: String) -> void:
	await super.shot(label)
	var visible: int = 0
	for card: Control in page.cards.get_children():
		if page.gallery.get_global_rect().grow(0.5).encloses(card.get_global_rect()): visible += 1
	var expected: int = 4 if root.size.x==960 else 5
	check(visible==expected,"complete visible car count "+label+": "+str(visible))
	check(page.preview.size.y >= (269 if root.size.x==960 else 423),"larger live 3D area retained "+label)
	observations.layout[label].visible_cards = visible
	if label!="stock-1280" or _kart_reviewed: return
	_kart_reviewed = true
	page.preview_car(1)
	page.showroom.finish_car_transition()
	page.gallery.scroll_horizontal = 0
	await frames(12)
	var live_suits: int = 0
	for part: MeshInstance3D in page.showroom.car.find_children("*","MeshInstance3D",true,false):
		for surface: int in range(part.mesh.get_surface_count() if part.mesh!=null else 0):
			var material: Material = part.get_active_material(surface)
			if material is ShaderMaterial and material.shader==Renderer.DRIVER_CLOTH: live_suits += 1
	check(live_suits>0,"live Garage still uses its original native suit")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("kart-live-and-shared-picture.png"))==OK,"capture native live Kart beside the corrected carousel picture")
	var records := LocalRecords.new("user://kart-picture-"+TrackLibrary.unique_id()+"/records.json")
	var paint: Dictionary = VehicleLivery.defaults("kart")
	paint.colors.body = "22879d"
	records.settings.vehicle_liveries = {"kart":paint}
	for vehicle: String in VehicleCatalog.IDS:
		check((Icons.appearance_key(vehicle,records)!=old_key(vehicle,records))==(vehicle=="kart"),"only Kart invalidates the former picture version "+vehicle)
	var pixels := Image.create(Icons.SIZE.x,Icons.SIZE.y,false,Image.FORMAT_RGBA8)
	var obsolete: String = old_key("kart",records)
	Icons.customized[obsolete] = ImageTexture.create_from_image(pixels)
	check(not Icons.ready("kart",records),"old plain-suit cache cannot satisfy the new Kart look")
	var cache: Node = PictureCache.new()
	cache.allowed = func() -> bool: return true
	root.add_child(cache)
	var state: Dictionary = {"checked":false,"surfaces":0}
	var observer: Callable = inspect_suit.bind(cache,state)
	RenderingServer.frame_pre_draw.connect(observer)
	cache.bind_records(records)
	await wait_for(func() -> bool: return Icons.ready("kart",records),"custom Kart picture completes with the native garment")
	RenderingServer.frame_pre_draw.disconnect(observer)
	check(state.checked and state.surfaces>0,"actual runtime capture inspected")
	check(cache.captures==1,"one custom Kart capture")
	var custom: Texture2D = Icons.texture("kart",records)
	check(custom!=null and custom.get_size()==Vector2(Icons.SIZE),"customised Kart stays sharp at shared picture size")
	var image: Image = custom.get_image()
	image.clear_mipmaps()
	check(image.save_png(output.path_join("kart-custom-picture.png"))==OK,"save corrected customised Kart picture")
	cache.request_pictures(records)
	await frames()
	check(cache.captures==1 and Icons.texture("kart",records)==custom,"warm custom Kart reuses the same image")
	Icons.customized.erase(obsolete)
	cache.queue_free()
	await frames()
	observations.kart_runtime_suit_surfaces = state.surfaces
