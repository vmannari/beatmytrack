extends VBoxContainer
## Read-only driver overview. Asynchronous results belong to one account.
const Icons = preload("res://ui/header_car_icons.gd")
const Scans = preload("res://persistence/draft_scan.gd")
const Numbers = preload("res://ui/achievement_detail.gd")
const Biomes = preload("res://ui/biome_badge.gd")

class RouteThumbnail extends Control:
	var paths: Array[PackedVector2Array] = []
	var bounds := Rect2()
	func setup(document: Dictionary) -> void:
		paths.clear()
		var pieces: Array = document.get("pieces",[])
		if pieces.size() <= RoadPieces.MAX_PIECES:
			for piece: Variant in pieces:
				if RoadPieces.validate(piece).is_empty(): paths.append(RoadPieces.samples(piece))
		if paths.is_empty():
			var route := PackedVector2Array()
			for point: Variant in document.get("points",[]).slice(0,1024):
				if point is Array and point.size() == 2: route.append(Vector2(float(point[0]),float(point[1])))
			if route.size() >= 2:
				route.append(route[0])
				paths.append(route)
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for path: PackedVector2Array in paths:
			for point: Vector2 in path:
				low = low.min(point)
				high = high.max(point)
		bounds = Rect2(low,(high-low).max(Vector2.ONE)) if low.is_finite() else Rect2()
		queue_redraw()
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		if paths.is_empty():
			draw_texture_rect(MenuIcon.texture("tracks"),Rect2((size-Vector2(30,30))*0.5,Vector2(30,30)),false,MenuStyle.MUTED)
			return
		var scale: float = minf((size.x-16)/bounds.size.x,(size.y-16)/bounds.size.y)
		for path: PackedVector2Array in paths:
			if path.size() < 2: continue
			var points := PackedVector2Array()
			for point: Vector2 in path:
				var offset: Vector2 = (point-bounds.get_center())*scale
				points.append(size*0.5+Vector2(offset.x,-offset.y))
			draw_polyline(points,Color("07121b"),6,true)
			draw_polyline(points,Color("e9ede5"),2.5,true)

var app: Node
var client: Node
var records: LocalRecords
var service: Node
var scope: String
var request_epoch: int = 0
var overview: GridContainer
var fleet: GridContainer
var track_grid: GridContainer
var badge_grid: GridContainer
var track_status: Label
var ranking_status: Label
var track_action: Button
var badge_summary: Label
var fleet_note: Label
var page_body: VBoxContainer
var scroll: ScrollContainer
var collection: Control
var photos: Dictionary = {}
var car_values: Dictionary = {}
var total_values: Dictionary = {}
var remote_cars: Dictionary = {}
var photo_timer: Timer
var track_mode: String = "published"
var published: Array[Dictionary] = []
var drafts: Array[Dictionary] = []
var next_offset: int = 0
var track_busy: bool = false
var track_error: bool = false
var loaded_tracks: bool = false
var draft_scan: RefCounted
var draft_directory: String = ""
var draft_revision: int = -1
var draft_loading: bool = false
var track_tabs: Dictionary = {}
var identity_bar: BoxContainer
var stats_grid: GridContainer

func _ready() -> void:
	set_process(false)
	name = "OwnProfilePage"
	client = app.online.client
	records = app.records
	service = app.achievements
	scope = _scope()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",0)
	page_body = VBoxContainer.new()
	page_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_body.add_theme_constant_override("separation",12)
	add_child(page_body)
	_build_identity()
	_build_stats(identity_bar)
	scroll = preload("res://ui/vertical_swipe_scroll.gd").new()
	scroll.name = "ProfileScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	page_body.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",16)
	scroll.add_child(body)
	_build_fleet(body)
	overview = GridContainer.new()
	overview.name = "ProfileOverview"
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_theme_constant_override("h_separation",16)
	overview.add_theme_constant_override("v_separation",16)
	body.add_child(overview)
	_build_tracks(overview)
	_build_achievements(overview)
	_build_ranking(body)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()
	if client.has_signal("identity_changed"): client.identity_changed.connect(_identity_changed)
	if service != null:
		service.changed.connect(_refresh_badges)
		if service.has_method("refresh"): service.refresh.call_deferred()
	photo_timer = Timer.new()
	photo_timer.wait_time = 1.0
	photo_timer.timeout.connect(_refresh_car_picture)
	add_child(photo_timer)
	photo_timer.start()
	_refresh_car_picture()
	_start_drafts()
	if client.signed_in():
		_load_tracks.call_deferred()
		_load_car_history.call_deferred()
		if preload("res://backend/world_ranking_client.gd").supported(client): _load_ranking.call_deferred()

func _scope() -> String:
	return client.base_url()+"/"+str(client.player.get("id",""))+"/"+str(client.signed_in())

func _active(epoch: int) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and epoch == request_epoch and scope == _scope() and app.records == records

func _identity_changed() -> void:
	if scope == _scope(): return
	request_epoch += 1
	visible = false
	if draft_scan != null: draft_scan.cancel()

func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(overview): return
	var width: float = minf(size.x,get_viewport().get_visible_rect().size.x)-MenuStyle.SCROLLBAR_LANE
	overview.columns = 2 if width >= 880 else 1
	fleet.columns = 5 if width >= 850 else 3 if width >= 560 else 2 if width >= 340 else 1
	badge_grid.columns = 3 if width >= 560 else 1
	track_grid.columns = 1
	identity_bar.vertical = width < 1080
	stats_grid.custom_minimum_size.x = 540 if not identity_bar.vertical else 0
	stats_grid.columns = 4 if width >= 560 else 2
	for picture: TextureRect in photos.values():
		picture.custom_minimum_size.y = minf(128 if width >= 1080 else 112,maxf(100,size.y-460))

func _label(parent: Node, value: String, font_size: int = 18, muted: bool = false) -> Label:
	var label: Label = MenuStyle.label(value,font_size,muted)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _panel(parent: Node, id: String, padding: int = 12) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	var style: StyleBoxFlat = MenuStyle.card(padding)
	style.border_color = Color("29414e")
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",10)
	panel.add_child(box)
	return box

func _action(value: String, callback: Callable) -> Button:
	var button: Button = MenuStyle.button(value,callback)
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size",18)
	return button

func _section(parent: Node, title: String, caption: String, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label: Label = _label(row,title,24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var button: Button = _action(caption,callback)
	button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,8))
	button.add_theme_color_override("font_color",MenuStyle.ACCENT)
	row.add_child(button)
	return button

func _build_identity() -> void:
	identity_bar = BoxContainer.new()
	identity_bar.name = "ProfileHeader"
	identity_bar.add_theme_constant_override("separation",20)
	page_body.add_child(identity_bar)
	var row := HBoxContainer.new()
	row.name = "ProfileIdentity"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",14)
	identity_bar.add_child(row)
	var identity := HBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation",16)
	row.add_child(identity)
	var heading: Label = _label(identity,"PROFILE",34)
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	var driver := HBoxContainer.new()
	driver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	driver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	driver.add_theme_constant_override("separation",8)
	identity.add_child(driver)
	var country: String = str(client.player.get("country_code","")) if client.signed_in() else ""
	if not country.is_empty():
		var flag: Control = PlayerCountry.flag(country,26)
		flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		driver.add_child(flag)
	var title: Label = _label(driver,app.online.player_name() if client.signed_in() else "Guest",26,true)
	title.name = "ProfilePlayerName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	if client.signed_in(): GameText.user_text(title)
	var account: Button = _action("Edit profile" if client.signed_in() else "Sign in",app._open_account)
	account.name = "ManageAccount"
	account.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(account)

func _build_stats(parent: Node) -> void:
	var grid := GridContainer.new()
	stats_grid = grid
	grid.name = "ProfileRacingStats"
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation",18)
	parent.add_child(grid)
	var metrics: Dictionary = AchievementProgress.read(records).metrics
	total_values.races = _stat(grid,Numbers.number(int(metrics.get("races",0))),"Completed races")
	total_values.distance_m = _stat(grid,GameText.message("%.1f km") % (float(metrics.get("distance_m",0))/1000.0),"Distance driven")
	total_values.tracks = _stat(grid,Numbers.number(int(metrics.get("tracks",0))),"Tracks raced")
	total_values.cars = _stat(grid,Numbers.number(int(metrics.get("cars",0))),"Cars raced")
	for number: Label in total_values.values():
		number.add_theme_color_override("font_color",MenuStyle.ACCENT)
	grid.tooltip_text = "Progress recorded on this device; earlier races may not be included."

func _stat(parent: Node, value: String, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",0)
	parent.add_child(box)
	var number: Label = _label(box,value,28)
	_label(box,caption,15,true)
	return number

func _build_fleet(parent: Node) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation",6)
	parent.add_child(section)
	var heading := HBoxContainer.new()
	section.add_child(heading)
	heading.hide()
	var title: Label = _label(heading,"YOUR CARS",24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleet_note = _label(heading,"Recorded on this device",14,true)
	fleet_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	fleet_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fleet_note.tooltip_text = "Progress recorded on this device; earlier races may not be included."
	fleet_note.hide()
	heading.tooltip_text = fleet_note.tooltip_text
	fleet = GridContainer.new()
	fleet.name = "ProfileFleet"
	fleet.columns = 5
	fleet.tooltip_text = fleet_note.tooltip_text
	fleet.add_theme_constant_override("h_separation",10)
	fleet.add_theme_constant_override("v_separation",10)
	section.add_child(fleet)
	for id: String in VehicleCatalog.IDS:
		var box: VBoxContainer = _panel(fleet,"ProfileCar_"+id,1)
		box.add_theme_constant_override("separation",0)
		var picture := TextureRect.new()
		picture.name = "CarPhoto"
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(0,128)
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(picture)
		photos[id] = picture
		var footer := PanelContainer.new()
		var footer_style: StyleBoxFlat = MenuStyle.box(Color("102632"),10)
		footer_style.set_corner_radius_all(0)
		footer_style.border_color = Color("29414e")
		footer_style.border_width_top = 1
		footer.add_theme_stylebox_override("panel",footer_style)
		box.add_child(footer)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",2)
		footer.add_child(content)
		var line := HBoxContainer.new()
		content.add_child(line)
		var car_name: Label = _label(line,VehicleCatalog.title(id),22)
		car_name.add_theme_font_override("font",MenuStyle.DISPLAY)
		car_name.name = "CarName"
		car_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var selected: Label = _label(line,"●",14)
		selected.autowrap_mode = TextServer.AUTOWRAP_OFF
		selected.name = "SelectedCar"
		selected.add_theme_color_override("font_color",MenuStyle.ACCENT)
		selected.tooltip_text = "Current car"
		selected.visible = id == VehicleCatalog.selected
		var values := HBoxContainer.new()
		values.add_theme_constant_override("separation",8)
		content.add_child(values)
		var distance: Label = _stat(values,"—","km driven")
		var races: Label = _stat(values,"—","Races")
		for number: Label in [distance,races]:
			number.add_theme_font_size_override("font_size",24)
			(number.get_parent().get_child(1) as Label).add_theme_font_size_override("font_size",14)
		car_values[id] = {"distance":distance,"races":races}
	_refresh_car_values()

func _refresh_car_values() -> void:
	var local: Dictionary = records.settings.get("driving_history",{}).get("cars",{})
	var values: Dictionary = remote_cars if not remote_cars.is_empty() else local
	var new_driver: bool = int(AchievementProgress.read(records).metrics.get("races",0)) == 0
	for id: String in car_values:
		var data: Dictionary = values.get(id,{"races":0,"distance_m":0} if new_driver else {})
		car_values[id].races.text = Numbers.number(int(data.races)) if data.has("races") else "—"
		car_values[id].distance.text = "%.1f" % (float(data.distance_m)/1000.0) if data.get("distance_m") != null else "—"
		car_values[id].distance.tooltip_text = "Distance in completed races. Earlier races may not be included."

func refresh_car() -> void:
	_refresh_car_picture()

func _refresh_car_picture() -> void:
	if not _active(request_epoch) or not is_visible_in_tree(): return
	var preloader: Node = app.get("_garage_preloader")
	var pictures: Node = preloader.get("picture_service") if is_instance_valid(preloader) else null
	for id: String in photos:
		var texture: Texture2D
		var studio: bool = false
		if is_instance_valid(pictures) and preloader.get("picture_records") == records:
			var view: Node = pictures.warm_views.get(id)
			if is_instance_valid(view) and view.livery == VehicleLivery.for_car(records.settings,id) and view.customisation == VehicleCustomisation.for_car(records.settings,id) and view.condition == VehicleCondition.read(records,id):
				texture = pictures._remembered(id,view.preview_key)
				studio = texture != null
		if texture == null and Icons.stock_appearance(id,records):
			texture = load("res://assets/garage/previews_v1/"+id+".png")
			studio = true
		if texture == null: texture = Icons.texture(id,records)
		photos[id].modulate = Color.WHITE
		if texture == null:
			var silhouette := AtlasTexture.new()
			silhouette.atlas = preload("res://assets/menu/rivalry_loading_cars_v1.png")
			silhouette.region = Rect2(VehicleCatalog.IDS.find(id)*384,0,384,256)
			texture = silhouette
			photos[id].modulate = Color("8399a5")
		photos[id].texture = texture
		photos[id].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if studio else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var card: Control = fleet.get_node("ProfileCar_"+id)
		card.find_child("SelectedCar",true,false).visible = id == VehicleCatalog.selected
		var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		style.border_color = MenuStyle.ACCENT if id == VehicleCatalog.selected else Color("29414e")
		card.add_theme_stylebox_override("panel",style)
		card.find_child("CarName",true,false).add_theme_color_override("font_color",MenuStyle.ACCENT if id == VehicleCatalog.selected else MenuStyle.TEXT)

func _load_car_history() -> void:
	var epoch: int = request_epoch
	var response: Dictionary = await client.request_api("/me/profile-statistics",HTTPClient.METHOD_GET,{},"",true)
	if not _active(epoch) or not response.get("ok",false): return
	var data: Variant = response.get("data",{}).get("cars")
	if not data is Dictionary: return
	for id: String in VehicleCatalog.IDS:
		var car: Variant = data.get(id,{})
		if not car is Dictionary or not AchievementProgress.whole(car.get("races")): return
		if car.get("distance_m") != null and not AchievementProgress.whole(car.distance_m): return
	remote_cars = data.duplicate(true)
	fleet_note.text = "Verified race history"
	fleet_note.tooltip_text = "Recorded verified races. Older archived races may not be included."
	fleet.tooltip_text = fleet_note.tooltip_text
	var totals: Dictionary = response.data.get("totals",{})
	for key: String in total_values:
		if not totals.has(key): continue
		if totals[key] == null:
			total_values[key].text = "—"
			continue
		if not AchievementProgress.whole(totals[key]): continue
		total_values[key].text = GameText.message("%.1f km") % (float(totals[key])/1000.0) if key == "distance_m" else Numbers.number(int(totals[key]))
	find_child("ProfileRacingStats",true,false).tooltip_text = fleet_note.tooltip_text
	_refresh_car_values()

func _build_ranking(parent: Node) -> void:
	var box: VBoxContainer = _panel(parent,"ProfileRanking",12)
	var row := HBoxContainer.new()
	box.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",2)
	row.add_child(copy)
	_label(copy,"WORLD RANKING",18)
	ranking_status = _label(copy,"Loading ranking…" if client.signed_in() else "Sign in to compete in the World Ranking.",16,true)
	ranking_status.name = "ProfileRankingStatus"
	if client.signed_in() and preload("res://backend/world_ranking_client.gd").supported(client):
		row.add_child(_action("View ranking",func() -> void: preload("res://ui/world_ranking.gd").open(app.root_ui,client)))
	elif client.signed_in(): ranking_status.text = "World Ranking is unavailable."
	if client.signed_in():
		var uploads: Button = _action("Race uploads",app.cloud.show_uploads.bind(app.root_ui))
		uploads.name = "ProfileRaceUploads"
		row.add_child(uploads)

func _load_ranking() -> void:
	var epoch: int = request_epoch
	var adapter: Node = preload("res://backend/world_ranking_client.gd").for_client(client)
	var response: Dictionary = await adapter.profile()
	if not _active(epoch): return
	if not response.ok: ranking_status.text = "Could not load ranking. Open World Ranking to retry."
	elif response.data.get("world_rank") != null:
		ranking_status.text = GameText.message("World #%d · %d points") % [int(response.data.world_rank),int(response.data.points)]
		ranking_status.add_theme_color_override("font_color",MenuStyle.ACCENT)
	elif response.data.get("state") == "unranked": ranking_status.text = "Unranked · Finish five Circuit tracks"
	else: ranking_status.text = "World Ranking has not started yet."

func _build_achievements(parent: Node) -> void:
	var box: VBoxContainer = _panel(parent,"ProfileAchievements")
	var choose: Button = _section(box,"ACHIEVEMENTS","View collection",show_achievements)
	choose.name = "ProfileChooseAchievements"
	var heading: HBoxContainer = choose.get_parent()
	var title: Label = heading.get_child(0)
	heading.remove_child(title)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation",0)
	heading.add_child(copy)
	heading.move_child(copy,0)
	copy.add_child(title)
	badge_summary = _label(copy,"",15,true)
	badge_summary.name = "ProfileAchievementSummary"
	badge_grid = GridContainer.new()
	badge_grid.name = "ProfileBadgeGrid"
	box.add_child(badge_grid)
	_refresh_badges()

func _refresh_badges() -> void:
	if not is_instance_valid(badge_grid): return
	_clear(badge_grid)
	var featured: Array = service.featured() if service != null else []
	var families: Array[Dictionary] = []
	var earned: int = 0
	var total: int = 0
	for family: Dictionary in AchievementProgress.catalog().families:
		var source: Dictionary = service.source(family) if service != null else AchievementProgress.empty()
		earned += AchievementProgress.tier(family,source)
		total += family.tiers.size()
		if family.id in featured: families.append(family)
	badge_summary.text = GameText.message("%d / %d earned") % [earned,total]
	if families.is_empty():
		for family: Dictionary in AchievementProgress.catalog().families:
			if family.id in ["races","distance","tracks"]: families.append(family)
	for family: Dictionary in families:
		var source: Dictionary = service.source(family) if service != null else AchievementProgress.empty()
		var level: int = AchievementProgress.tier(family,source)
		var row: HBoxContainer = _row_button(badge_grid,"ProfileBadge_"+str(family.id),show_achievements.bind(str(family.id)))
		var inset: MarginContainer = row.get_parent()
		inset.add_theme_constant_override("margin_top",0)
		inset.add_theme_constant_override("margin_bottom",0)
		(inset.get_parent() as Button).add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
		var display := VBoxContainer.new()
		display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		display.add_theme_constant_override("separation",6)
		row.add_child(display)
		var badge := AchievementBadge.new()
		badge.family_id = family.id
		badge.prestige = family.prestige
		badge.tier = 3 if family.prestige and level > 0 else level
		display.add_child(badge)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.custom_minimum_size = Vector2(76,76)
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation",3)
		display.add_child(copy)
		var title: Label = _label(copy,str(family.title),22)
		title.add_theme_font_override("font",MenuStyle.DISPLAY)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var caption: String = "Prestige earned" if family.prestige and level > 0 else ["Not yet earned","Bronze earned","Silver earned","Gold earned","Platinum earned"][level]
		_label(copy,caption,14,true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 3
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.show_percentage = false
		progress.add_theme_stylebox_override("fill",MenuStyle.box(AchievementBadge.METALS[3 if family.prestige else maxi(level,1)],0))
		progress.max_value = family.tiers[mini(level,family.tiers.size()-1)]
		progress.value = progress.max_value if level == family.tiers.size() else int(source.get("metrics",{}).get(family.metric,0))
		copy.add_child(progress)

func show_achievements(family: String = "") -> void:
	if collection != null: return
	page_body.hide()
	photo_timer.stop()
	collection = preload("res://ui/achievements_menu.gd").new()
	collection.service = service
	collection.trophy_room_requested.connect(_close_collection)
	add_child(collection)
	collection.find_child("AchievementClose",true,false).tooltip_text = "Back to profile"
	if not family.is_empty(): collection._show_achievement(family)
	else: collection.find_child("AchievementClose",true,false).grab_focus()

func _close_collection() -> void:
	remove_child(collection)
	collection.queue_free()
	collection = null
	page_body.show()
	photo_timer.start()
	_refresh_badges()
	find_child("ProfileChooseAchievements",true,false).grab_focus()

func _row_button(parent: Node, id: String, callback: Callable) -> HBoxContainer:
	var button: Button = _action("",callback)
	button.name = id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var neutral: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,0)
	neutral.set_corner_radius_all(0)
	neutral.border_width_bottom = 1
	neutral.border_color = Color("31566a99")
	button.add_theme_stylebox_override("normal",neutral)
	button.add_theme_stylebox_override("pressed",MenuStyle.box(Color("29434f"),0))
	parent.add_child(button)
	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+side,10)
	button.add_child(inset)
	MenuStyle.fill(inset)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",12)
	inset.add_child(row)
	# Button minimums do not follow children. Propagate wrapped height only;
	# the grid owns width so long names cannot push the page off screen.
	inset.minimum_size_changed.connect(func() -> void:
		if is_instance_valid(button): button.custom_minimum_size.y = maxf(80,inset.get_combined_minimum_size().y))
	return row

func _build_tracks(parent: Node) -> void:
	var box: VBoxContainer = _panel(parent,"ProfilePublishedTracks")
	var create: Button = _section(box,"CREATED TRACKS","Create a track",app._new_document)
	create.name = "ProfileCreateTrack"
	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	track_mode = "published" if client.signed_in() else "drafts"
	for item: Array in [["published","Published"],["drafts","Drafts"]]:
		var button: Button = _action(item[1],_select_tracks.bind(item[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
		track_tabs[item[0]] = button
	track_status = _label(box,"Loading published tracks…",16,true)
	track_status.name = "ProfileTrackStatus"
	track_grid = GridContainer.new()
	track_grid.name = "ProfileTrackGrid"
	track_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_grid.add_theme_constant_override("v_separation",8)
	box.add_child(track_grid)
	track_action = _action("More tracks",_load_tracks)
	track_action.name = "ProfileViewTracks"
	box.add_child(track_action)
	_render_tracks()

func _select_tracks(mode: String) -> void:
	track_mode = mode
	_render_tracks()

func _load_tracks() -> void:
	if track_busy or not client.signed_in(): return
	track_busy = true
	track_error = false
	_render_tracks()
	var epoch: int = request_epoch
	var response: Dictionary = await client.request_api("/me/tracks?heads=true&profile_stats=true&limit=12&offset="+str(next_offset),HTTPClient.METHOD_GET,{},"",true)
	if not _active(epoch): return
	track_busy = false
	loaded_tracks = true
	track_error = not response.get("ok",false)
	if not track_error:
		var ids: Dictionary = {}
		for item: Dictionary in published: ids[str(item.track_id)] = true
		for entry: Variant in response.data.get("items",[]):
			if not entry is Dictionary or str(entry.get("creator_id","")) != str(client.player.get("id","")) or entry.get("state","published") != "published": continue
			if is_instance_valid(client.safety) and not client.safety.allows(entry): continue
			if ids.has(str(entry.get("track_id",""))): continue
			published.append(entry)
			ids[str(entry.track_id)] = true
		var next: Variant = response.data.get("next_offset")
		next_offset = int(next) if next != null and int(next) > next_offset and int(next) <= 10000 else -1
	_render_tracks()

func _start_drafts() -> void:
	var library: TrackLibrary = app.get("library")
	if library == null: return
	draft_directory = library.directory
	draft_revision = library.revision
	draft_loading = true
	draft_scan = Scans.start(draft_directory,get_tree())
	set_process(true)
	_render_tracks()

func _process(_delta: float) -> void:
	if draft_scan == null or not draft_scan.done: return
	var completed: RefCounted = draft_scan
	draft_scan = null
	set_process(false)
	if not _active(request_epoch): return
	var library: TrackLibrary = app.get("library")
	if library == null: return
	if library.directory != draft_directory or library.revision != draft_revision:
		_start_drafts()
		return
	drafts = completed.entries
	draft_loading = false
	_render_tracks()

func _render_tracks() -> void:
	if not is_instance_valid(track_grid): return
	_clear(track_grid)
	for mode: String in track_tabs:
		track_tabs[mode].add_theme_color_override("font_color",MenuStyle.ACCENT if mode == track_mode else MenuStyle.MUTED)
		var style: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,8)
		style.set_corner_radius_all(0)
		style.border_width_bottom = 2 if mode == track_mode else 1
		style.border_color = MenuStyle.ACCENT if mode == track_mode else Color("29414e")
		track_tabs[mode].add_theme_stylebox_override("normal",style)
	var entries: Array[Dictionary] = published if track_mode == "published" else drafts
	for entry: Dictionary in entries: _add_track(entry,track_mode == "drafts")
	track_action.visible = track_mode == "published" and client.signed_in() and (track_error or next_offset >= 0)
	track_action.disabled = track_busy
	track_action.text = "Retry" if track_error else "Loading…" if track_busy else "More tracks"
	var status: String = ""
	if track_mode == "drafts":
		if draft_loading: status = "Loading drafts…"
		elif drafts.is_empty(): status = "Your next great circuit starts here."
	elif not client.signed_in(): status = "Sign in to see your published tracks."
	elif track_error: status = "Could not load published tracks."
	elif track_busy and entries.is_empty(): status = "Loading published tracks…"
	elif loaded_tracks and entries.is_empty(): status = "Your published tracks will appear here."
	track_status.text = status
	track_status.visible = not status.is_empty()

func _add_track(entry: Dictionary, draft: bool = false) -> void:
	var doc: Dictionary = entry.get("document",entry)
	var id: String = str(entry.get("id",entry.get("track_id","")))
	var callback: Callable = app._load_saved_document.bind(str(entry.get("load_id",id))) if draft else app._open_published_track.bind(entry)
	var row: HBoxContainer = _row_button(track_grid,"ProfileTrack_"+id,callback)
	var theme_id: String = str(doc.get("theme","pine"))
	var thumbnail := PanelContainer.new()
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame: StyleBoxFlat = MenuStyle.box(Color("102530"),2)
	frame.set_border_width_all(1)
	frame.border_color = Color(Biomes.color(theme_id),0.3)
	thumbnail.add_theme_stylebox_override("panel",frame)
	row.add_child(thumbnail)
	var route := RouteThumbnail.new()
	route.name = "ProfileRoute"
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route.custom_minimum_size = Vector2(72,64)
	route.setup(doc)
	thumbnail.add_child(route)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation",3)
	row.add_child(copy)
	var title: Label = _label(copy,str(doc.get("name","Track")),22)
	title.add_theme_font_override("font",MenuStyle.DISPLAY)
	GameText.user_text(title)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var metadata := HBoxContainer.new()
	metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metadata.add_theme_constant_override("separation",5)
	copy.add_child(metadata)
	var glyph := TextureRect.new()
	glyph.texture = MenuIcon.texture(Biomes.icon(theme_id))
	glyph.modulate = Biomes.color(theme_id)
	glyph.custom_minimum_size = Vector2(14,14)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metadata.add_child(glyph)
	var subtitle: String = tr(TrackTheme.title(theme_id))
	if draft: subtitle += " · "+tr("Draft")
	elif entry.get("rating_average") != null: subtitle += " · ★ %.1f" % float(entry.rating_average)
	_label(metadata,subtitle,14,true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var races: Variant = records.settings.get("driving_history",{}).get("tracks",{}).get(id) if draft else entry.get("verified_races")
	var number: Label = _stat(row,Numbers.number(int(races)) if races != null else "—","Your races" if draft else "Verified races")
	var counter: VBoxContainer = number.get_parent()
	counter.size_flags_horizontal = Control.SIZE_SHRINK_END
	counter.custom_minimum_size.x = 108
	(counter.get_child(1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.name = "TrackRaceCount"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.tooltip_text = "Completed races on this device" if draft else "Recorded verified races on this version. Older archived races may not be included."

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _exit_tree() -> void:
	request_epoch += 1
	if draft_scan != null: draft_scan.cancel()
