extends AcceptDialog
## A frozen creation receipt. Platform sharing remains an explicit player action.
signal share_requested
var snapshot: Dictionary = {}
var context_current: Callable

func _ready() -> void:
	name = "ChallengeReadyDialog"
	title = "Your challenge is ready"
	ok_button_text = "Share invite"
	var content := VBoxContainer.new()
	var viewport_width: float = get_parent().get_viewport().get_visible_rect().size.x
	var viewport_height: float = get_parent().get_viewport().get_visible_rect().size.y
	content.custom_minimum_size.x = minf(520,viewport_width-88)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(420,maxf(100,viewport_height-210))
	add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right",12)
	scroll.add_child(gutter)
	gutter.add_child(content)
	content.add_child(MenuStyle.label("Share the invite. Start the chase.",18,true))
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel",MenuStyle.card(18))
	content.add_child(panel)
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(str(snapshot.entry.get("theme","pine")))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.07,0.1,0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shade)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",8)
	row.add_child(text)
	var group: bool = snapshot.get("mode") != "beat"
	text.add_child(MenuStyle.label("UP TO 20 DRIVERS" if group else "YOU + ONE RIVAL",14,true))
	var heading := MenuStyle.label("3×3 CHALLENGE" if snapshot.get("mode") == "3x3" else "CUSTOM CHALLENGE" if ChallengesClient.is_series(snapshot) else str(snapshot.entry.name),30)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(heading)
	if ChallengesClient.is_series(snapshot):
		for stage: Dictionary in snapshot.get("stages",[]): text.add_child(MenuStyle.label(str(int(stage.index)+1)+"  "+str(stage.entry.name),20))
	text.add_child(MenuStyle.label("LOWEST TOTAL TIME WINS" if ChallengesClient.is_series(snapshot) else "BEST TIME WINS" if group else "CAN YOU BEAT",13,true))
	var time_value: Variant = snapshot.get("target_ms")
	if time_value == null:
		for driver: Dictionary in snapshot.get("standings",[]):
			if str(driver.get("id","")) == str(snapshot.get("creator_id","")):
				time_value = driver.get("ms")
				break
	var time := MenuStyle.label(MenuStyle.time_text(float(time_value)/1000.0) if time_value != null else "Open grid",52)
	time.name = "ChallengeReadyTime"
	time.add_theme_color_override("font_color",MenuStyle.ACCENT)
	text.add_child(time)
	text.add_child(MenuStyle.label(VehicleCatalog.title(str(snapshot.vehicle_id))+" · 5 laps",16,true))
	var seconds: int = int(snapshot.get("ends_at",0))-int(snapshot.get("created_at",0))
	var duration: String = "24 hours" if seconds == 86400 else "3 days" if seconds == 259200 else "7 days"
	var limit: int = 0 if snapshot.get("attempt_limit") == null else int(snapshot.attempt_limit)
	if ChallengesClient.is_series(snapshot): limit = int(snapshot.stages[0].attempt_limit) if snapshot.stages[0].attempt_limit != null else 0
	text.add_child(MenuStyle.label(duration+" · "+("Unlimited tries" if limit == 0 else str(limit)+(" try" if limit == 1 else " tries")+(" per track" if ChallengesClient.is_series(snapshot) else " per driver")),16,true))
	var route := LapRouteView.new()
	route.miniature = true
	route.custom_minimum_size = Vector2(140,160)
	route.visible = viewport_width >= 600
	for point: Array in snapshot.entry.get("points",[]): route.route.append(Vector2(point[0],point[1]))
	row.add_child(route)
	add_button("My challenges",false,"view")
	custom_action.connect(func(action: StringName) -> void:
		if action == &"view":
			hide()
			queue_free())
	confirmed.connect(func() -> void:
		if not context_current.is_valid() or context_current.call(): share_requested.emit())
	about_to_popup.connect(_fit_heading,CONNECT_DEFERRED)

func _fit_heading() -> void:
	if size.x >= 600: return
	var chrome: Node = get_node_or_null("PopupStyle")
	if chrome != null and is_instance_valid(chrome.header): chrome.header.add_theme_font_size_override("font_size",24)

func _process(_delta: float) -> void:
	if context_current.is_valid() and not context_current.call():
		hide()
		queue_free()
