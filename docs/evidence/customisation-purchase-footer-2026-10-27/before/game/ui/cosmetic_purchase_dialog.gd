extends ConfirmationDialog
## A compact purchase sheet. Native confirmation retains the Garage economy fences.
var item_id: String = ""
var item_title: String = ""
var vehicle_id: String = "compact"
var price: int = 0
var balance: int = 0
var signed_in: bool = false
var surface: Control
var scenery: TextureRect
var copy_scroll: ScrollContainer
var details: VBoxContainer
var eyebrow: HBoxContainer
var heading: Label
var description: Label
var summary: GridContainer
var price_label: Label
var balance_label: Label
var remaining_label: Label
var status_label: Label
var confirm_button: Button
var cancel_button: Button
var close_button: Button
var scrim: CanvasLayer
var prior_focus: WeakRef
var context_current: Callable
var _issued: bool = false
var _fitting: bool = false
var _header: MarginContainer
var _price_row: HBoxContainer
var _wallet: HBoxContainer

class Coin extends Control:
	func _draw() -> void:
		var radius: float = minf(size.x,size.y)*0.43
		var center: Vector2 = size*0.5
		draw_circle(center,radius,Color("d8a62f"),true,-1,true)
		draw_arc(center,radius-1,-PI,0.1,48,Color("ffe999"),3,true)
		draw_arc(center,radius-5,0,TAU,64,Color("f2cd65"),1.5,true)
		var font: Font = MenuStyle.DISPLAY
		var text_size: int = roundi(radius*1.45)
		var width: float = font.get_string_size("C",HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x
		draw_string(font,center+Vector2(-width*0.5,radius*0.5),"C",HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,Color("fff0ac"))

func _init() -> void: set_meta("menu_popup_custom",true)

func _ready() -> void:
	borderless = true
	transparent_bg = true
	transparent = true
	unresizable = true
	exclusive = true
	wrap_controls = false
	min_size = Vector2i.ZERO
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	get_label().hide()
	get_ok_button().hide()
	get_cancel_button().hide()
	surface = Control.new()
	surface.name = "CosmeticPurchaseSurface"
	surface.theme = MenuStyle.theme()
	add_child(surface)
	MenuStyle.fill(surface)
	scenery = TextureRect.new()
	scenery.texture = preload("res://assets/menu/customisation_winter_turnout_v1.png")
	scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := ShaderMaterial.new()
	backdrop.shader = preload("res://ui/cosmetic_purchase_background.gdshader")
	scenery.material = backdrop
	surface.add_child(scenery)
	MenuStyle.fill(scenery)
	copy_scroll = ScrollContainer.new()
	copy_scroll.name = "PurchaseDetailsScroll"
	copy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.add_child(copy_scroll)
	details = VBoxContainer.new()
	details.name = "PurchaseDetails"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",10)
	copy_scroll.add_child(details)
	_build_details()
	status_label = MenuStyle.label("",16,true)
	status_label.name = "PurchaseAvailability"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not signed_in:
		GameText.bind(status_label,"Sign in to earn coins and unlock this item.")
	elif balance < price:
		GameText.bind(status_label,"Not enough coins. Complete more races.")
	surface.add_child(status_label)
	confirm_button = MenuStyle.button("",_confirm,true)
	confirm_button.name = "PurchaseUnlock"
	if signed_in: _bind_upper(confirm_button,"Unlock for {price}",{"price":_number(price)})
	else: GameText.bind_upper(confirm_button,"Sign in")
	confirm_button.add_theme_font_size_override("font_size",28)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: confirm_button.add_theme_color_override(state,MenuStyle.INK)
	confirm_button.disabled = get_ok_button().disabled
	surface.add_child(confirm_button)
	cancel_button = MenuStyle.button("",_cancel)
	cancel_button.name = "PurchaseNotNow"
	GameText.bind_upper(cancel_button,"Not now")
	cancel_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	cancel_button.add_theme_color_override("font_color",MenuStyle.MUTED)
	cancel_button.add_theme_font_size_override("font_size",18)
	surface.add_child(cancel_button)
	close_button = MenuStyle.button("",_cancel)
	close_button.name = "PurchaseClose"
	close_button.icon = MenuIcon.texture("close",true)
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.expand_icon = true
	close_button.add_theme_constant_override("icon_max_width",26)
	close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	close_button.tooltip_text = GameText.message("Close")
	surface.add_child(close_button)
	about_to_popup.connect(_opening)
	visibility_changed.connect(_visibility_changed)
	size_changed.connect(_layout)
	get_parent().get_viewport().size_changed.connect(_fit_to_view)
	details.minimum_size_changed.connect(_fit_to_view.call_deferred)
	_fit_to_view()

func _bind_upper(control: Control, source: String, values: Dictionary) -> void:
	GameText.bind(control,source,values)
	control.get_meta(GameText.META)["uppercase"] = true
	GameText.update(control)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := MenuStyle.label(text,font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_override("font",MenuStyle.DISPLAY)
	return label

func _build_details() -> void:
	_header = MarginContainer.new()
	_header.add_theme_constant_override("margin_right",64)
	details.add_child(_header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation",8)
	_header.add_child(titles)
	eyebrow = HBoxContainer.new()
	eyebrow.name = "PurchaseCategory"
	eyebrow.add_theme_constant_override("separation",8)
	titles.add_child(eyebrow)
	var car_name: Label = _label(VehicleCatalog.title(vehicle_id).get_slice(" /",0)+" /",16,MenuStyle.MUTED)
	car_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	eyebrow.add_child(car_name)
	var category: Label = _label("",16,MenuStyle.MUTED)
	GameText.bind_upper(category,"Paint" if item_id.begins_with("livery/") else "Exterior")
	eyebrow.add_child(category)
	heading = _label("",44,MenuStyle.TEXT)
	heading.name = "PurchaseItemTitle"
	GameText.bind_upper(heading,item_title)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(heading)
	description = MenuStyle.label("",18,true)
	description.name = "PurchaseUnlockScope"
	GameText.bind(description,"Permanent unlock for every car." if item_id.begins_with("livery/") else "Permanent unlock for this car.")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(description)
	var divider := HSeparator.new()
	divider.custom_minimum_size.y = 10
	details.add_child(divider)
	summary = GridContainer.new()
	summary.name = "PurchaseSummary"
	summary.columns = 2
	summary.add_theme_constant_override("h_separation",24)
	summary.add_theme_constant_override("v_separation",12)
	details.add_child(summary)
	_price_row = HBoxContainer.new()
	_price_row.name = "PurchasePrice"
	_price_row.add_theme_constant_override("separation",10)
	summary.add_child(_price_row)
	var coin := Coin.new()
	coin.custom_minimum_size = Vector2(44,72)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_row.add_child(coin)
	price_label = _label(_number(price),64,MenuStyle.ACCENT)
	price_label.name = "PurchasePriceValue"
	price_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_price_row.add_child(price_label)
	var unit: Label = _label("",18,MenuStyle.MUTED)
	GameText.bind_upper(unit,"Coins")
	unit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price_row.add_child(unit)
	_wallet = HBoxContainer.new()
	_wallet.name = "PurchaseBalanceComparison"
	_wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet.add_theme_constant_override("separation",16)
	_wallet.visible = signed_in
	summary.add_child(_wallet)
	balance_label = _wallet_value(_wallet,"Your balance",balance,"PurchaseCurrentBalance")
	var line := VSeparator.new()
	_wallet.add_child(line)
	remaining_label = _wallet_value(_wallet,"After purchase" if balance >= price else "Still needed",balance-price if balance >= price else price-balance,"PurchaseAfterBalance")

func _wallet_value(parent: HBoxContainer, title: String, value: int, node_name: String) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",2)
	parent.add_child(column)
	var caption: Label = _label("",14,MenuStyle.MUTED)
	GameText.bind_upper(caption,title)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	var amount: Label = _label(_number(value),28,MenuStyle.TEXT)
	amount.name = node_name
	amount.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(amount)
	return amount

static func _number(value: int) -> String:
	var source: String = str(value)
	var result: String = ""
	for index: int in source.length():
		if index>0 and (source.length()-index)%3 == 0: result += ","
		result += source[index]
	return result

func _opening() -> void:
	var focus: Control = get_parent().get_viewport().gui_get_focus_owner()
	if focus != null: prior_focus = weakref(focus)
	scrim = CanvasLayer.new()
	scrim.name = "CosmeticPurchaseScrim"
	scrim.layer = 90
	get_parent().add_child(scrim)
	var shade := ColorRect.new()
	shade.color = MenuStyle.POPUP_DIM
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.add_child(shade)
	MenuStyle.fill(shade)
	_fit_to_view()
	_focus_action.call_deferred()

func _focus_action() -> void:
	if not visible: return
	if confirm_button.disabled: cancel_button.grab_focus()
	else: confirm_button.grab_focus()

func _fit_to_view() -> void:
	if not is_inside_tree() or surface == null or _fitting: return
	_fitting = true
	var available: Vector2 = get_parent().get_viewport().get_visible_rect().size-Vector2(48,48)
	var width: int = mini(760,floori(available.x))
	if size.x != width: size.x = width
	_layout()
	var height: int = mini(floori(available.y),maxi(472,ceili(details.get_combined_minimum_size().y)+36+ceili(_footer_height())))
	if size.y != height: size.y = height
	position = Vector2i((get_parent().get_viewport().get_visible_rect().size-Vector2(size))*0.5)
	_layout()
	_fitting = false

func _footer_height() -> float:
	return 14+maxf(48,cancel_button.get_combined_minimum_size().y)+4+maxf(60,confirm_button.get_combined_minimum_size().y)+14+48+12

func _layout() -> void:
	if surface == null or close_button == null: return
	var extent: Vector2 = Vector2(size)
	var padding: float = 32 if extent.x >= 620 else 24
	var width: float = extent.x-padding*2
	(scenery.material as ShaderMaterial).set_shader_parameter("panel_size",extent)
	copy_scroll.position = Vector2(padding,24)
	summary.columns = 1 if width < 600 else 2
	var heading_size: int = 36 if width < 600 else 44
	if heading.get_theme_font_size("font_size") != heading_size: heading.add_theme_font_size_override("font_size",heading_size)
	var cancel_height: float = maxf(48,cancel_button.get_combined_minimum_size().y)
	var confirm_height: float = maxf(60,confirm_button.get_combined_minimum_size().y)
	cancel_button.position = Vector2(padding,extent.y-14-cancel_height)
	cancel_button.size = Vector2(width,cancel_height)
	confirm_button.position = Vector2(padding,cancel_button.position.y-4-confirm_height)
	confirm_button.size = Vector2(width,confirm_height)
	status_label.position = Vector2(padding,confirm_button.position.y-14-48)
	status_label.size = Vector2(width,48)
	copy_scroll.size = Vector2(width,maxf(64,status_label.position.y-12-copy_scroll.position.y))
	close_button.position = Vector2(extent.x-64,10)
	close_button.size = Vector2(52,52)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(surface):
		if is_instance_valid(close_button): close_button.tooltip_text = GameText.message("Close")
		_fit_to_view.call_deferred()

func _confirm() -> void:
	if not visible or _issued or get_ok_button().disabled: return
	if context_current.is_valid() and not context_current.call():
		_cancel()
		return
	_issued = true
	get_ok_button().pressed.emit()

func _cancel() -> void:
	if visible: get_cancel_button().pressed.emit()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		_cancel()
		set_input_as_handled()
	elif event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
		_confirm()
		set_input_as_handled()

func _visibility_changed() -> void:
	if visible: return
	if is_instance_valid(scrim): scrim.queue_free()
	if prior_focus != null:
		var focus: Control = prior_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()

func _exit_tree() -> void:
	if is_instance_valid(scrim): scrim.queue_free()
