extends VBoxContainer
## Car-specific previews share the normal paint-icon cache and live showroom.
var page: GaragePage
var rows: Dictionary = {}
var scroll: ScrollContainer
var icons: Node
var restore: Button

func _ready() -> void:
	name = "GaragePremiumLiveries"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	var note: Label = MenuStyle.label("Coming soon · Preview only",16,true)
	note.name = "PremiumLiveryNotice"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	scroll = preload("res://ui/vertical_swipe_scroll.gd").new()
	scroll.name = "PremiumLiveryGallery"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	icons = preload("res://ui/garage_paint_icons.gd").new()
	icons.scroll = scroll
	add_child(icons)
	for item: Dictionary in LiveryCatalog.premium_for(page.vehicle_id):
		var row := preload("res://ui/garage_part_option.gd").new()
		row.setup(rows.size(),[item.id,item.title],"Premium livery",page._preview_premium_livery.bind(str(item.id)))
		row.name = "PremiumLivery_"+str(item.id)
		row.add_car_icon()
		row.set_meta("premium_id",item.id)
		list.add_child(row)
		rows[item.id] = row
		row.focus_entered.connect(reveal_selected,CONNECT_DEFERRED)
	restore = MenuStyle.button("Restore equipped paint",_restore)
	restore.name = "RestorePremiumLiveryPreview"
	restore.custom_minimum_size.y = 48
	restore.add_theme_font_size_override("font_size",18)
	add_child(restore)
	visibility_changed.connect(_queue_icons,CONNECT_DEFERRED)
	scroll.resized.connect(_queue_icons,CONNECT_DEFERRED)
	scroll.get_v_scroll_bar().changed.connect(_queue_icons,CONNECT_DEFERRED)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _queue_icons.call_deferred())
	refresh()

func refresh() -> void:
	var selected: String = str(page._cosmetic_preview.get("id","")) if page._cosmetic_preview.get("kind","")=="premium_livery" else ""
	for id: String in rows:
		var row: Button = rows[id]
		var chosen: bool = id==selected
		row.set_selected(chosen)
		row.checkmark.hide()
		row.price.hide()
		row.status.show()
		GameText.bind_upper(row.status,"Previewing" if chosen else "Preview")
		row.status.add_theme_color_override("font_color",MenuStyle.ACCENT if chosen else MenuStyle.MUTED)
		row.accessibility_description = GameText.message("Preview only")
	if is_instance_valid(restore): restore.visible = not selected.is_empty()
	_queue_icons.call_deferred()

func reveal_selected() -> void:
	if not is_visible_in_tree(): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and scroll.is_ancestor_of(focused): scroll.ensure_control_visible(focused)
	else:
		for row: Button in rows.values():
			if row.selected:
				scroll.ensure_control_visible(row)
				break
	_queue_icons.call_deferred()

func _queue_icons() -> void:
	if not is_instance_valid(icons): return
	var active: bool = is_visible_in_tree() and page.section=="customise" and page._customise_tab=="livery"
	for id: String in rows:
		var row: Button = rows[id]
		if active and scroll.get_global_rect().intersects(row.get_global_rect()):
			var item: Dictionary = LiveryCatalog.premium_pattern(id)
			var paint: Dictionary = page.draft.duplicate(true)
			paint.pattern = id
			for slot: int in range(VehicleLivery.SLOTS.size()): paint.colors[VehicleLivery.SLOTS[slot]] = item.colours[slot]
			icons.request(row,page.vehicle_id,paint,page.kit_draft)
		else:
			row.car_icon.texture = null
			row.icon_key = ""

func _restore() -> void:
	page._cancel_cosmetic_preview()
