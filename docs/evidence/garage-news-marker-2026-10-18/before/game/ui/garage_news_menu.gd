extends MarginContainer
## A personal racing newspaper. Only the receiving, visible pane requests data.
const Art = preload("res://ui/garage_news_art.gd")
const Examples = preload("res://ui/garage_news_examples.gd")
const SERIF: Font = preload("res://assets/fonts/libre_baskerville/LibreBaskerville.ttf")
const INK := Color("292e29")
const MUTED := Color("68665b")
const RED := Color("9c3c2b")
static var _photo_ink: ShaderMaterial
var page: Control
var service: Node
var _tab: String = "news"
var _list: VBoxContainer
var _tabs: Dictionary = {}
var _entry: LineEdit
var _add_row: HBoxContainer
var _poll: Timer
var _poll_count: int = 0
var _refresh_button: Button
var _waiting: bool = false
var _selected_id: String = ""
var _scroll: ScrollContainer
var _folio: Label
var _previous: Button
var _next: Button
var _status: Label
var _account_button: Button
var _examples: Array = []

func _ready() -> void:
	name = "GarageNewsMenu"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(440,260)
	for side: String in ["left","right","top","bottom"]: add_theme_constant_override("margin_"+side,20)
	# Background is drawn by this control, outside the container's children.
	var paper := PanelContainer.new()
	paper.name = "Newspaper"
	var stock := _box(Color("eee7d4"),18)
	stock.shadow_color = Color(0,0,0,0.45)
	stock.shadow_size = 12
	stock.shadow_offset = Vector2(4,6)
	paper.add_theme_stylebox_override("panel",stock)
	add_child(paper)
	var fibres := Art.new()
	fibres.kind = "paper"
	paper.add_child(fibres)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	paper.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var mast := VBoxContainer.new()
	mast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mast.add_theme_constant_override("separation",0)
	header.add_child(mast)
	_text(mast,"THE GARAGE JOURNAL",11,RED)
	_text(mast,"Trackside",40,INK,true)
	var controls := HBoxContainer.new()
	controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_theme_constant_override("separation",4)
	header.add_child(controls)
	for id: String in ["news","friends"]:
		var button := _button("Headlines" if id == "news" else "Friends",_select_tab.bind(id))
		controls.add_child(button)
		_tabs[id] = button
	_refresh_button = _button("",_open)
	_refresh_button.name = "RefreshNews"
	_refresh_button.icon = MenuIcon.texture("restart")
	_refresh_button.add_theme_color_override("icon_normal_color",INK)
	_refresh_button.add_theme_color_override("icon_hover_color",RED)
	_refresh_button.tooltip_text = "Check for new stories"
	controls.add_child(_refresh_button)
	_rule(column,2)
	var dateline := HBoxContainer.new()
	column.add_child(dateline)
	_status = _text(dateline,"YOUR RACING WORLD, IN PRINT",11,MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text(dateline,"PERSONAL EDITION",11,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rule(column)
	_add_row = HBoxContainer.new()
	column.add_child(_add_row)
	_entry = LineEdit.new()
	_entry.name = "FriendName"
	_entry.placeholder_text = "Exact racing name"
	_entry.max_length = 40
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.custom_minimum_size.y = 52
	_entry.add_theme_stylebox_override("normal",_box(Color("e3dbc6")))
	_entry.add_theme_color_override("font_color",INK)
	_entry.add_theme_color_override("font_placeholder_color",MUTED)
	_entry.add_theme_color_override("caret_color",RED)
	_entry.text_submitted.connect(func(_value: String) -> void: _send_friend())
	_add_row.add_child(_entry)
	_add_row.add_child(_button("Add driver",_send_friend))
	_scroll = ScrollContainer.new()
	_scroll.name = "NewsScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "NewsItems"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation",10)
	_scroll.add_child(_list)
	_rule(column,2)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	footer.add_child(_button("Garage",func() -> void:
		if _active(): page.call("_show_section","cars")))
	_folio = _text(footer,"",13,MUTED)
	_folio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_account_button = _button("Sign in",func() -> void: page.account_requested.emit())
	footer.add_child(_account_button)
	_previous = _button("Previous",_step.bind(-1))
	footer.add_child(_previous)
	_next = _button("Next story",_step.bind(1))
	footer.add_child(_next)
	_poll = Timer.new()
	_poll.one_shot = true
	_poll.timeout.connect(_poll_once)
	add_child(_poll)
	visibility_changed.connect(_visibility_changed)
	resized.connect(queue_redraw)
	if service != null: service.changed.connect(_changed)
	_render()
	_open.call_deferred()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("302c27"))
	for row: int in range(65):
		var grain := PackedVector2Array()
		for step: int in range(25):
			var x: float = size.x*step/24.0
			grain.append(Vector2(x,size.y*row/64.0+sin(x*0.013+row*2.8)*2.5))
		draw_polyline(grain,Color(0.65,0.48,0.30,0.07),1,true)
	draw_arc(Vector2(size.x-28,40),31,0,TAU,64,Color(0.05,0.02,0,0.4),3,true)
	draw_set_transform(Vector2(16,24),-0.008)
	draw_rect(Rect2(Vector2.ZERO,size-Vector2(32,40)),Color("beb7a4"))
	draw_set_transform(Vector2.ZERO)

func _active() -> bool:
	return is_visible_in_tree() and is_instance_valid(page) and page.section == "news" and page.tools.is_ancestor_of(self)

func _visibility_changed() -> void:
	if not _active():
		if is_instance_valid(_poll): _poll.stop()
	else: _open.call_deferred()

func _select_tab(id: String) -> void:
	_tab = id
	_waiting = false
	_poll.stop()
	_scroll.scroll_vertical = 0
	_render()
	_open()

func _open() -> void:
	if not _active() or service == null: return
	if service.busy:
		_waiting = true
		return
	_poll_count = 0
	if _tab == "friends": await service.load_friends()
	else: await service.refresh()
	if _active(): _changed()

func _changed() -> void:
	if not _active(): return
	_render()
	if _waiting and service != null and not service.busy:
		_waiting = false
		_open.call_deferred()
		return
	if _tab == "news" and service != null and service.refreshing and _poll.is_stopped() and _poll_count < 4:
		_poll.start(pow(2.0,_poll_count+1))

func _poll_once() -> void:
	if not _active() or _tab != "news" or service == null: return
	_poll_count += 1
	await service.refresh(true)

func _send_friend() -> void:
	if not _active() or service == null or _entry.text.strip_edges().is_empty(): return
	await service.friend_action("send",_entry.text.strip_edges())
	if is_instance_valid(_entry) and service.error.is_empty(): _entry.clear()

func _friend_action(action: String, id: String) -> void:
	if _active() and service != null: await service.friend_action(action,id)

func _race_story(item: Dictionary) -> void:
	if not _active() or _tab != "news" or not _has_race_track(item): return
	# A queued click must still belong to the current account's visible stories.
	for current: Dictionary in _stories():
		if current.get("id","") == item.get("id","") and current.get("version_id","") == item.get("version_id","") and current.get("authoring_id","") == item.get("authoring_id",""):
			page.news_race_requested.emit(current.duplicate(true))
			return

static func _has_race_track(item: Dictionary) -> bool:
	return not str(item.get("version_id","")).is_empty() or not str(item.get("authoring_id","")).is_empty()

static func _box(color: Color, padding: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_content_margin_all(padding)
	return box

func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(52,52)
	button.add_theme_font_size_override("font_size",18)
	for state: String in ["normal","disabled"]: button.add_theme_stylebox_override(state,_box(Color.TRANSPARENT))
	for state: String in ["hover","pressed"]: button.add_theme_stylebox_override(state,_box(Color("d8cfb8")))
	var focus := _box(Color.TRANSPARENT)
	focus.border_color = RED
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
	for state: String in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(state,INK)
	button.add_theme_color_override("font_disabled_color",Color("a9a28f"))
	button.pressed.connect(callback)
	return button

func _text(parent: Node, value: String, pixels: int = 16, color: Color = INK, serif: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font",SERIF if serif else MenuStyle.BODY)
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _rule(parent: Node, width: int = 1) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("8a8675")
	style.thickness = width
	line.add_theme_stylebox_override("separator",style)
	parent.add_child(line)

func _using_examples() -> bool:
	return _tab == "news" and (service == null or not service.available() or service.items.is_empty())

func _stories() -> Array:
	if _using_examples():
		if _examples.is_empty(): _examples = Examples.stories()
		return _examples
	return service.items if service != null and service.available() else []

func _index() -> int:
	var stories: Array = _stories()
	for index: int in range(stories.size()):
		if str(stories[index].get("id","")) == _selected_id: return index
	return 0

func _choose(index: int) -> void:
	var stories: Array = _stories()
	if not _active() or index < 0 or index >= stories.size(): return
	_selected_id = str(stories[index].get("id",""))
	_scroll.scroll_vertical = 0
	_render()

func _step(direction: int) -> void:
	if not _active(): return
	var index: int = _index()+direction
	if not _using_examples() and service != null and index >= service.items.size() and not service.next_cursor.is_empty(): await service.more()
	_choose(index)

func _render() -> void:
	if not is_instance_valid(_list): return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for id: String in _tabs: _tabs[id].add_theme_color_override("font_color",RED if id == _tab else INK)
	_add_row.visible = _tab == "friends" and service != null and service.available()
	var examples: bool = _using_examples()
	var stories: Array = _stories()
	var can_more: bool = not examples and service != null and not service.next_cursor.is_empty()
	_refresh_button.disabled = service == null or not service.available() or service.busy
	_previous.visible = _tab != "friends"
	_next.visible = _tab != "friends"
	_previous.disabled = _index() == 0
	_next.disabled = stories.is_empty() or (_index() >= stories.size()-1 and not can_more) or (not examples and service != null and service.busy)
	_account_button.visible = _tab != "friends" and (service == null or not service.client.signed_in())
	_folio.text = "DRIVERS' DIRECTORY" if _tab == "friends" else "THE PERSONAL EDITION"
	_status.text = "UPDATING YOUR EDITION..." if service != null and (service.busy or service.refreshing) else "YOUR RACING WORLD, IN PRINT"
	if _tab == "friends" and (service == null or not service.client.signed_in()):
		_empty("Your next chapter starts here.","Sign in for track milestones, records and news from your friends.")
		_list.add_child(_button("Sign in",func() -> void: page.account_requested.emit()))
		return
	if _tab == "friends" and not service.available():
		_empty("The presses are quiet.","News is unavailable on this server.")
		return
	if service != null and not service.error.is_empty(): _text(_list,service.error,16,RED)
	if _tab == "friends":
		_text(_list,"The drivers' directory",28,INK,true)
		if service.friends.is_empty(): _text(_list,"Add a racing name above to keep up with friends on the track.",16,MUTED)
		for item: Dictionary in service.friends: _friend_card(item)
		return
	var index: int = _index()
	var item: Dictionary = stories[index]
	_folio.text = "STORY %02d / %02d  ·  %s" % [index+1,stories.size(),Time.get_date_string_from_unix_time(int(item.get("created_at",0)))]
	var columns := HBoxContainer.new()
	columns.name = "EditorialColumns"
	columns.add_theme_constant_override("separation",20)
	_list.add_child(columns)
	var lead := VBoxContainer.new()
	lead.name = "LeadStory"
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.size_flags_stretch_ratio = 1.8
	lead.add_theme_constant_override("separation",6)
	columns.add_child(lead)
	_story(lead,item)
	if stories.size() < 2: return
	var divider := VSeparator.new()
	var ink := StyleBoxLine.new()
	ink.color = Color("a8a08b")
	ink.vertical = true
	divider.add_theme_stylebox_override("separator",ink)
	columns.add_child(divider)
	var briefs := VBoxContainer.new()
	briefs.name = "OtherStories"
	briefs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	briefs.add_theme_constant_override("separation",8)
	columns.add_child(briefs)
	_text(briefs,"ELSEWHERE IN YOUR GARAGE",11,RED)
	for offset: int in range(1,mini(stories.size(),4)):
		var other: int = (index+offset)%stories.size()
		_brief(briefs,stories[other],other)

func _empty(title: String, detail: String) -> void:
	_text(_list,title,30,INK,true)
	_text(_list,detail,18,MUTED)

static func _category(item: Dictionary) -> String:
	match str(item.get("kind","")):
		"milestone": return "CIRCUIT MILESTONE"
		"world_record": return "WORLD RECORD"
		"friend_overtake": return "FRIENDLY RIVALRY"
		"percentile_drop": return "THE CHASING PACK"
		"friend_track": return "NEW CIRCUIT"
	return "PADDOCK NEWS"

static func _headline(item: Dictionary) -> String:
	match str(item.get("kind","")):
		"milestone": return "%s racers take the start." % _count(int(item.get("count",0)))
		"world_record": return "A new %s record." % ("lap" if item.get("metric","") == "lap" else "track")
		"friend_overtake": return "%s moves ahead." % str(item.get("actor_name","A friend"))
		"percentile_drop": return "Time for a comeback."
		"friend_track": return "%s's latest creation." % str(item.get("actor_name","A friend"))
	return "From the paddock."

func _story(parent: VBoxContainer, item: Dictionary) -> void:
	var track: String = str(item.get("track_name",""))
	var vehicle: String = str(item.get("vehicle_id",""))
	var byline := HBoxContainer.new()
	byline.add_theme_constant_override("separation",12)
	parent.add_child(byline)
	var category := _text(byline,_category(item),12,RED)
	category.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	category.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text(byline,track.to_upper()+("  /  "+VehicleCatalog.title(vehicle) if vehicle in VehicleCatalog.IDS else ""),14,MUTED)
	_text(parent,_headline(item),30,INK,true)
	var media := HBoxContainer.new()
	media.name = "StoryMedia"
	media.custom_minimum_size.y = 114
	media.add_theme_constant_override("separation",12)
	parent.add_child(media)
	if vehicle in VehicleCatalog.IDS:
		var photograph := VBoxContainer.new()
		photograph.name = "NewsPhotograph"
		photograph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		photograph.size_flags_stretch_ratio = 1.5
		photograph.add_theme_constant_override("separation",5)
		media.add_child(photograph)
		var photo := TextureRect.new()
		photo.name = "NewsCarPhoto"
		photo.texture = load("res://assets/news/vehicles/%s.png" % vehicle)
		photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if _photo_ink == null:
			_photo_ink = ShaderMaterial.new()
			_photo_ink.shader = preload("res://ui/garage_news_photo.gdshader")
		photo.material = _photo_ink
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.custom_minimum_size.y = 114
		photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photograph.add_child(photo)
		var caption := _text(photograph,VehicleCatalog.title(vehicle).capitalize()+". "+("Lap" if item.get("metric","") == "lap" else "Track")+" times at "+track+".",13,MUTED,true)
		caption.name = "NewsPhotoCaption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var map_column := VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media.add_child(map_column)
	var map := Art.new()
	map.name = "NewsCircuit"
	map.kind = "circuit"
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size.y = 112
	var raw: Variant = item.get("track_points",[])
	if raw is Array:
		for point: Variant in raw.slice(0,96):
			if point is Array and point.size() >= 2 and (point[0] is float or point[0] is int) and (point[1] is float or point[1] is int):
				var p := Vector2(float(point[0]),float(point[1]))
				if is_finite(p.x) and is_finite(p.y) and absf(p.x) <= 100000 and absf(p.y) <= 100000: map.points.append(p)
	map_column.add_child(map)
	_text(map_column,"CIRCUIT OUTLINE" if map.points.size() >= 2 else "OUTLINE UNAVAILABLE",10,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var metric: String = "lap" if item.get("metric","") == "lap" else "track"
	var actor: String = str(item.get("actor_name","A racer"))
	var body: String = ""
	match str(item.get("kind","")):
		"milestone": body = "Your track has now welcomed %s different racers. %s is making a name for itself." % [_count(int(item.get("count",0))),track]
		"world_record": body = "%s has set a new %s world record on %s." % [actor,metric,track]
		"friend_overtake": body = "%s has beaten your best %s time on %s. A new target for your next visit." % [actor,metric,track]
		"percentile_drop": body = "Your %s time on %s has slipped outside the top %d%%. The competition is moving." % [metric,track,int(item.get("threshold",0))]
		"friend_track": body = "%s has published a new track: %s. A fresh circuit to try." % [actor,track]
	_text(parent,body,17)
	var closing := HBoxContainer.new()
	closing.name = "StoryClosing"
	closing.add_theme_constant_override("separation",12)
	parent.add_child(closing)
	var times := VBoxContainer.new()
	times.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	times.add_theme_constant_override("separation",2)
	closing.add_child(times)
	if item.has("time_ticks"): _text(times,_time(int(item.time_ticks),int(item.get("tick_rate",120)))+"  /  "+metric.to_upper()+" TIME",23,RED)
	if item.has("your_ticks"): _text(times,"Your best  "+_time(int(item.your_ticks),int(item.get("tick_rate",120))),14,MUTED)
	if _has_race_track(item):
		var race := _button("Race track",_race_story.bind(item))
		race.name = "GarageNewsRace"
		race.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		race.custom_minimum_size.x = 176
		race.add_theme_font_override("font",SERIF)
		race.tooltip_text = "Race "+track
		for state: String in ["normal","hover","pressed","focus"]:
			race.add_theme_stylebox_override(state,_box(Color.TRANSPARENT))
		for state: String in ["font_hover_color","font_pressed_color","font_focus_color"]:
			race.add_theme_color_override(state,RED)
		closing.add_child(race)

func _brief(parent: Node, item: Dictionary, index: int) -> void:
	_rule(parent)
	var button := _button("",_choose.bind(index))
	button.name = "NewsBrief"+str(index)
	parent.add_child(button)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	MenuStyle.fill(margin)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,5)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",5)
	margin.add_child(column)
	_text(column,_category(item),10,RED)
	_text(column,_headline(item),18,INK,true)
	_text(column,str(item.get("track_name","")),13,MUTED)
	column.minimum_size_changed.connect(func() -> void: button.custom_minimum_size.y = maxf(70,column.get_combined_minimum_size().y+10))

func _friend_card(item: Dictionary) -> void:
	_rule(_list)
	var row := HBoxContainer.new()
	_list.add_child(row)
	var name_column := VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_column)
	_text(name_column,str(item.get("display_name","")),20,INK,true)
	var status: String = str(item.get("status",""))
	_text(name_column,"Request sent" if status == "sent" else "Wants to race with you" if status == "received" else "Racing friend",13,MUTED)
	if status == "received":
		var accept := _button("Accept",_friend_action.bind("accept",str(item.player_id)))
		accept.disabled = service.busy
		row.add_child(accept)
	var remove := _button("Decline" if status == "received" else "Cancel" if status == "sent" else "Remove",_friend_action.bind("remove",str(item.player_id)))
	remove.disabled = service.busy
	row.add_child(remove)

static func _time(ticks: int, rate: int) -> String:
	var seconds: float = float(ticks)/maxi(1,rate)
	return "%d:%06.3f" % [int(seconds/60.0),fmod(seconds,60.0)]

static func _count(value: int) -> String:
	return "10,000" if value == 10000 else "1,000" if value == 1000 else str(value)

func _exit_tree() -> void:
	if service != null and service.changed.is_connected(_changed): service.changed.disconnect(_changed)
