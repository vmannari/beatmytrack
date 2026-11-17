extends SceneTree
## PCS01-PCS03: deterministic PNG fixtures isolate read scheduling from model edits.
const Icons = preload("res://ui/header_car_icons.gd")
var checks: int = 0
var failures: int = 0
var output: String
var legacy: bool = false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",label)
func frames(count: int = 4) -> void:
	for _frame: int in range(count): await process_frame
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output=arg.trim_prefix("--evidence-root=")
		if arg=="--legacy-read-gate": legacy=true
	DirAccess.make_dir_recursive_absolute(output)
	Icons.customized.clear()
	var folder: String="user://startup-pictures-"+TrackLibrary.unique_id()
	var records:=LocalRecords.new(folder.path_join("records.json"))
	var paints: Dictionary={}
	for id: String in ["compact","kart"]:
		var paint: Dictionary=VehicleLivery.defaults(id)
		paint.colors.body="3388aa"
		paints[id]=paint
	records.settings={"vehicle_liveries":paints}
	# App is a policy owner only: no network, player saves or showroom starts.
	var policy: Node=load("res://core/app.gd").new()
	policy.cloud_starting=true
	policy._publishing_slots_foreground=false
	var cache: Node=load("res://ui/header_car_appearance_cache.gd").new()
	cache.allowed=policy._header_car_work_allowed
	if not legacy: cache.read_allowed=policy._header_car_read_allowed
	cache.capture_allowed=func(_id: String) -> bool: return false
	root.add_child(cache)
	var directory: String=folder.path_join("header_appearance_icons")
	DirAccess.make_dir_recursive_absolute(directory)
	var fixtures: Dictionary={}
	for id: String in ["compact","kart"]:
		# Synthetic PNGs prove exact IO/publication, not car appearance.
		var image:=Image.create(Icons.SIZE.x,Icons.SIZE.y,false,Image.FORMAT_RGBA8)
		image.fill(Color("3388aa") if id=="compact" else Color("ddaa33"))
		fixtures[id]=image.get_data()
		check(image.save_png(directory.path_join(Icons.appearance_key(id,records)+".png"))==OK,"save private PNG fixture "+id)
	var shared: Node=load("res://ui/garage_shared_pictures.gd").new()
	shared.records=records
	shared.header_cache=cache
	root.add_child(shared)
	VehicleCatalog.selected="kart"
	var header: Control=load("res://ui/profile_car.gd").new()
	header.records=records
	root.add_child(header)
	cache.changed.connect(func(_id: String) -> void: header.refresh())
	var cards: Dictionary={}
	for id: String in ["compact","kart"]:
		var card: Control=load("res://ui/garage_cached_thumbnail.gd").new()
		card.vehicle_id=id
		card.livery=VehicleLivery.for_car(records.settings,id)
		card.customisation=VehicleCustomisation.for_car(records.settings,id)
		card.preview_service=shared
		root.add_child(card)
		cards[id]=card
	cache.bind_records(records)
	await frames()
	check(not policy._header_car_read_allowed() and cache._io==null and cache.disk_hits==0,"backgrounded startup dispatches no PNG read")
	policy._publishing_slots_foreground=true
	policy.game=Node.new()
	check(not policy._header_car_read_allowed(),"active game blocks picture reads")
	policy.game.free(); policy.game=null
	policy._feature_loading=CanvasLayer.new()
	check(not policy._header_car_read_allowed(),"feature loading blocks picture reads")
	policy._feature_loading.free(); policy._feature_loading=null
	policy.race_loading=load("res://ui/race_loading.gd").new()
	check(not policy._header_car_read_allowed(),"race loading blocks picture reads")
	policy.race_loading.free(); policy.race_loading=null
	check(policy._header_car_read_allowed() and not policy._header_car_work_allowed(),"startup and menu data permit only disk picture work")
	cache.resume_pending()
	var deadline: int=Time.get_ticks_msec()+5000
	while not cache.reads_idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(Icons.ready("compact",records) and Icons.ready("kart",records),"cached pictures restore while startup and menu data remain blocked")
	# The former gate can finish too; it must fail precisely the earlier-read check.
	policy.startup_complete=true
	policy.cloud_starting=false
	cache.resume_pending()
	deadline=Time.get_ticks_msec()+5000
	while not cache.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(cache.idle() and cache.disk_hits==2,"both saved PNGs restored")
	check(cache.captures==0 and cache.peak_worlds==0 and cache.canvas==null,"restoration constructs no native picture studio")
	for id: String in ["compact","kart"]:
		var texture: Texture2D=Icons.texture(id,records)
		check(cards[id]._image.texture==texture,"carousel uses the shared texture "+id)
		if texture!=null:
			var image: Image=texture.get_image()
			image.clear_mipmaps()
			check(image.get_data()==fixtures[id],"decoded PNG pixels exact "+id)
	check(header.preview.texture==cards.kart._image.texture,"profile and selected carousel card hold the same texture object")
	check(shared.renders==0 and shared.renderer==null,"carousel creates no separate picture renderer")
	var report: Dictionary={"checks":checks,"failures":failures,"legacy_read_gate":legacy,"disk_hits":cache.disk_hits,"captures":cache.captures,"carousel_renders":shared.renders}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for card: Control in cards.values(): card.queue_free()
	header.queue_free(); shared.queue_free(); cache.queue_free()
	await frames()
	policy.free()
	print("PROFILE_PICTURE_STARTUP ",JSON.stringify(report))
	quit(1 if failures else 0)
