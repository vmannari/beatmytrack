extends AcceptDialog
## Public Rivalry profile. Uses the existing published catalog and safety adapter.
const PAGE_SIZE: int = 20
const MAX_TRACKS: int = 100
var client: Node
var driver: Dictionary = {}
var vehicle_id: String = "compact"
var account_scope: String
var tracks: VBoxContainer
var track_status: Label
var more: Button
var actions: MenuButton
var preview: Control
var next_cursor: String = ""
var track_count: int = 0
var loading: bool = false
var blocking: bool = false
var read_epoch: int = 0
var bounds := Vector2i(800,580)

static func open(parent: Node, adapter: Node, row: Dictionary, car_id: String) -> Node:
	var sheet: Node = load("res://ui/player_profile.gd").new()
	sheet.client = adapter
	sheet.driver = row.duplicate(true)
	sheet.vehicle_id = car_id
	sheet.bounds = Vector2i(parent.get_viewport().get_visible_rect().size-Vector2(32,32)).min(Vector2i(800,580))
	parent.add_child(sheet)
	sheet.popup_centered(sheet.bounds)
	return sheet

static func bind_name(label: Label, action: Callable) -> void:
	label.set_meta("player_profile_action",action)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.focus_mode = Control.FOCUS_ALL
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.tooltip_text = "View player"
	var press: Dictionary = {"active":false,"origin":Vector2.ZERO}
	label.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
			if event.pressed:
				press.active = true
				press.origin = event.position
			elif press.active:
				press.active = false
				if Rect2(Vector2.ZERO,label.size).has_point(event.position) and event.position.distance_to(press.origin) < 12: action.call()
		elif event is InputEventScreenTouch:
			if event.pressed:
				press.active = true
				press.origin = event.position
			elif press.active:
				press.active = false
				if not event.canceled and event.position.distance_to(press.origin) < 12: action.call()
		elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and press.active:
			if event.position.distance_to(press.origin) >= 12: press.active = false
		elif event.is_action_pressed("ui_accept") and not event.is_echo():
			action.call()
			label.accept_event()
	)

func player_id() -> String:
	return str(driver.get("driver_id",driver.get("id","")))

func _scope() -> String:
	return client.base_url()+"/"+str(client.player.get("id",""))

func _ready() -> void:
	name = "RivalryPlayerProfile"
	title = "Player"
	theme = MenuStyle.theme()
	preload("res://ui/popup_style.gd").watch(self)
	ok_button_text = "Close"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	account_scope = _scope()
	client.identity_changed.connect(func() -> void:
		if _scope() != account_scope: queue_free()
	)
	client.safety.changed.connect(_safety_changed)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := ScrollContainer.new()
	content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.custom_minimum_size = Vector2(bounds.x-64,maxi(180,bounds.y-200))
	content.add_child(body)
	add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	body.add_child(header)
	var country: Control = PlayerCountry.flag(str(driver.get("country_code","")),30)
	country.name = "PlayerProfileCountry"
	header.add_child(country)
	var identity: Label = MenuStyle.label(str(driver.get("name","Player")),27)
	identity.name = "PlayerProfileName"
	identity.clip_text = true
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	actions = MenuButton.new()
	actions.name = "PlayerProfileMore"
	actions.text = "…"
	actions.tooltip_text = "Player options"
	actions.custom_minimum_size = Vector2(52,48)
	add_child(actions)
	get_node("PopupStyle").header_action = actions
	preload("res://ui/popup_style.gd").watch(actions.get_popup())
	actions.get_popup().about_to_popup.connect(_update_actions)
	actions.get_popup().id_pressed.connect(_action)
	_update_actions()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var car_column := VBoxContainer.new()
	car_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	car_column.size_flags_stretch_ratio = 0.85
	columns.add_child(car_column)
	car_column.add_child(MenuStyle.label("Rivalry car",19,true))
	preview = preload("res://ui/rivalry_victory_car.gd").new()
	preview.name = "PlayerProfileCar"
	preview.vehicle_id = vehicle_id
	preview.simple_model = true
	preview.podium_presentation = true
	preview.fit_to_frame = true
	var appearance: Dictionary = driver.get("appearance",{})
	if appearance.get("vehicle_id") == vehicle_id:
		if VehicleLivery.valid(appearance.get("livery")): preview.livery = VehicleLivery.normalize(appearance.livery,vehicle_id)
		if VehicleCustomisation.valid(appearance.get("customisation")):
			preview.customisation = appearance.customisation.duplicate(true)
			preview.customisation.version = VehicleCustomisation.VERSION
	preview.custom_minimum_size = Vector2(160,110)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	car_column.add_child(preview)
	var car_name: Label = MenuStyle.label(VehicleCatalog.title(vehicle_id),20)
	car_name.name = "PlayerProfileCarName"
	car_column.add_child(car_name)
	if appearance.get("vehicle_id") != vehicle_id:
		car_column.add_child(MenuStyle.label("Appearance not shared",16,true))
	var summary: Label = MenuStyle.label("%d points" % int(driver.get("points",0)),18,true)
	if driver.get("rank") != null: summary.text = "#%d  ·  " % int(driver.rank)+summary.text
	car_column.add_child(summary)
	if preload("res://backend/world_ranking_client.gd").supported(client):
		var world: Control = preload("res://ui/world_ranking_summary.gd").new()
		world.client = client
		world.player_id = player_id()
		car_column.add_child(world)
	var track_column := VBoxContainer.new()
	track_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(track_column)
	track_column.add_child(MenuStyle.label("Created tracks",23))
	var scroll := ScrollContainer.new()
	scroll.name = "PlayerProfileTrackScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 100
	track_column.add_child(scroll)
	tracks = VBoxContainer.new()
	tracks.name = "PlayerProfileTracks"
	tracks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks.add_theme_constant_override("separation",8)
	scroll.add_child(tracks)
	track_status = MenuStyle.label("Loading published tracks…",17,true)
	track_status.name = "PlayerProfileTrackStatus"
	track_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_column.add_child(track_status)
	more = MenuStyle.button("More tracks",_load_tracks)
	more.name = "PlayerProfileMoreTracks"
	more.custom_minimum_size.y = 48
	more.hide()
	track_column.add_child(more)
	_safety_changed()
	if not client.safety.is_blocked(player_id()): _load_tracks.call_deferred()

func _update_actions() -> void:
	var popup: PopupMenu = actions.get_popup()
	popup.clear()
	popup.add_item("Report player",0)
	popup.add_item("Unblock player" if client.safety.is_blocked(player_id()) else "Block player",1)
	var own: bool = player_id() == str(client.player.get("id",""))
	for index: int in range(popup.item_count): popup.set_item_disabled(index,own or blocking)

func _action(id: int) -> void:
	if id == 0:
		preload("res://ui/community_safety_ui.gd").open(self,client,"report",{"subject":"player","reported_player_id":player_id(),"name":str(driver.get("name","Player"))})
	elif id == 1:
		if not client.signed_in():
			preload("res://ui/community_safety_ui.gd").open(self,client,"player",{})
			return
		if blocking: return
		blocking = true
		_update_actions()
		var response: Dictionary = await client.safety.set_block(player_id(),str(driver.get("name","Player")),not client.safety.is_blocked(player_id()))
		if not is_inside_tree() or is_queued_for_deletion() or _scope() != account_scope: return
		blocking = false
		_update_actions()
		if not response.ok: track_status.text = "Could not sync. Retry from Community safety."

func _safety_changed() -> void:
	if not is_instance_valid(tracks): return
	_update_actions()
	var blocked: bool = client.safety.is_blocked(player_id())
	find_child("PlayerProfileName",true,false).text = "Blocked player" if blocked else str(driver.get("name","Player"))
	find_child("PlayerProfileCountry",true,false).visible = not blocked
	preview.visible = not blocked
	find_child("PlayerProfileCarName",true,false).visible = not blocked
	if blocked:
		read_epoch += 1
		loading = false
		for child: Node in tracks.get_children():
			tracks.remove_child(child)
			child.queue_free()
		track_count = 0
		next_cursor = ""
		track_status.text = "This player is blocked."
		more.hide()
	elif track_status.text == "This player is blocked.": _load_tracks.call_deferred()

func _load_tracks() -> void:
	if loading or client.safety.is_blocked(player_id()) or _scope() != account_scope: return
	loading = true
	var epoch: int = read_epoch
	more.disabled = true
	track_status.text = "Loading published tracks…"
	# Creator names are a search hint only. Exact account IDs decide every visible row.
	var path: String = "/tracks?creator="+str(driver.get("catalog_creator",driver.get("name",""))).uri_encode()+"&limit="+str(PAGE_SIZE)
	if not next_cursor.is_empty(): path += "&cursor="+next_cursor.uri_encode()
	var response: Dictionary = await client.request_api(path,HTTPClient.METHOD_GET,{},"",client.signed_in())
	if not is_inside_tree() or is_queued_for_deletion() or _scope() != account_scope: return
	if epoch != read_epoch: return
	loading = false
	more.disabled = false
	if client.safety.is_blocked(player_id()): return
	if not response.ok:
		track_status.text = "Could not load tracks."
		more.text = "Retry"
		more.show()
		return
	for entry: Dictionary in response.data.get("items",[]):
		if str(entry.get("creator_id","")) != player_id() or not client.safety.allows(entry): continue
		if track_count >= MAX_TRACKS: break
		_add_track(entry)
		next_cursor = str(response.data.get("next_cursor","") if response.data.get("next_cursor") != null else "")
	more.text = "More tracks"
	more.visible = not next_cursor.is_empty() and track_count < MAX_TRACKS
	track_status.text = "Published tracks" if track_count > 0 else "No published tracks yet." if next_cursor.is_empty() else "More published tracks are available."

func _add_track(entry: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "PlayerTrack_"+str(entry.get("track_id",""))
	panel.add_theme_stylebox_override("panel",MenuStyle.card(8))
	tracks.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	panel.add_child(row)
	var route := LapRouteView.new()
	route.name = "PlayerTrackRoute"
	route.custom_minimum_size = Vector2(64,64)
	route.miniature = true
	for point: Variant in entry.get("points",[]):
		if point is Array and point.size() == 2: route.route.append(Vector2(float(point[0]),float(point[1])))
	row.add_child(route)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var track_name: Label = MenuStyle.label(str(entry.get("name","Track")),20)
	track_name.clip_text = true
	track_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(track_name)
	copy.add_child(MenuStyle.label(str(entry.get("theme","pine")).capitalize(),16,true))
	if entry.get("rating_average") != null:
		copy.add_child(MenuStyle.label("★ %.1f  ·  %d ratings" % [float(entry.rating_average),int(entry.get("rating_count",0))],16,true))
	track_count += 1
