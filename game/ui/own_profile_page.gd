extends VBoxContainer
## The player's own profile. Remote summaries are read only and account fenced.
var app: Node
var client: Node
var records: LocalRecords
var service: Node
var scope: String
var overview: GridContainer
var track_grid: GridContainer
var badge_grid: GridContainer
var track_status: Label
var ranking_status: Label
var track_action: Button
var request_epoch: int = 0
var hero_photo: TextureRect
var hero_car: Control
var photo_timer: Timer

class HeroArt extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var bounds: Rect2 = Rect2(Vector2.ZERO,size)
		draw_rect(bounds,Color("102631"))
		for i: int in range(32):
			var y: float = size.y*float(i)/32.0
			draw_rect(Rect2(0,y,size.x,size.y/32.0+1),Color("1d3b45").lerp(Color("0a1820"),float(i)/32.0))
		var right: float = size.x
		draw_colored_polygon(PackedVector2Array([Vector2(right*0.40,0),Vector2(right*0.63,0),Vector2(right*0.49,size.y),Vector2(right*0.26,size.y)]),Color(0.56,0.77,0.74,0.035))
		draw_line(Vector2(right*0.59,0),Vector2(right*0.45,size.y),Color(0.75,0.90,0.84,0.10),1.0)

func _ready() -> void:
	name = "OwnProfilePage"
	client = app.online.client
	records = app.records
	service = app.achievements
	scope = _scope()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	var heading := HBoxContainer.new()
	add_child(heading)
	var title: Label = MenuStyle.label("PROFILE",36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var account: Button = MenuStyle.button("Edit profile" if client.signed_in() else "Sign in",app._open_account)
	account.name = "ManageAccount"
	heading.add_child(account)
	var scroll := ScrollContainer.new()
	scroll.name = "ProfileScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	_build_identity(body)
	overview = GridContainer.new()
	overview.name = "ProfileOverview"
	overview.columns = 2
	overview.add_theme_constant_override("h_separation",12)
	overview.add_theme_constant_override("v_separation",12)
	body.add_child(overview)
	_build_stats(overview)
	_build_ranking(overview)
	_build_achievements(body)
	_build_tracks(body)
	if client.signed_in():
		var uploads: Button = MenuStyle.button("Race uploads",app.cloud.show_uploads.bind(app.root_ui))
		uploads.name = "ProfileRaceUploads"
		body.add_child(uploads)
	resized.connect(_layout)
	_layout.call_deferred()
	if client.has_signal("identity_changed"): client.identity_changed.connect(_identity_changed)
	if service != null: service.changed.connect(_refresh_badges)
	photo_timer = Timer.new()
	photo_timer.wait_time = 1.0
	photo_timer.timeout.connect(_refresh_car_picture)
	add_child(photo_timer)
	photo_timer.start()
	_refresh_car_picture()
	if client.signed_in():
		_load_tracks.call_deferred()
		if preload("res://backend/world_ranking_client.gd").supported(client): _load_ranking.call_deferred()

func _scope() -> String:
	return client.base_url()+"/"+str(client.player.get("id",""))

func _active(epoch: int) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and epoch == request_epoch and scope == _scope() and app.records == records

func _identity_changed() -> void:
	if scope == _scope(): return
	request_epoch += 1
	# The app owns profile transitions and reconstructs this page for the new owner.
	visible = false

func _layout() -> void:
	if not is_instance_valid(overview): return
	var width: float = size.x
	overview.columns = 2 if width >= 760 else 1
	badge_grid.columns = 3 if width >= 760 else 2 if width >= 460 else 1
	track_grid.columns = 3 if width >= 900 else 2 if width >= 540 else 1

func _panel(parent: Control, id: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = MenuStyle.box(Color("101f29"),16)
	style.set_corner_radius_all(8)
	style.border_color = Color("29434d")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	return box

func _label(parent: Control, value: String, font_size: int = 18, muted: bool = false) -> Label:
	var label: Label = MenuStyle.label(value,font_size,muted)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _section_heading(parent: Control, value: String, action_text: String, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var label: Label = _label(row,value,22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var action: Button = _text_action(action_text,callback)
	row.add_child(action)
	return action

func _text_action(value: String, callback: Callable) -> Button:
	var button: Button = MenuStyle.button(value,callback)
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size",19)
	button.add_theme_stylebox_override("normal",MenuStyle.box(Color(0.17,0.26,0.30,0.40),10))
	button.add_theme_stylebox_override("hover",MenuStyle.box(Color("284858"),10))
	button.add_theme_color_override("font_color",MenuStyle.TEXT)
	return button

func _build_identity(parent: Control) -> void:
	var frame := PanelContainer.new()
	frame.name = "ProfileIdentity"
	frame.custom_minimum_size.y = 224
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = MenuStyle.box(Color("102631"),0)
	style.set_corner_radius_all(8)
	style.border_color = Color("34535b")
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel",style)
	parent.add_child(frame)
	var stage := Control.new()
	stage.custom_minimum_size.y = 224
	stage.clip_contents = true
	frame.add_child(stage)
	var art := HeroArt.new()
	stage.add_child(art)
	MenuStyle.fill(art)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation",0)
	stage.add_child(layout)
	MenuStyle.fill(layout)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 0.95
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	layout.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",5)
	margin.add_child(box)
	var eyebrow: Label = _label(box,"DRIVER PROFILE",15)
	eyebrow.add_theme_color_override("font_color",MenuStyle.ACCENT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	box.add_child(row)
	var country: String = str(client.player.get("country_code","")) if client.signed_in() else ""
	if not country.is_empty(): row.add_child(PlayerCountry.flag(country,32))
	var identity: Label = _label(row,app.online.player_name() if client.signed_in() else "Guest",38)
	identity.name = "ProfilePlayerName"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.autowrap_mode = TextServer.AUTOWRAP_OFF
	identity.custom_minimum_size.y = 46
	identity.clip_text = true
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if client.signed_in(): GameText.user_text(identity)
	_label(box,PlayerCountry.country_name(country) if client.signed_in() else "Your racing story starts here",17,true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_label(box,"CURRENT CAR",14,true)
	var car_name: Label = _label(box,VehicleCatalog.title(VehicleCatalog.selected),24)
	car_name.name = "ProfileSelectedCarName"
	var picture := Control.new()
	picture.name = "ProfileCarStage"
	picture.clip_contents = true
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.size_flags_stretch_ratio = 1.2
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(picture)
	hero_car = preload("res://ui/profile_car.gd").new()
	hero_car.name = "ProfileSelectedCar"
	hero_car.records = records
	picture.add_child(hero_car)
	MenuStyle.fill(hero_car)
	hero_photo = TextureRect.new()
	hero_photo.name = "ProfileCarPhoto"
	hero_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hero_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_photo.scale = Vector2(1.55,1.55)
	hero_photo.resized.connect(func() -> void: hero_photo.pivot_offset = hero_photo.size*0.5)
	picture.add_child(hero_photo)
	MenuStyle.fill(hero_photo)
	hero_photo.hide()

func refresh_car() -> void:
	var car: Control = find_child("ProfileSelectedCar",true,false)
	var car_name: Label = find_child("ProfileSelectedCarName",true,false)
	if car != null: car.refresh()
	if car_name != null: car_name.text = VehicleCatalog.title(VehicleCatalog.selected)
	_refresh_car_picture()

func _refresh_car_picture() -> void:
	if not is_instance_valid(hero_photo): return
	var preloader: Node = app.get("_garage_preloader")
	var service_node: Node = preloader.get("picture_service") if is_instance_valid(preloader) else null
	var picture: Texture2D
	if is_instance_valid(service_node) and preloader.get("picture_records") == records:
		var view: Node = service_node.warm_views.get(VehicleCatalog.selected)
		if is_instance_valid(view) and view.livery == VehicleLivery.for_car(records.settings,VehicleCatalog.selected) and view.customisation == VehicleCustomisation.for_car(records.settings,VehicleCatalog.selected) and view.condition == VehicleCondition.read(records,VehicleCatalog.selected):
			picture = service_node._remembered(VehicleCatalog.selected,view.preview_key)
	hero_photo.texture = picture
	hero_photo.visible = picture != null
	hero_car.visible = picture == null

func _build_ranking(parent: Control) -> void:
	var box: VBoxContainer = _panel(parent,"ProfileRanking")
	_label(box,"WORLD RANKING",22)
	var presentation := HBoxContainer.new()
	presentation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	presentation.add_theme_constant_override("separation",12)
	box.add_child(presentation)
	ranking_status = _label(presentation,"Loading ranking…" if client.signed_in() and preload("res://backend/world_ranking_client.gd").supported(client) else "World Ranking is unavailable." if client.signed_in() else "Sign in to compete in the World Ranking.",21,true)
	ranking_status.name = "ProfileRankingStatus"
	ranking_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var emblem := TextureRect.new()
	emblem.name = "ProfileRankingEmblem"
	emblem.texture = preload("res://ui/race_mode_icons.gd").texture("trophy")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(72,72)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.modulate = Color(0.75,0.84,0.84,0.35)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.add_child(emblem)
	if client.signed_in() and preload("res://backend/world_ranking_client.gd").supported(client):
		var action: Button = _text_action("View ranking  →",func() -> void: preload("res://ui/world_ranking.gd").open(app.root_ui,client))
		action.name = "ProfileViewRanking"
		box.add_child(action)

func _load_ranking() -> void:
	var epoch: int = request_epoch
	var adapter: Node = preload("res://backend/world_ranking_client.gd").for_client(client)
	var response: Dictionary = await adapter.profile()
	if not _active(epoch): return
	if not response.ok:
		ranking_status.text = "Could not load ranking. Open World Ranking to retry."
	elif response.data.get("world_rank") != null:
		ranking_status.text = GameText.message("World #%d\n%d points") % [int(response.data.world_rank),int(response.data.points)]
		ranking_status.add_theme_color_override("font_color",MenuStyle.ACCENT)
		ranking_status.add_theme_font_size_override("font_size",28)
	elif response.data.get("state") == "unranked":
		ranking_status.text = "Unranked · Finish five Circuit tracks"
	else:
		ranking_status.text = "World Ranking has not started yet."

func _build_stats(parent: Control) -> void:
	var box: VBoxContainer = _panel(parent,"ProfileRacing")
	_label(box,"YOUR RACING",22)
	var metrics: Dictionary = AchievementProgress.read(records).metrics
	if int(metrics.get("races",0)) == 0:
		_label(box,"Complete a race to start your racing story.",19,true)
		box.add_child(_text_action("Find a race  →",app._open_race_area))
	else:
		var grid := GridContainer.new()
		grid.name = "ProfileRacingStats"
		grid.columns = 2
		box.add_child(grid)
		_stat(grid,str(int(metrics.get("races",0))),"Completed races")
		_stat(grid,GameText.message("%.1f km") % (float(metrics.get("distance_m",0))/1000.0),"Distance driven")
		_stat(grid,str(int(metrics.get("tracks",0))),"Tracks raced")
		_stat(grid,str(int(metrics.get("clean",0))),"Clean races")
	_label(box,"Progress recorded on this device; earlier races may not be included.",15,true)

func _stat(parent: Control, value: String, caption: String) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",0)
	parent.add_child(box)
	var number: Label = _label(box,value,30)
	number.add_theme_color_override("font_color",MenuStyle.ACCENT)
	_label(box,caption,16,true)

func _build_achievements(parent: Control) -> void:
	var box: VBoxContainer = _panel(parent,"ProfileAchievements")
	var choose: Button = _section_heading(box,"FEATURED ACHIEVEMENTS","Choose featured  →",app._open_profile_achievements)
	choose.name = "ProfileChooseAchievements"
	badge_grid = GridContainer.new()
	badge_grid.name = "ProfileBadgeGrid"
	box.add_child(badge_grid)
	_refresh_badges()

func _refresh_badges() -> void:
	if not is_instance_valid(badge_grid): return
	for child: Node in badge_grid.get_children():
		badge_grid.remove_child(child)
		child.queue_free()
	var featured: Array = service.featured() if service != null else []
	if featured.is_empty():
		_label(badge_grid,"Earn achievements and choose your favourites to display here.",18,true)
		return
	for family: Dictionary in AchievementProgress.catalog().families:
		if family.id not in featured: continue
		var level: int = AchievementProgress.tier(family,service.source(family))
		var button: Button = MenuStyle.button("",app._open_profile_achievements.bind(str(family.id)))
		button.name = "ProfileBadge_"+str(family.id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 90
		badge_grid.add_child(button)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		MenuStyle.fill(row)
		var badge := AchievementBadge.new()
		badge.family_id = family.id
		badge.tier = level
		row.add_child(badge)
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		_label(copy,str(family.title),18)
		_label(copy,["Locked","Bronze","Silver","Gold","Platinum"][clampi(level,0,4)],15,true)

func _build_tracks(parent: Control) -> void:
	var box: VBoxContainer = _panel(parent,"ProfilePublishedTracks")
	track_action = _section_heading(box,"YOUR PUBLISHED TRACKS","View all  →",app._open_profile_tracks)
	track_action.name = "ProfileViewTracks"
	track_action.visible = false
	track_status = _label(box,"Loading published tracks…" if client.signed_in() else "Sign in to see your published tracks.",18,true)
	track_status.name = "ProfileTrackStatus"
	track_grid = GridContainer.new()
	track_grid.name = "ProfileTrackGrid"
	box.add_child(track_grid)
	if not client.signed_in(): box.add_child(_text_action("Create a track  →",app._new_document))

func _load_tracks() -> void:
	var epoch: int = request_epoch
	var owner_id: String = str(client.player.get("id",""))
	var cursor: String = ""
	var seen: Dictionary = {}
	var count: int = 0
	for page: int in range(5):
		var path: String = "/tracks?creator="+app.online.player_name().uri_encode()+"&limit=20"
		if not cursor.is_empty(): path += "&cursor="+cursor.uri_encode()
		var response: Dictionary = await client.request_api(path,HTTPClient.METHOD_GET,{},"",true)
		if not _active(epoch): return
		if not response.ok:
			track_status.text = "Could not load published tracks."
			track_action.text = "Retry"
			track_action.visible = true
			track_action.pressed.disconnect(app._open_profile_tracks)
			track_action.pressed.connect(_retry_tracks,CONNECT_ONE_SHOT)
			return
		for entry: Variant in response.data.get("items",[]):
			if not entry is Dictionary or str(entry.get("creator_id","")) != owner_id: continue
			if is_instance_valid(client.safety) and not client.safety.allows(entry): continue
			_add_track(entry)
			count += 1
			if count >= 3: break
		cursor = str(response.data.get("next_cursor","") if response.data.get("next_cursor") != null else "")
		if count >= 3 or cursor.is_empty() or seen.has(cursor): break
		seen[cursor] = true
	track_status.text = "" if count > 0 else "Your published tracks will appear here." if cursor.is_empty() else "No tracks found in this preview. View all tracks to search."
	track_status.visible = not track_status.text.is_empty()
	track_action.visible = count > 0 or not cursor.is_empty()
	if count == 0 and cursor.is_empty():
		track_action.text = "Create a track"
		track_action.pressed.disconnect(app._open_profile_tracks)
		track_action.pressed.connect(app._new_document)
		track_action.visible = true

func _retry_tracks() -> void:
	for child: Node in track_grid.get_children():
		track_grid.remove_child(child)
		child.queue_free()
	track_status.show()
	track_status.text = "Loading published tracks…"
	track_action.text = "View all  →"
	track_action.hide()
	track_action.pressed.connect(app._open_profile_tracks)
	_load_tracks()

func _add_track(entry: Dictionary) -> void:
	var button: Button = MenuStyle.button("",app._open_published_track.bind(entry))
	button.name = "ProfileTrack_"+str(entry.get("track_id",""))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 110
	track_grid.add_child(button)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	MenuStyle.fill(row)
	var route := LapRouteView.new()
	route.miniature = true
	route.custom_minimum_size = Vector2(70,70)
	for point: Variant in entry.get("points",[]):
		if point is Array and point.size() == 2: route.route.append(Vector2(float(point[0]),float(point[1])))
	row.add_child(route)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title: Label = _label(copy,str(entry.get("name","Track")),19)
	GameText.user_text(title)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.y = 26
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label(copy,str(entry.get("theme","pine")).capitalize(),16,true)
	if entry.get("rating_average") != null:
		_label(copy,GameText.message("★ %.1f · %d ratings") % [float(entry.rating_average),int(entry.get("rating_count",0))],15,true)
