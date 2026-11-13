extends ConfirmationDialog
## Purchase presentation only. Native confirmation retains the Garage economy fences.
const Preview = preload("res://ui/cosmetic_purchase_preview.gd")
var item_id: String = ""
var item_title: String = ""
var vehicle_id: String = "compact"
var price: int = 0
var balance: int = 0
var signed_in: bool = false
var source_car: WeakRef
var preview_livery: Dictionary = {}
var preview_customisation: Dictionary = {}
var surface: Control
var scenery: TextureRect
var preview_area: Control
var vehicle_preview: Control
var copy_scroll: ScrollContainer
var details: VBoxContainer
var eyebrow: Label
var heading: Label
var description: Label
var price_label: Label
var balance_label: Label
var remaining_label: Label
var status_label: Label
var confirm_button: Button
var cancel_button: Button
var close_button: Button
var rotate_hint: Label
var scrim: CanvasLayer
var prior_focus: WeakRef
var context_current: Callable
var _issued: bool = false
var _display: Font

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
	_display = MenuStyle.DISPLAY.duplicate()
	_display.fallbacks = []
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
	preview_area = Control.new()
	preview_area.name = "PurchasePreviewArea"
	preview_area.clip_contents = true
	surface.add_child(preview_area)
	vehicle_preview = Preview.new()
	vehicle_preview.name = "PurchaseVehicle"
	vehicle_preview.source_car = source_car
	vehicle_preview.vehicle_id = vehicle_id
	vehicle_preview.livery = preview_livery.duplicate(true)
	vehicle_preview.customisation = preview_customisation.duplicate(true)
	vehicle_preview.caption = item_title
	if item_id.begins_with("kit/compact/"): vehicle_preview.category = item_id.get_slice("/",2)
	preview_area.add_child(vehicle_preview)
	rotate_hint = _label(GameText.message("Drag to rotate").to_upper(),15,MenuStyle.TEXT)
	rotate_hint.name = "PurchaseRotateHint"
	preview_area.add_child(rotate_hint)
	copy_scroll = ScrollContainer.new()
	copy_scroll.name = "PurchaseDetailsScroll"
	copy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.add_child(copy_scroll)
	details = VBoxContainer.new()
	details.name = "PurchaseDetails"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",8)
	copy_scroll.add_child(details)
	_build_details()
	confirm_button = MenuStyle.button(GameText.message("Unlock for %d") % price if signed_in else GameText.message("Sign in"),_confirm,true)
	confirm_button.name = "PurchaseUnlock"
	confirm_button.text = confirm_button.text.to_upper()
	confirm_button.add_theme_font_override("font",_display)
	confirm_button.add_theme_font_size_override("font_size",34)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: confirm_button.add_theme_color_override(state,MenuStyle.INK)
	confirm_button.disabled = get_ok_button().disabled
	surface.add_child(confirm_button)
	cancel_button = MenuStyle.button(GameText.message("Not now").to_upper(),_cancel)
	cancel_button.name = "PurchaseNotNow"
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
	_fit_to_view()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := MenuStyle.label(text,font_size)
	label.add_theme_color_override("font_color",color)
	var latin: bool = true
	for character: String in text:
		if character.unicode_at(0)>=768: latin = false
	label.add_theme_font_override("font",_display if latin else MenuStyle.DISPLAY)
	return label

func _build_details() -> void:
	var car_name: String = VehicleCatalog.title(vehicle_id).get_slice(" /",0)
	eyebrow = _label(car_name+"  /  "+GameText.message("Paint" if item_id.begins_with("livery/") else "Exterior").to_upper(),20,MenuStyle.MUTED)
	eyebrow.name = "PurchaseCategory"
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(eyebrow)
	heading = _label(GameText.message(item_title).to_upper(),66,MenuStyle.TEXT)
	heading.name = "PurchaseItemTitle"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(heading)
	description = MenuStyle.label(GameText.message("Permanent unlock for every car." if item_id.begins_with("livery/") else "Permanent unlock for this car."),19,true)
	description.name = "PurchaseUnlockScope"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(description)
	var divider := HSeparator.new()
	divider.custom_minimum_size.y = 14
	details.add_child(divider)
	var price_row := HBoxContainer.new()
	price_row.name = "PurchasePrice"
	price_row.add_theme_constant_override("separation",12)
	details.add_child(price_row)
	var coin := Coin.new()
	coin.custom_minimum_size = Vector2(54,70)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(coin)
	price_label = _label(_number(price),82,MenuStyle.ACCENT)
	price_label.name = "PurchasePriceValue"
	price_row.add_child(price_label)
	var unit: Label = _label(GameText.message("Coins").to_upper(),22,MenuStyle.MUTED)
	unit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_row.add_child(unit)
	var wallet := HBoxContainer.new()
	wallet.name = "PurchaseBalanceComparison"
	wallet.add_theme_constant_override("separation",22)
	wallet.visible = signed_in
	details.add_child(wallet)
	balance_label = _wallet_value(wallet,"Your balance",balance,"PurchaseCurrentBalance")
	var line := VSeparator.new()
	wallet.add_child(line)
	remaining_label = _wallet_value(wallet,"After purchase",maxi(0,balance-price),"PurchaseAfterBalance")
	if balance < price: remaining_label.text = "—"
	status_label = MenuStyle.label("",17,true)
	status_label.name = "PurchaseAvailability"
	status_label.text = GameText.message("Sign in to earn coins and unlock this item.") if not signed_in else GameText.message("Complete more races to earn coins.") if balance < price else ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.visible = not status_label.text.is_empty()
	details.add_child(status_label)

func _wallet_value(parent: HBoxContainer, title: String, value: int, node_name: String) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",2)
	parent.add_child(column)
	var caption: Label = _label(GameText.message(title).to_upper(),15,MenuStyle.MUTED)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	var amount: Label = _label(_number(value),32,MenuStyle.TEXT)
	amount.name = node_name
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
	if not is_inside_tree(): return
	var available: Vector2 = get_parent().get_viewport().get_visible_rect().size-Vector2(48,48)
	var stacked: bool = available.x < 760 and available.y > available.x*1.1
	size = Vector2i(minf(1180,available.x),minf(900 if stacked else 610,available.y))
	position = Vector2i((get_parent().get_viewport().get_visible_rect().size-Vector2(size))*0.5)
	_layout()

func _layout() -> void:
	if surface == null: return
	var extent: Vector2 = Vector2(size)
	var stacked: bool = extent.x < 760 and extent.y > extent.x*1.1
	var compact: bool = extent.x < 900
	var split: float = minf(0.38,300.0/extent.y) if stacked else 0.46 if compact else 0.55
	var top: float = extent.y*split+20 if stacked else 66
	var left: float = 26 if stacked else extent.x*split+(22 if compact else 34)
	var right: float = 26 if stacked else 22 if compact else 34
	var width: float = extent.x-left-right
	(scenery.material as ShaderMaterial).set_shader_parameter("panel_size",extent)
	(scenery.material as ShaderMaterial).set_shader_parameter("divide",split)
	(scenery.material as ShaderMaterial).set_shader_parameter("stacked",stacked)
	preview_area.position = Vector2.ZERO
	preview_area.size = Vector2(extent.x,extent.y*split) if stacked else Vector2(extent.x*split,extent.y)
	vehicle_preview.position = Vector2(12,preview_area.size.y*0.28)
	vehicle_preview.size = Vector2(preview_area.size.x-24,preview_area.size.y*0.70)
	rotate_hint.position = Vector2(24,preview_area.size.y-36)
	rotate_hint.size = Vector2(preview_area.size.x-48,24)
	heading.add_theme_font_size_override("font_size",34 if compact else 66)
	price_label.add_theme_font_size_override("font_size",56 if compact else 82)
	for amount: Label in [balance_label,remaining_label]:
		var value_width: float = maxf(1,_display.get_string_size(amount.text,HORIZONTAL_ALIGNMENT_LEFT,-1,32).x)
		amount.add_theme_font_size_override("font_size",clampi(floori(32.0*(width-48)*0.5/value_width),16,32))
	copy_scroll.position = Vector2(left,top)
	copy_scroll.size = Vector2(width,maxf(64,extent.y-top-178))
	confirm_button.position = Vector2(left,extent.y-154)
	confirm_button.size = Vector2(width,76)
	cancel_button.position = Vector2(left,extent.y-76)
	cancel_button.size = Vector2(width,48)
	close_button.position = Vector2(extent.x-64,10)
	close_button.size = Vector2(52,52)

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
	if is_instance_valid(vehicle_preview): vehicle_preview.release()
	if is_instance_valid(scrim): scrim.queue_free()
	if prior_focus != null:
		var focus: Control = prior_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()

func _exit_tree() -> void:
	if is_instance_valid(scrim): scrim.queue_free()
