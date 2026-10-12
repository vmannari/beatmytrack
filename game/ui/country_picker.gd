extends Button
## Searchable touch/keyboard country choice. Saving belongs to the account flow.
signal country_selected(code: String)
var country_code: String = ""
var dialog: AcceptDialog
var search: LineEdit
var items: ItemList
var matches: Array[String] = []

func _ready() -> void:
	name = "PlayerCountryPicker"
	custom_minimum_size.y = 54
	add_theme_font_size_override("font_size",18)
	expand_icon = true
	add_theme_constant_override("icon_max_width",28)
	pressed.connect(_open)
	set_country(country_code)

func set_country(code: String) -> void:
	country_code = PlayerCountry.valid_code(code)
	text = "Country: "+PlayerCountry.country_name(country_code) if not country_code.is_empty() else "Choose your country"
	icon = PlayerCountry.texture(country_code)
	tooltip_text = "Shown beside your name in standings."

func _open() -> void:
	if not is_instance_valid(dialog):
		dialog = AcceptDialog.new()
		dialog.name = "CountryPickerDialog"
		dialog.title = "Choose your country"
		dialog.theme = MenuStyle.theme()
		dialog.get_ok_button().text = "Close"
		dialog.get_ok_button().custom_minimum_size.y = 52
		add_child(dialog)
		preload("res://ui/popup_style.gd").watch(dialog)
		var body := VBoxContainer.new()
		dialog.add_child(body)
		search = LineEdit.new()
		search.name = "CountrySearch"
		search.placeholder_text = "Search country or code"
		search.custom_minimum_size.y = 52
		search.text_changed.connect(_filter)
		body.add_child(search)
		items = ItemList.new()
		items.name = "CountryChoices"
		items.custom_minimum_size = Vector2(400,260)
		items.size_flags_vertical = Control.SIZE_EXPAND_FILL
		items.fixed_icon_size = Vector2i(32,24)
		items.add_theme_constant_override("v_separation",24)
		items.add_theme_font_size_override("font_size",18)
		items.add_theme_stylebox_override("panel",MenuStyle.box(MenuStyle.PANEL,8))
		items.add_theme_stylebox_override("selected",MenuStyle.box(Color("ffd34824"),6))
		items.add_theme_stylebox_override("selected_focus",MenuStyle.box(Color("ffd34838"),6))
		items.add_theme_color_override("font_color",MenuStyle.TEXT)
		items.add_theme_color_override("font_selected_color",MenuStyle.TEXT)
		items.item_clicked.connect(func(index: int, _position: Vector2, button: int) -> void:
			if button == MOUSE_BUTTON_LEFT: _choose(index))
		items.item_activated.connect(_choose)
		body.add_child(items)
	search.text = ""
	_filter("")
	var viewport_size: Vector2i = Vector2i(get_viewport_rect().size)
	dialog.popup_centered(Vector2i(mini(480,viewport_size.x-32),mini(450,viewport_size.y-32)))
	search.grab_focus()

func _filter(query: String) -> void:
	items.clear()
	matches.clear()
	query = query.strip_edges().to_lower()
	for row: Dictionary in PlayerCountry.countries():
		if not query.is_empty() and not str(row.name).to_lower().contains(query) and not str(row.code).to_lower().contains(query): continue
		matches.append(str(row.code))
		items.add_item(str(row.name)+"  ("+str(row.code)+")",PlayerCountry.texture(str(row.code)))
		if row.code == country_code: items.select(items.item_count-1)

func _choose(index: int) -> void:
	if index < 0 or index >= matches.size(): return
	set_country(matches[index])
	dialog.hide()
	country_selected.emit(country_code)
