extends HBoxContainer
## Shared Garage header layout with the original filled navigation buttons.
var app: Node
var _nav: HBoxContainer
var _amount: Label
const CONTROL_HEIGHT: int = 56
const BUTTON_PADDING_Y: int = 10

class Coin extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(24,24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		draw_circle(Vector2(12,12),11,Color("eaa718"))
		draw_circle(Vector2(12,12),9,MenuStyle.ACCENT)
		draw_string(MenuStyle.DISPLAY,Vector2(7,19),"$",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("b67c13"))

func _ready() -> void:
	name = "GarageHeaderWallet"
	_nav = get_parent()
	_nav.move_child(self,app.account_button.get_index())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation",8)
	add_child(Coin.new())
	_amount = MenuStyle.label("",24)
	GameText.user_text(_amount)
	add_child(_amount)
	var divider := VSeparator.new()
	divider.custom_minimum_size.x = 16
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)
	if app.cosmetic_economy != null: app.cosmetic_economy.changed.connect(_balance)
	_balance()
	get_viewport().size_changed.connect(refresh)
	refresh()

func _balance() -> void:
	if not is_instance_valid(_amount): return
	var signed_in: bool = app.cosmetic_economy != null and app.cosmetic_economy.authenticated()
	_amount.text = _grouped(app.cosmetic_economy.balance()) if signed_in else "—"
	tooltip_text = GameText.message("Account coins" if signed_in else "Sign in to earn coins")

func _grouped(value: int) -> String:
	var text: String = str(value)
	var offset: int = text.length()-3
	while offset > 0:
		text = text.insert(offset,",")
		offset -= 3
	return text

func refresh() -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.root_ui): return
	_fit(get_viewport_rect().size.x < 1100)

func _fit(compact: bool) -> void:
	_nav.add_theme_constant_override("separation",6 if compact else 12)
	var layout: VBoxContainer = _nav.get_parent()
	layout.add_theme_constant_override("separation",6)
	var margin: MarginContainer = layout.get_parent()
	# Mobile margins already include the display's safe area in App.
	if not OS.has_feature("mobile"):
		margin.add_theme_constant_override("margin_top",10)
		margin.add_theme_constant_override("margin_bottom",18)
		margin.add_theme_constant_override("margin_left",16)
	var brand: Control = _nav.get_child(0)
	brand.custom_minimum_size = Vector2(136 if compact else 196,CONTROL_HEIGHT)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tabs: Control = app.root_ui.find_child("MenuNavigation",true,false)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for tab: Button in tabs.get_children():
		var id: String = str(tab.name).trim_prefix("Tab_")
		var selected: bool = id == app.screen or (id == "tracks" and app.screen in ["rivalry","daily","challenges","challenge_create"]) or (id == "create" and app.screen in ["biome","drafts"])
		# Preserve the original MenuStyle.tab button treatment on every page.
		var style: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,16)
		if selected:
			style.bg_color = Color("29343be8")
			style.border_color = Color("64737c80")
			style.set_border_width_all(1)
			style.border_width_bottom = 2
			style.shadow_color = Color("00000035")
			style.shadow_size = 3
			style.shadow_offset = Vector2(0,2)
		tab.add_theme_stylebox_override("normal",style)
		tab.add_theme_color_override("font_color",MenuStyle.ACCENT if selected else MenuStyle.MUTED)
		_size_button(tab)
	var account: Button = app.account_button
	account.custom_minimum_size = Vector2(174 if compact else 210,CONTROL_HEIGHT)
	account.clip_text = true
	account.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	account.tooltip_text = GameText.message("Profile")+"\n"+account.text if account.text != "Guest" else GameText.message("Profile")
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var style: StyleBoxFlat = account.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 88 if compact else 104
		style.content_margin_right = 12
		if state == "normal": style.bg_color = Color(0.04,0.08,0.10,0.55)
		account.add_theme_stylebox_override(state,style)
	_size_button(account)
	var picture: Control = account.get_node_or_null("MenuProfileCar")
	if picture != null:
		picture.offset_right = 78 if compact else 94
		picture.offset_top = -24
		picture.offset_bottom = 24
	var picker: Control = account.get_node_or_null("MenuCarPicker")
	if picker != null: picker.offset_right = 84 if compact else 100
	var settings: Button = app.root_ui.find_child("MenuSettings",true,false)
	settings.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT))
	settings.custom_minimum_size = Vector2(CONTROL_HEIGHT,CONTROL_HEIGHT)
	_size_button(settings)

func _size_button(button: Button) -> void:
	button.custom_minimum_size.y = CONTROL_HEIGHT
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Font padding otherwise makes a nominal 64px tab render at 66px.
	# Match all interaction states so hovering cannot change text placement.
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var source: StyleBox = button.get_theme_stylebox(state)
		if not source is StyleBoxFlat: continue
		var style: StyleBoxFlat = source.duplicate()
		style.content_margin_top = BUTTON_PADDING_Y
		style.content_margin_bottom = BUTTON_PADDING_Y
		button.add_theme_stylebox_override(state,style)
