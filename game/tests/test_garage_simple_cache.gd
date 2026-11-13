extends SceneTree
## GSM03: quality pins, distinct pictures and the specialized capture renderer.
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("GARAGE_SIMPLE_CACHE_FAIL ",label)
func run() -> void:
	root.size=Vector2i(1280,720)
	var cache: Node=load("res://ui/garage_preview_cache.gd").new();root.add_child(cache);cache.set_process(false)
	var old_cache: Node=load("res://../docs/evidence/garage-simple-models-2026-11-07/before/game/ui/garage_preview_cache.gd").new()
	for id: String in VehicleCatalog.IDS:
		var view: CarShowroom=load("res://ui/garage_cached_thumbnail.gd").new()
		view.simple_model=false;view.vehicle_id=id;view.preview_service=cache;view.size=Vector2(300,100)
		view.livery=VehicleLivery.defaults(id);view.customisation=VehicleCustomisation.defaults()
		root.add_child(view)
		var standard: String=cache.identity(view)
		check(standard==old_cache.identity(view),"standard cache identity layout remains compatible "+id)
		check(not cache._default(view) and view.displayed_key.is_empty(),"detailed references cannot reuse reduced catalogue pictures "+id)
		var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
		image.fill(Color.RED)
		var texture: Texture2D=ImageTexture.create_from_image(image)
		cache.prepared_picture={"vehicle":id,"paint":view.livery.duplicate(true),"condition":{},"parts":view.customisation.duplicate(true),"texture":texture}
		view.apply_model_quality(true)
		check(view.preview_key!=standard and cache._default(view),"reduced view has a distinct identity and uses production catalogue "+id)
		check(view.displayed_key==view.preview_key and view._image.texture!=texture,"old standard prepared picture cannot replace reduced catalogue "+id)
		view.livery.colors.body="1981af";view.refresh_thumbnail()
		check(not cache.queued.is_empty() and cache.queued.back().simple,"custom capture retains reduced quality "+id)
		cache.prepared_picture.paint=view.livery.duplicate(true)
		check(not cache._current({"view":weakref(view),"key":standard}),"old completion cannot publish across qualities "+id)
		cache.prepared_picture.simple=true
		view.refresh_thumbnail()
		check(view.displayed_key==view.preview_key,"matching prepared quality can publish "+id)
		view.apply_model_quality(false)
		check(not cache._default(view) and view.displayed_key.is_empty(),"detailed offline reference cannot borrow reduced picture "+id)
		view.free();cache.queued.clear();cache.prepared_picture={}
	var records:=LocalRecords.new("user://cache-quality-records.json")
	records.settings.reduced_car_models=true;cache.warm_records(records,false)
	for id: String in cache.warm_views:check(cache.warm_views[id].simple_model,"background picture warming follows selected quality "+id)
	var renderer: CarShowroom=cache._make_renderer();renderer.simple_model=true;renderer.vehicle_id="compact"
	renderer.size=Vector2(600,300);root.add_child(renderer)
	while not renderer.showroom_ready:await process_frame
	check(renderer.car.simple_model,"actual specialized thumbnail renderer constructs reduced car")
	renderer.queue_free();cache.queue_free();old_cache.free()
	await process_frame
	print("GARAGE_SIMPLE_CACHE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
