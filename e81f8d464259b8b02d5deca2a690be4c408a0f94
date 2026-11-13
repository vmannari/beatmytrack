extends Node
## Shared chrome for game-owned windows. Native actions and form controls remain intact.
const ART: Texture2D = preload("res://assets/menu/rivalry_winter_v1.png")
const FRAME: Shader = preload("res://ui/fault_dialog.gdshader")
var window: AcceptDialog
var background_layer: CanvasLayer
var header_layer: CanvasLayer
var art: TextureRect
var header: Label
var symbol: TextureRect
var close_button: Button
var header_action: Control
var body: VBoxContainer
var message: Label
var message_scroll: ScrollContainer
var message_padding: StyleBoxEmpty
var shade_layer: CanvasLayer
var shade: ColorRect
var prior_focus: WeakRef
var forms: bool = false
var prepared: bool = false

static func watch(popup: Window) -> void:
	if popup.has_meta("menu_popup_style") or popup.has_meta("menu_popup_custom"): return
	popup.set_meta("menu_popup_style",true)
	popup.theme = MenuStyle.theme()
	if popup is PopupMenu:
		popup.add_theme_stylebox_override("panel",MenuStyle.popup_panel(12))
		popup.add_theme_stylebox_override("hover",MenuStyle.box(MenuStyle.ACCENT,8))
		popup.add_theme_color_override("font_hover_color",MenuStyle.INK)
		popup.add_theme_color_override("font_color",MenuStyle.TEXT)
		return
	if popup is PopupPanel:
		popup.add_theme_stylebox_override("panel",MenuStyle.popup_panel(16))
		return
	if not popup is AcceptDialog: return
	var chrome: Node = load("res://ui/popup_style.gd").new()
	chrome.window = popup
	chrome.name = "PopupStyle"
	popup.add_child(chrome)

static func decorate_panel(panel: PanelContainer) -> void:
	if panel.has_meta("menu_popup_panel"): return
	panel.set_meta("menu_popup_panel",true)
	panel.add_theme_stylebox_override("panel",MenuStyle.popup_panel(20))
	var material := ShaderMaterial.new()
	material.shader = FRAME
	material.set_shader_parameter("compact",true)
	material.set_shader_parameter("panel_background",true)
	material.set_shader_parameter("scenery",ART)
	material.set_shader_parameter("scenery_size",ART.get_size())
	panel.material = material
	var layout: Callable = _layout_panel.bind(weakref(panel),material)
	panel.item_rect_changed.connect(layout)
	layout.call_deferred()

static func _layout_panel(panel_ref: WeakRef, material: ShaderMaterial) -> void:
	var panel: PanelContainer = panel_ref.get_ref() as PanelContainer
	if panel == null: return
	if material.get_shader_parameter("panel_size") != panel.size:
		material.set_shader_parameter("panel_size",panel.size)

func _ready() -> void:
	set_process(false)
	window.about_to_popup.connect(_opening)
	window.visibility_changed.connect(_visibility_changed)
	window.size_changed.connect(_layout.call_deferred)
	window.get_parent().get_viewport().size_changed.connect(_layout.call_deferred)
	window.borderless = true
	window.transparent_bg = true
	window.transparent = true
	window.unresizable = true

func _process(_delta: float) -> void:
	# Some native dialogs update their message after an extra action (for example Copy).
	if message != null and message.text != window.dialog_text:
		message.text = window.dialog_text
		message.visible = not window.dialog_text.is_empty()
		_layout.call_deferred()

func _prepare() -> void:
	if prepared: return
	prepared = true
	forms = window is FileDialog or window.get_children().any(func(child: Node) -> bool: return child is Control)
	if not forms:
		# Avoid zero-width wrapping expanding a message window before first layout.
		window.wrap_controls = false
		window.min_size = Vector2i.ZERO
		window.size = Vector2i(820,380)
	var content: Array[Control] = []
	if not window is FileDialog:
		for child: Node in window.get_children():
			if child is Control and child != header_action: content.append(child)
		body = VBoxContainer.new()
		body.name = "PopupBody"
		body.add_theme_constant_override("separation",14)
		if forms:
			window.add_child(body)
		else:
			message_scroll = ScrollContainer.new()
			message_scroll.name = "PopupMessageScroll"
			message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			window.add_child(message_scroll)
			message_scroll.add_child(body)
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message = MenuStyle.label(window.dialog_text,19,true)
		message.name = "PopupMessage"
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if forms and not window.dialog_text.is_empty(): message.custom_minimum_size.x = 380
		message.visible = not window.dialog_text.is_empty()
		body.add_child(message)
		if not forms: message.minimum_size_changed.connect(_layout.call_deferred)
		for control: Control in content: control.reparent(body)
		window.get_label().hide()
		window.dialog_autowrap = true
	var padding := StyleBoxEmpty.new()
	padding.content_margin_left = 28 if forms else 340
	padding.content_margin_right = 28 if forms else 36
	padding.content_margin_top = 88 if forms else 128
	padding.content_margin_bottom = 24
	window.add_theme_stylebox_override("panel",padding)
	if not forms: message_padding = padding
	window.add_theme_constant_override("buttons_min_height",56)
	window.add_theme_constant_override("buttons_min_width",110)
	window.add_theme_constant_override("buttons_separation",18)
	background_layer = CanvasLayer.new()
	background_layer.layer = -10
	window.add_child(background_layer)
	art = TextureRect.new()
	art.name = "PopupScenery"
	art.texture = ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FRAME
	material.set_shader_parameter("compact",forms)
	art.material = material
	background_layer.add_child(art)
	header_layer = CanvasLayer.new()
	header_layer.layer = 10
	window.add_child(header_layer)
	var surface := Control.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_layer.add_child(surface)
	MenuStyle.fill(surface)
	header = MenuStyle.label("",32 if forms else 40)
	header.name = "PopupHeading"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	surface.add_child(header)
	symbol = TextureRect.new()
	symbol.name = "PopupSymbol"
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.modulate = MenuStyle.ACCENT
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(symbol)
	close_button = MenuStyle.button("",_cancel)
	close_button.name = "PopupClose"
	close_button.icon = MenuIcon.texture("close")
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "Close"
	close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	surface.add_child(close_button)
	if is_instance_valid(header_action): header_action.reparent(surface)
	_style_actions()

func _style_actions() -> void:
	var actions: Node = window.get_ok_button().get_parent()
	for child: Node in actions.get_children():
		if not child is Button: continue
		child.add_theme_font_override("font",MenuStyle.DISPLAY)
		child.add_theme_font_size_override("font_size",23)
		if child == window.get_ok_button():
			child.add_theme_stylebox_override("normal",MenuStyle.box(MenuStyle.ACCENT,12))
			child.add_theme_stylebox_override("hover",MenuStyle.box(Color("ffe499"),12))
			child.add_theme_stylebox_override("pressed",MenuStyle.box(Color("e7b744"),12))
			for state: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]: child.add_theme_color_override(state,MenuStyle.INK)

func _opening() -> void:
	var focus: Control = window.get_parent().get_viewport().gui_get_focus_owner()
	if focus != null: prior_focus = weakref(focus)
	_prepare()
	if message != null:
		message.text = window.dialog_text
		message.visible = not window.dialog_text.is_empty()
	header.text = window.title if window.title not in ["","Alert!","Please Confirm..."] else "Please confirm" if window is ConfirmationDialog else "Please note"
	var title: String = header.text.to_lower()
	var icon: String = "folder" if window is FileDialog or title.contains("import") else "delete" if title.contains("delete") or title.contains("discard") else "person" if title.contains("country") or title.contains("profile") else "trophy" if (title.contains("scores") or title.contains("ranking")) else "star" if title.contains("rate") else "publish" if title.contains("uploads") else "target" if title.contains("challenge") else "edit" if forms else "help" if window is ConfirmationDialog else "check"
	symbol.texture = MenuIcon.texture(icon,true)
	_style_actions()
	if not is_instance_valid(shade_layer):
		shade_layer = CanvasLayer.new()
		shade_layer.name = "PopupScrim"
		shade_layer.layer = 90
		window.get_parent().add_child(shade_layer)
		shade = ColorRect.new()
		shade.color = MenuStyle.POPUP_DIM
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		shade_layer.add_child(shade)
		MenuStyle.fill(shade)
	shade_layer.show()
	_layout.call_deferred()
	_center.call_deferred()

func _center() -> void:
	if not is_instance_valid(window) or not window.is_inside_tree() or not window.visible: return
	var extent: Vector2 = window.get_parent().get_viewport().get_visible_rect().size
	window.position = Vector2i((extent-Vector2(window.size))*0.5)

func _layout() -> void:
	if not prepared or not is_instance_valid(window) or not window.is_inside_tree(): return
	if not forms: _layout_message()
	var extent: Vector2 = Vector2(window.size)
	art.size = extent
	(art.material as ShaderMaterial).set_shader_parameter("panel_size",extent)
	close_button.position = Vector2(extent.x-62,8)
	close_button.size = Vector2(52,52)
	if is_instance_valid(header_action):
		header_action.position = close_button.position-Vector2(58,0)
		header_action.size = Vector2(52,52)
	if forms:
		header.position = Vector2(86,24)
		header.size = Vector2(maxf(120,extent.x-header.position.x-76),60)
	if is_instance_valid(header_action): header.size.x = maxf(120,header.size.x-58)
	if forms:
		symbol.size = Vector2(38,38)
		symbol.position = Vector2(30,24)
	var actions: Control = window.get_ok_button().get_parent()
	actions.position.x = 28 if forms else message_padding.content_margin_left
	actions.size.x = extent.x-actions.position.x-(28 if forms else message_padding.content_margin_right)
	if not forms and window.visible: _center()

func _layout_message() -> void:
	# Measure wrapped copy instead of letting a fixed-height native body cover its actions.
	var available: Vector2 = window.get_parent().get_viewport().get_visible_rect().size-Vector2(32,32)
	var width: float = minf(820,available.x)
	var actions: Control = window.get_ok_button().get_parent()
	var compact: bool = width < 760 or actions.get_combined_minimum_size().x > width-376
	var short_window: bool = available.y < 440
	var left: float = 28 if compact else 340
	var right: float = 28 if compact else 36
	header.add_theme_font_size_override("font_size",28 if short_window else 32 if compact else 40)
	header.position = Vector2(left,24) if short_window else Vector2(86,24) if compact else Vector2(left,42)
	header.size = Vector2(maxf(1,width-header.position.x-76),0)
	header.size.y = maxf(60,header.get_minimum_size().y)
	var top: float = ceilf(header.position.y+header.size.y+24)
	message_padding.content_margin_left = left
	message_padding.content_margin_right = right
	message_padding.content_margin_top = top
	var scrollbar_width: float = message_scroll.get_v_scroll_bar().get_combined_minimum_size().x if message_scroll.get_v_scroll_bar().visible else 0
	body.size.x = width-left-right-scrollbar_width
	message.size.x = body.size.x
	var action_height: float = maxf(56,actions.get_combined_minimum_size().y)
	var height: float = minf(available.y,maxf(380,top+body.get_combined_minimum_size().y+24+action_height+24))
	window.size = Vector2i(ceili(width),ceili(height))
	symbol.visible = not short_window
	symbol.size = Vector2(38,38) if compact else Vector2(140,140)
	symbol.position = Vector2(30,24) if compact else Vector2(92,height*0.45-70)

func _visibility_changed() -> void:
	if window.visible:
		set_process(true)
		_layout.call_deferred()
		return
	set_process(false)
	if is_instance_valid(shade_layer): shade_layer.hide()
	if prior_focus != null:
		var focus: Control = prior_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()

func _cancel() -> void:
	if window is ConfirmationDialog:
		window.get_cancel_button().pressed.emit()
	else:
		window.canceled.emit()
		window.hide()

func _exit_tree() -> void:
	if is_instance_valid(shade_layer): shade_layer.queue_free()
