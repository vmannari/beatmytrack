extends MarginContainer
## A personal racing newspaper. Only the receiving, visible pane requests data.
const Art = preload("res://ui/garage_news_art.gd")
const Examples = preload("res://ui/garage_news_examples.gd")
const SERIF: Font = preload("res://assets/fonts/libre_baskerville/LibreBaskerville.ttf")
const ITALIC: Font = preload("res://assets/fonts/libre_baskerville/LibreBaskerville-Italic.ttf")
const INK := Color("292e29")
const MUTED := Color("68665b")
const RED := Color("9c3c2b")
const STORY_TURN_SECONDS: float = 0.52
const TURN_SHADER: Shader = preload("res://ui/garage_news_turn.gdshader")
static var _photo_ink: ShaderMaterial
static var _bold_serif: FontVariation
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
var _reading_scope: String = ""
var _local_read_ids: Dictionary = {}
var _scroll: ScrollContainer
var _brief_scroll: ScrollContainer
var _brief_offset: int = 0
var _brief_restore_pending: bool = false
var _folio: Label
var _previous: Button
var _next: Button
var _status: Label
var _account_button: Button
var _navigation_separator: VSeparator
var _examples: Array = []
var _masthead: Label
var _masthead_header: HBoxContainer
var _tagline: Label
var _layout_size := Vector2.ZERO
var _layout_queued: bool = false
var _spread: PanelContainer
var _story_motion: Tween
var _tab_turn: bool = false
var _outgoing_story: Control
var _turn_viewport: SubViewport
var _turn_material: ShaderMaterial
var _paper: PanelContainer
var _paper_host: Control
var _ranking: Control
var _controls: HFlowContainer
var _ranking_footer: HFlowContainer
var _eyebrow: Label

func _ready() -> void:
	name = "GarageNewsMenu"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(440,260)
	for side: String in ["left","right","top","bottom"]: add_theme_constant_override("margin_"+side,20)
	# The sheet keeps the allocated page rectangle while its replacement lays
	# out. Temporary wrapped text must not resize the surrounding Garage UI.
	_paper_host = Control.new()
	_paper_host.name = "NewspaperArea"
	_paper_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paper_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_paper_host)
	_build_paper()
	_poll = Timer.new()
	_poll.one_shot = true
	_poll.timeout.connect(_poll_once)
	add_child(_poll)
	visibility_changed.connect(_visibility_changed)
	resized.connect(queue_redraw)
	resized.connect(_queue_layout)
	if service != null: service.changed.connect(_changed)
	_render()
	_open.call_deferred()
	_queue_layout()

func _build_paper() -> void:
	_tabs.clear()
	# Background is drawn by this control, outside the container's children.
	var paper := PanelContainer.new()
	_paper = paper
	paper.name = "Newspaper"
	var stock := _box(Color("eee7d4"),0)
	stock.shadow_color = Color(0,0,0,0.45)
	stock.shadow_size = 12
	stock.shadow_offset = Vector2(4,6)
	paper.add_theme_stylebox_override("panel",stock)
	_paper_host.add_child(paper)
	MenuStyle.fill(paper)
	paper.minimum_size_changed.connect(_fit_paper.bind(paper).call_deferred)
	var fibres := Art.new()
	fibres.kind = "paper"
	paper.add_child(fibres)
	var content := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: content.add_theme_constant_override("margin_"+side,18)
	paper.add_child(content)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	content.add_child(column)
	var header := HBoxContainer.new()
	_masthead_header = header
	header.add_theme_constant_override("separation",18)
	column.add_child(header)
	var mast := VBoxContainer.new()
	mast.add_theme_constant_override("separation",0)
	header.add_child(mast)
	_eyebrow = _text(mast,"THE GARAGE JOURNAL",14,RED)
	_masthead = _text(mast,"Trackside",64 if size.x >= 1360 else 58,INK,true)
	_masthead.name = "NewsMasthead"
	_masthead.add_theme_font_override("font",_headline_font())
	_masthead.autowrap_mode = TextServer.AUTOWRAP_OFF
	_vertical_rule(header)
	_tagline = _text(header,"YOUR RACING WORLD,\nIN PRINT",17,MUTED)
	_tagline.name = "NewsTagline"
	_tagline.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tagline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tagline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var controls := HFlowContainer.new()
	_controls = controls
	controls.add_theme_constant_override("separation",4)
	header.add_child(controls)
	for id: String in ["news","friends","ranking"]:
		var button := _button({"news":"Headlines","friends":"Friends","ranking":"World Ranking"}[id],_select_tab.bind(id))
		button.name = "NewsTab_"+id
		controls.add_child(button)
		_tabs[id] = button
	_refresh_button = _button("",_open)
	_refresh_button.name = "RefreshNews"
	_refresh_button.icon = MenuIcon.texture("restart")
	_refresh_button.add_theme_color_override("icon_normal_color",INK)
	_refresh_button.add_theme_color_override("icon_hover_color",RED)
	_refresh_button.add_theme_color_override("icon_disabled_color",MUTED)
	_refresh_button.tooltip_text = "Check for new stories"
	controls.add_child(_refresh_button)
	var dateline := HBoxContainer.new()
	dateline.add_theme_constant_override("separation",10)
	column.add_child(dateline)
	var mast_rule := HSeparator.new()
	mast_rule.name = "MastheadRule"
	mast_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heavy_ink := StyleBoxLine.new()
	heavy_ink.color = INK
	heavy_ink.thickness = 2
	mast_rule.add_theme_stylebox_override("separator",heavy_ink)
	dateline.add_child(mast_rule)
	_status = _text(dateline,"PERSONAL EDITION",13,MUTED)
	_status.size_flags_horizontal = Control.SIZE_SHRINK_END
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	_spread = PanelContainer.new()
	_spread.name = "StorySpread"
	_spread.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_spread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spread.clip_contents = true
	_scroll.add_child(_spread)
	_list = VBoxContainer.new()
	_list.name = "NewsItems"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation",10)
	_spread.add_child(_list)
	_rule(column,2)
	var footer := HBoxContainer.new()
	footer.name = "NewsFooter"
	footer.add_theme_constant_override("separation",12)
	column.add_child(footer)
	footer.add_child(_button("Garage",func() -> void:
		if _active(): page.call("_show_section","cars")))
	_vertical_rule(footer)
	_folio = _text(footer,"",16,MUTED)
	_folio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ranking_footer = HFlowContainer.new()
	_ranking_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_ranking_footer)
	_account_button = _button("Sign in",func() -> void: page.account_requested.emit())
	footer.add_child(_account_button)
	_previous = _button("‹  Previous",_step.bind(-1))
	footer.add_child(_previous)
	_navigation_separator = _vertical_rule(footer)
	_next = _button("Next story  ›",_step.bind(1))
	footer.add_child(_next)

static func _headline_font() -> Font:
	if _bold_serif == null:
		_bold_serif = FontVariation.new()
		_bold_serif.base_font = SERIF
		_bold_serif.variation_opentype = {0x77676874:700.0} # OpenType wght axis.
	return _bold_serif

func _fit_paper(paper: Control) -> void:
	if is_instance_valid(paper) and paper.get_parent() == _paper_host: MenuStyle.fill(paper)

func _queue_layout() -> void:
	if _layout_queued: return
	_layout_queued = true
	_apply_layout.call_deferred()

func _apply_layout() -> void:
	_layout_queued = false
	if not is_inside_tree() or size.is_equal_approx(_layout_size): return
	_layout_size = size
	_layout_header()
	if _tab != "ranking": _render()

func _layout_header() -> void:
	var narrow: bool = size.x < 900
	_masthead.add_theme_font_size_override("font_size",34 if narrow else 44 if size.x < 1100 else 64 if size.x >= 1360 else 58)
	_masthead_header.add_theme_constant_override("separation",8 if narrow else 18)
	for button: Button in _tabs.values(): button.add_theme_font_size_override("font_size",19)
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_controls.alignment = FlowContainer.ALIGNMENT_END

func _vertical_rule(parent: Node) -> VSeparator:
	var line := VSeparator.new()
	line.size_flags_vertical = Control.SIZE_FILL
	var style := StyleBoxLine.new()
	style.color = Color("99917d")
	style.vertical = true
	line.add_theme_stylebox_override("separator",style)
	parent.add_child(line)
	return line

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
		_finish_story_turn()
	else: _open.call_deferred()

func _select_tab(id: String) -> void:
	var tabs: Array[String] = ["news","friends","ranking"]
	var old_index: int = tabs.find(_tab)
	var new_index: int = tabs.find(id)
	var direction: int = 0 if old_index == new_index or new_index < 0 else 1 if new_index > old_index else -1
	_tab = id
	_waiting = false
	_poll.stop()
	_scroll.scroll_vertical = 0
	_render(direction,direction != 0)
	if _tab != "ranking": _open()

func _open() -> void:
	if _tab == "ranking":
		if _active() and is_instance_valid(_ranking): _ranking.refresh()
		return
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
	if _tab == "ranking": return
	_render()
	if _waiting and service != null and not service.busy:
		_waiting = false
		_open.call_deferred()
		return
	# A daily pass may span many batches. Keep checking while it is active so
	# stories from later boards appear without reopening the newspaper.
	if _tab == "news" and service != null and not service.busy and service.refreshing and _poll.is_stopped() and _poll_count < 120:
		_poll.start(5.0)

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
	button.add_theme_font_override("font",MenuStyle.DISPLAY)
	button.add_theme_font_size_override("font_size",21)
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
	label.add_theme_font_override("font",SERIF if serif else MenuStyle.DISPLAY)
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _rule(parent: Node, width: int = 1) -> void:
	var line := HSeparator.new()
	line.add_theme_constant_override("separation",width)
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

func _story_read(item: Dictionary, examples: bool) -> bool:
	var id: String = str(item.get("id",""))
	return service.story_read(id,examples) if service != null else _local_read_ids.has(id)

func _mark_story_read(item: Dictionary, examples: bool) -> void:
	var id: String = str(item.get("id",""))
	if service != null: service.mark_story_read(id,examples)
	elif not id.is_empty(): _local_read_ids[id] = true

func _more_stories() -> void:
	if _active() and _tab == "news" and service != null and not service.busy:
		await service.more()

func _index() -> int:
	var stories: Array = _stories()
	for index: int in range(stories.size()):
		if str(stories[index].get("id","")) == _selected_id: return index
	return 0

func _choose(index: int) -> void:
	var stories: Array = _stories()
	if not _active() or _tab != "news" or index < 0 or index >= stories.size() or index == _index(): return
	var direction: int = 1 if index > _index() else -1
	_selected_id = str(stories[index].get("id",""))
	_scroll.scroll_vertical = 0
	_render(direction)

func _step(direction: int) -> void:
	if not _active() or _tab != "news": return
	var index: int = _index()+direction
	if not _using_examples() and service != null and index >= service.items.size() and not service.next_cursor.is_empty():
		var identity: String = service.scope()
		var selected: String = _selected_id
		await service.more()
		if not _active() or _tab != "news" or identity != service.scope() or selected != _selected_id: return
	_choose(index)

func _finish_story_turn() -> void:
	if _story_motion != null: _story_motion.kill()
	_story_motion = null
	_tab_turn = false
	if is_instance_valid(_outgoing_story):
		_outgoing_story.get_parent().remove_child(_outgoing_story)
		_outgoing_story.queue_free()
	_outgoing_story = null
	_turn_viewport = null
	_turn_material = null
	if is_instance_valid(_list):
		_list.scale = Vector2.ONE
		_list.pivot_offset = Vector2.ZERO
		_list.modulate = Color.WHITE
	if is_instance_valid(_paper):
		for slot: Node in _paper.find_children("*Slot","Control",true,false):
			if slot.has_meta("news_column_content"):
				_update_column_minimum(slot.get_meta("news_column_content"),slot)

func _retire_story(node: Node) -> void:
	# The outgoing print is visual only, including any already-focused buttons.
	node.name = "Outgoing"+str(node.name)
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	if node is BaseButton: node.disabled = true
	for child: Node in node.get_children(): _retire_story(child)

func _set_story_turn(weight: float) -> void:
	if _turn_material != null: _turn_material.set_shader_parameter("progress",weight)

func _prepare_page_turn(outgoing: Control, direction: int) -> void:
	_outgoing_story = Control.new()
	_outgoing_story.name = "OutgoingStory"
	_outgoing_story.mouse_filter = Control.MOUSE_FILTER_STOP
	_paper_host.add_child(_outgoing_story)
	_outgoing_story.position = _paper.position
	_outgoing_story.size = outgoing.size
	MenuStyle.fill(_outgoing_story)
	_turn_viewport = SubViewport.new()
	_turn_viewport.name = "PrintedPage"
	_turn_viewport.disable_3d = true
	_turn_viewport.transparent_bg = false
	var logical := Vector2i(maxi(1,ceili(outgoing.size.x)),maxi(1,ceili(outgoing.size.y)))
	var resolution: float = minf(1.0,minf(2048.0/logical.x,1024.0/logical.y))
	_turn_viewport.size = Vector2i(maxi(1,int(logical.x*resolution)),maxi(1,int(logical.y*resolution)))
	_turn_viewport.size_2d_override = logical
	_turn_viewport.size_2d_override_stretch = true
	_turn_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_outgoing_story.add_child(_turn_viewport)
	_turn_viewport.add_child(outgoing)
	outgoing.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	outgoing.position = Vector2.ZERO
	outgoing.size = Vector2(logical)
	_turn_material = ShaderMaterial.new()
	_turn_material.shader = TURN_SHADER
	_turn_material.set_shader_parameter("page_size",Vector2(logical))
	_turn_material.set_shader_parameter("turn_direction",float(direction))
	var sheet := TextureRect.new()
	sheet.name = "TurningPaper"
	sheet.texture = _turn_viewport.get_texture()
	sheet.material = _turn_material
	sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outgoing_story.add_child(sheet)
	MenuStyle.fill(sheet)

func _column_slot(parent: BoxContainer, content: Control, ratio: float = 1.0) -> void:
	# BoxContainer distributes only spare width. Zero-width slots give both
	# columns the same proportions regardless of captions, buttons or names.
	var slot := Control.new()
	slot.name = str(content.name)+"Slot"
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.size_flags_stretch_ratio = ratio
	slot.clip_contents = true
	slot.set_meta("news_column_content",content)
	parent.add_child(slot)
	slot.add_child(content)
	MenuStyle.fill(content)
	content.minimum_size_changed.connect(_update_column_minimum.bind(content,slot).call_deferred)
	slot.resized.connect(_update_column_minimum.bind(content,slot).call_deferred)

func _update_column_minimum(content: Control, slot: Control) -> void:
	if not is_instance_valid(content) or not is_instance_valid(slot): return
	if _story_motion != null: return
	# Do not propagate a zero-width label's temporary wrapped height into the
	# paper while a fresh sheet is still receiving its real column widths.
	if slot.size.x > 1.0 and is_equal_approx(content.size.x,slot.size.x):
		slot.custom_minimum_size.y = content.get_combined_minimum_size().y

func _render(direction: int = 0, tab_turn: bool = false) -> void:
	if not is_instance_valid(_list): return
	if is_instance_valid(_brief_scroll) and not _brief_restore_pending: _brief_offset = _brief_scroll.scroll_vertical
	_brief_scroll = null
	_brief_restore_pending = false
	# Feed updates may arrive while a tab is turning; update the live page
	# underneath without interrupting the printed sheet.
	if direction != 0 or not _tab_turn: _finish_story_turn()
	var outgoing: Control
	if direction != 0 and _list.get_child_count() > 0:
		outgoing = _paper
		# Preserve the exact inherited type/spacing when printing offscreen.
		var source: Control = self
		while source != null:
			if source.theme != null:
				outgoing.theme = source.theme
				break
			source = source.get_parent_control()
		_paper_host.remove_child(outgoing)
		_retire_story(outgoing)
		_build_paper()
		_prepare_page_turn(outgoing,direction)
		_tab_turn = tab_turn
		_set_story_turn(0.0)
		_story_motion = create_tween()
		_story_motion.tween_method(_set_story_turn,0.0,1.0,STORY_TURN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_story_motion.tween_callback(_finish_story_turn)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_ranking = null
	for child: Node in _ranking_footer.get_children():
		_ranking_footer.remove_child(child)
		child.queue_free()
	_ranking_footer.visible = _tab == "ranking"
	_folio.visible = _tab != "ranking"
	_layout_header()
	for id: String in _tabs:
		_tabs[id].add_theme_color_override("font_color",RED if id == _tab else INK)
		var active := _box(Color.TRANSPARENT)
		if id == _tab:
			active.border_color = RED
			active.border_width_bottom = 2
		_tabs[id].add_theme_stylebox_override("normal",active)
	_add_row.visible = _tab == "friends" and service != null and service.available()
	var examples: bool = _using_examples()
	var stories: Array = _stories()
	var reading_scope: String = "examples" if examples else service.scope() if service != null else ""
	if reading_scope != _reading_scope:
		_reading_scope = reading_scope
		_selected_id = ""
		_brief_offset = 0
	var can_more: bool = not examples and service != null and not service.next_cursor.is_empty()
	_refresh_button.disabled = service == null or not service.available() or service.busy
	_previous.visible = _tab == "news"
	_next.visible = _tab == "news"
	_navigation_separator.visible = _tab == "news"
	_previous.disabled = _index() == 0
	_next.disabled = stories.is_empty() or (_index() >= stories.size()-1 and not can_more) or (not examples and service != null and service.busy)
	_account_button.visible = _tab != "friends" and (service == null or not service.client.signed_in())
	_folio.text = "DRIVERS' DIRECTORY" if _tab == "friends" else "THE PERSONAL EDITION"
	_status.text = "UPDATING YOUR EDITION…" if service != null and (service.busy or service.refreshing) else "PERSONAL EDITION"
	if _tab == "ranking":
		_folio.text = "WORLD RANKING"
		_status.text = "COMPACT CIRCUIT"
		_refresh_button.disabled = false
		_refresh_button.tooltip_text = "Refresh World Ranking"
		_ranking = preload("res://ui/garage_news_ranking.gd").new()
		_ranking.newspaper = self
		_ranking.client = service.client if service != null else null
		_list.add_child(_ranking)
		return
	_refresh_button.tooltip_text = "Check for new stories"
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
	_selected_id = str(item.get("id",""))
	if _active(): _mark_story_read(item,examples)
	_folio.text = GameText.message("STORY %02d / %02d  ·  %s") % [index+1,stories.size(),Time.get_date_string_from_unix_time(int(item.get("created_at",0)))]
	var columns := HBoxContainer.new()
	columns.name = "EditorialColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",20)
	_list.add_child(columns)
	var lead := VBoxContainer.new()
	lead.name = "LeadStory"
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.size_flags_stretch_ratio = 1.85
	lead.add_theme_constant_override("separation",3 if size.y < 620 else 6)
	_column_slot(columns,lead,1.85)
	_story(lead,item)
	if stories.size() < 2 and not can_more: return
	_vertical_rule(columns)
	var briefs := VBoxContainer.new()
	briefs.name = "OtherStories"
	briefs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	briefs.add_theme_constant_override("separation",1)
	_column_slot(columns,briefs)
	_text(briefs,"ELSEWHERE IN YOUR GARAGE",14,RED)
	var brief_scroll: ScrollContainer = preload("res://ui/vertical_swipe_scroll.gd").new()
	_brief_scroll = brief_scroll
	brief_scroll.name = "OtherStoriesScroll"
	brief_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brief_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	brief_scroll.follow_focus = true
	briefs.add_child(brief_scroll)
	var brief_list := VBoxContainer.new()
	brief_list.name = "OtherStoriesList"
	brief_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brief_list.add_theme_constant_override("separation",1)
	brief_scroll.add_child(brief_list)
	# Keep feed/navigation order intact; only the side list groups unread first.
	for read: bool in [false,true]:
		for other: int in range(stories.size()):
			if other != index and _story_read(stories[other],examples) == read:
				_brief(brief_list,stories[other],other)
	if can_more:
		var more := _button("Load older stories",_more_stories)
		more.name = "NewsLoadOlder"
		brief_list.add_child(more)
	brief_scroll.resized.connect(_size_briefs.bind(brief_scroll,brief_list).call_deferred)
	_size_briefs.call_deferred(brief_scroll,brief_list)
	_brief_restore_pending = true
	_restore_brief_scroll.call_deferred(brief_scroll,_brief_offset)

func _size_briefs(scroll: ScrollContainer, list: VBoxContainer) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(list) or scroll.size.y <= 1.0: return
	var separation: int = list.get_theme_constant("separation")
	var row: int = 0
	var rule_height: float = 0.0
	for child: Control in list.get_children():
		if child is HSeparator:
			rule_height = child.get_combined_minimum_size().y
		elif child is Button and child.name.begins_with("NewsBrief"):
			# Divide the viewport into five whole rows, distributing remainder
			# pixels so a sixth headline cannot peek in at the bottom.
			var slot: float = floorf((row+1)*scroll.size.y/5.0)-floorf(row*scroll.size.y/5.0)
			child.set_meta("news_row_height",maxf(40.0,slot-rule_height-2*separation))
			_update_brief_height(child.get_child(0).get_child(0),child)
			row += 1

func _restore_brief_scroll(scroll: ScrollContainer, offset: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and scroll == _brief_scroll:
		scroll.scroll_vertical = offset
		_brief_restore_pending = false

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
		"track_published": return "TRACK PUBLISHED"
	return "PADDOCK NEWS"

static func _headline(item: Dictionary) -> String:
	match str(item.get("kind","")):
		"milestone": return GameText.message("%s racers take the start.") % _count(int(item.get("count",0)))
		"world_record": return GameText.message("A new %s record.") % (GameText.message("lap") if item.get("metric","") == "lap" else GameText.message("track"))
		"friend_overtake": return GameText.message("%s moves ahead.") % str(item.get("actor_name",GameText.message("A friend")))
		"percentile_drop": return "Time for a comeback."
		"friend_track": return GameText.message("%s's latest creation.") % str(item.get("actor_name",GameText.message("A friend")))
		"track_published": return "Your track is ready to race."
	return "From the paddock."

func _story_uses_local_appearance(item: Dictionary, file_photo: bool) -> bool:
	var own: bool = file_photo or item.get("kind","") == "percentile_drop"
	if service != null and service.client != null:
		var actor_id: String = str(item.get("actor_id",""))
		own = own or (not actor_id.is_empty() and actor_id == str(service.client.player.get("id","")))
	return own

func _story_appearance(item: Dictionary, vehicle: String, file_photo: bool) -> Dictionary:
	if _story_uses_local_appearance(item,file_photo) and page is GaragePage and page.records != null:
		return preload("res://persistence/appearance_state.gd").car(page.records.settings,vehicle)
	var appearance: Variant = item.get("appearance",{})
	if preload("res://persistence/appearance_state.gd").valid_car(appearance) and appearance.vehicle_id == vehicle:
		return appearance.duplicate(true)
	return {}

func _reveal_news_car(view: Control, fallback: Control, loading: Control) -> void:
	while is_instance_valid(view) and view.is_inside_tree() and not view.presentation_ready:
		await get_tree().process_frame
	if is_instance_valid(view) and view.is_inside_tree() and is_instance_valid(fallback):
		fallback.hide()
		if is_instance_valid(loading): loading.hide()
		view.show()

func _story(parent: VBoxContainer, item: Dictionary) -> void:
	var track: String = str(item.get("track_name",""))
	var vehicle: String = str(item.get("vehicle_id",""))
	var file_photo: bool = vehicle.is_empty() and item.get("kind","") == "milestone"
	if file_photo: vehicle = VehicleCatalog.selected
	var appearance: Dictionary = _story_appearance(item,vehicle,file_photo) if vehicle in VehicleCatalog.IDS else {}
	var wide: bool = size.x >= 1360
	var short_page: bool = size.y < 620
	var byline := HBoxContainer.new()
	byline.add_theme_constant_override("separation",12)
	parent.add_child(byline)
	var category := _text(byline,_category(item),16,RED)
	category.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	category.autowrap_mode = TextServer.AUTOWRAP_OFF
	GameText.user_text(_text(byline,"/  "+track.to_upper(),16,MUTED))
	var headline_size: int = 42 if short_page else 48 if wide else 46
	var headline := _text(parent,_headline(item),headline_size,INK,true)
	headline.name = "NewsHeadline"
	headline.add_theme_font_override("font",_headline_font())
	headline.resized.connect(_fit_headline.bind(headline,headline_size,32))
	var media := HBoxContainer.new()
	media.name = "StoryMedia"
	media.custom_minimum_size.y = 142 if short_page else 158
	media.size_flags_vertical = Control.SIZE_EXPAND_FILL
	media.add_theme_constant_override("separation",16)
	parent.add_child(media)
	if vehicle in VehicleCatalog.IDS:
		var photograph := VBoxContainer.new()
		photograph.name = "NewsPhotograph"
		photograph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		photograph.size_flags_stretch_ratio = 1.5
		photograph.add_theme_constant_override("separation",5)
		_column_slot(media,photograph,1.5)
		var photo_frame := PanelContainer.new()
		photo_frame.name = "NewsPhotoFrame"
		photo_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		photo_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		photo_frame.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		photograph.add_child(photo_frame)
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
		photo.custom_minimum_size.y = 116 if short_page else 132
		photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
		photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo_frame.add_child(photo)
		if not appearance.is_empty():
			# Do not show a stock car while the real livery is being prepared.
			photo.modulate.a = 0.0
			var view: Control = preload("res://ui/rivalry_victory_car.gd").new()
			view.name = "NewsLiveryCar"
			view.vehicle_id = vehicle
			view.livery = VehicleLivery.normalize(appearance.livery,vehicle)
			view.customisation = appearance.customisation.duplicate(true)
			view.simple_model = true
			view.podium_presentation = true
			view.fit_to_frame = true
			view.cooperative_build = true
			view.build_budget_us = 24000
			view.custom_minimum_size.y = 116 if short_page else 132
			view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			view.size_flags_vertical = Control.SIZE_EXPAND_FILL
			view.hide()
			photo_frame.add_child(view)
			var loading := _text(photo_frame,"Preparing car…",13,MUTED,true)
			loading.name = "NewsCarLoading"
			loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_reveal_news_car(view,photo,loading)
		if appearance.is_empty() or not _story_uses_local_appearance(item,file_photo):
			var car_name: String = VehicleCatalog.title(vehicle).capitalize()
			var actor_name: String = str(item.get("actor_name",""))
			var photo_caption: String = GameText.message("{car} · illustration",{"car":car_name}) if appearance.is_empty() else GameText.message("{driver} · {car}",{"driver":actor_name,"car":car_name})
			var caption := _text(photograph,photo_caption,13,MUTED,true)
			caption.name = "NewsPhotoCaption"
			caption.add_theme_font_override("font",ITALIC)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vertical_rule(media).name = "NewsImageDivider"
	var map_column := VBoxContainer.new()
	map_column.name = "NewsMapColumn"
	map_column.add_theme_constant_override("separation",3)
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column_slot(media,map_column)
	var circuit_label := _text(map_column,"CIRCUIT OUTLINE",13,RED)
	circuit_label.name = "NewsCircuitLabel"
	circuit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var map := Art.new()
	map.name = "NewsCircuit"
	map.kind = "circuit"
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size.y = 60 if short_page else 90
	var raw: Variant = item.get("track_points",[])
	if raw is Array:
		for point: Variant in raw.slice(0,96):
			if point is Array and point.size() >= 2 and (point[0] is float or point[0] is int) and (point[1] is float or point[1] is int):
				var p := Vector2(float(point[0]),float(point[1]))
				if is_finite(p.x) and is_finite(p.y) and absf(p.x) <= 100000 and absf(p.y) <= 100000: map.points.append(p)
	map_column.add_child(map)
	if map.points.size() < 2: circuit_label.text = "OUTLINE UNAVAILABLE"
	var metric: String = GameText.message("lap") if item.get("metric","") == "lap" else GameText.message("track")
	var actor: String = str(item.get("actor_name",GameText.message("A racer")))
	var body: String = ""
	match str(item.get("kind","")):
		"milestone": body = GameText.message("Your track has welcomed %s racers.\n%s is making its name.") % [_count(int(item.get("count",0))),track]
		"world_record": body = GameText.message("%s sets a new %s world record.\nThe pace rises at %s.") % [actor,metric,track]
		"friend_overtake": body = GameText.message("%s beats your best %s time.\nA new target at %s.") % [actor,metric,track]
		"percentile_drop": body = GameText.message("Your %s time is outside the top %d%%.\nThe chase continues at %s.") % [metric,int(item.get("threshold",0)),track]
		"friend_track": body = GameText.message("%s unveils %s.\nA fresh circuit to try.") % [actor,track]
		"track_published": body = GameText.message("%s is published.\nShare the link or take to the track.") % track
	if item.has("time_ticks"):
		var result := HBoxContainer.new()
		result.name = "NewsResult"
		result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		result.add_theme_constant_override("separation",9)
		map_column.add_child(result)
		var record := _text(result,_time(int(item.time_ticks),int(item.get("tick_rate",120))),21,INK,true)
		record.name = "NewsRecordTime"
		record.add_theme_font_override("font",_headline_font())
		record.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		record.autowrap_mode = TextServer.AUTOWRAP_OFF
		var result_metric := _text(result,metric.to_upper(),13,RED)
		result_metric.name = "NewsRecordMetric"
		result_metric.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		result_metric.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		result_metric.autowrap_mode = TextServer.AUTOWRAP_OFF
	if item.has("your_ticks"):
		_text(map_column,GameText.message("Your best")+"  "+_time(int(item.your_ticks),int(item.get("tick_rate",120))),14,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var closing := HBoxContainer.new()
	closing.name = "StoryClosing"
	closing.add_theme_constant_override("separation",12)
	parent.add_child(closing)
	var article := _text(closing,body,16 if wide and not short_page else 14,INK,true)
	article.name = "NewsArticle"
	article.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not str(item.get("version_id","")).is_empty() and page.has_signal("news_share_requested"):
		var share := _button("",func() -> void:
			if _active(): page.news_share_requested.emit(item.duplicate(true)))
		share.name = "GarageNewsShare"
		share.icon = MenuIcon.texture("share")
		share.tooltip_text = "Share track link"
		share.add_theme_color_override("icon_normal_color",INK)
		for state: String in ["icon_hover_color","icon_pressed_color","icon_focus_color"]: share.add_theme_color_override(state,RED)
		closing.add_child(share)
	if _has_race_track(item):
		var race := _button("Race track  →",_race_story.bind(item))
		race.name = "GarageNewsRace"
		race.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		race.custom_minimum_size.x = 196 if wide else 176
		race.add_theme_font_override("font",_headline_font())
		race.add_theme_font_size_override("font_size",24 if wide else 21)
		race.tooltip_text = "Race "+track
		for state: String in ["normal","hover","pressed","focus"]:
			race.add_theme_stylebox_override(state,_box(Color.TRANSPARENT))
		for state: String in ["font_hover_color","font_pressed_color","font_focus_color"]:
			race.add_theme_color_override(state,RED)
		var marker := Art.new()
		marker.name = "RaceMarker"
		marker.kind = "marker"
		marker.show_behind_parent = true
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		race.add_child(marker)
		MenuStyle.fill(marker)
		closing.add_child(race)

func _brief(parent: Node, item: Dictionary, index: int) -> void:
	_rule(parent)
	var button := _button("",_choose.bind(index))
	button.name = "NewsBrief"+str(index)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 40
	parent.add_child(button)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	MenuStyle.fill(margin)
	for side: String in ["left","right"]: margin.add_theme_constant_override("margin_"+side,6)
	for side: String in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,2)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation",0)
	margin.add_child(column)
	var metadata := HBoxContainer.new()
	metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metadata.add_theme_constant_override("separation",6)
	column.add_child(metadata)
	var category := _text(metadata,_category(item),10,RED)
	category.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	category.custom_minimum_size.x = minf(140.0,category.get_theme_font("font").get_string_size(category.text,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x+2.0)
	var track := _text(metadata,str(item.get("track_name","")),10,MUTED)
	GameText.user_text(track)
	if not _story_read(item,_using_examples()):
		var unread := _text(metadata,"NEW",10,RED)
		unread.name = "NewsUnread"
		unread.size_flags_horizontal = Control.SIZE_SHRINK_END
		unread.autowrap_mode = TextServer.AUTOWRAP_OFF
	var title := _text(column,_headline(item),17 if size.x >= 1360 else 16,INK,true)
	title.resized.connect(_fit_headline.bind(title,17 if size.x >= 1360 else 16,14))
	for label: Label in [category,title,track]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.minimum_size_changed.connect(_update_brief_height.bind(column,button).call_deferred)
	button.resized.connect(_update_brief_height.bind(column,button).call_deferred)

func _update_brief_height(column: Control, button: Control) -> void:
	if not is_instance_valid(column) or not is_instance_valid(button): return
	if column.size.x > 1.0 and absf(column.size.x-(button.size.x-12)) < 0.5:
		button.custom_minimum_size.y = maxf(float(button.get_meta("news_row_height",40)),column.get_combined_minimum_size().y+4)

func _fit_headline(label: Label, maximum: int, minimum: int) -> void:
	if label.size.x <= 0: return
	var width: float = label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,maximum).x
	var pixels: int = clampi(int(floor(maximum*label.size.x/maxf(1,width))),minimum,maximum)
	if label.get_theme_font_size("font_size") != pixels: label.add_theme_font_size_override("font_size",pixels)

func _friend_card(item: Dictionary) -> void:
	_rule(_list)
	var row := HBoxContainer.new()
	_list.add_child(row)
	var name_column := VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_column)
	GameText.user_text(_text(name_column,str(item.get("display_name","")),20,INK,true))
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
	_finish_story_turn()
	if service != null and service.changed.is_connected(_changed): service.changed.disconnect(_changed)
