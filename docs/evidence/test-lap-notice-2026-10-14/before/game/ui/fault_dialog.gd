class_name FaultDialog
extends AcceptDialog
## Reference-led fault presentation; preserves the existing owned-dialog lifecycle.

const ART: Texture2D = preload("res://assets/menu/rivalry_winter_v1.png")
const ART_SHADER: Shader = preload("res://ui/fault_dialog.gdshader")
var backdrop: ColorRect
var surface: Control
var art: TextureRect
var warning: TextureRect
var details: VBoxContainer
var copy_scroll: ScrollContainer
var eyebrow: Label
var heading: Label
var message_label: Label
var support: HBoxContainer
var support_title: Label
var support_body: Label
var close_button: Button
var confirm_button: Button
var previous_focus: WeakRef

func _init() -> void:
	set_meta("menu_popup_custom",true)

static func presentation(message: String) -> Dictionary:
	var value: Dictionary = {"category":"PLEASE TRY AGAIN","title":"Something went wrong","message":message,"support_title":"","support":"","symbol":"warning"}
	if message == "Circuit exported." or message == "Track published." or message.begins_with("Draft saved.") or message.begins_with("Saved on this device."):
		value.category = "PUBLISHED" if message == "Track published." else "SAVED"
		value.title = "Track exported" if message == "Circuit exported." else "Track published" if message == "Track published." else "Draft saved"
		value.symbol = "check"
		if message in ["Circuit exported.","Track published."]:
			value.category = ""
			value.message = ""
	elif message.begins_with("Track creator:"):
		value.category = "TRACK INFORMATION"
		value.title = "Track creator"
		value.symbol = "person"
	elif message.begins_with("Changes autosave"):
		value.category = "HELP"
		value.title = "Using the track editor"
		value.symbol = "help"
	elif message.begins_with("Confirm or cancel") or message.begins_with("Complete or cancel"):
		value.category = "ACTION REQUIRED"
		value.title = "Pending previews"
		value.symbol = "edit"
	elif message.begins_with("Sign in to publish"):
		value.category = "ACCOUNT REQUIRED"
		value.title = "Sign in to publish"
		value.symbol = "publish"
	elif message.contains("Your publication request is saved"):
		value.category = "PUBLICATION PENDING"
		value.title = "Publication queued"
		value.symbol = "clock"
	elif message.contains("matching server update"):
		value.category = "UPDATE REQUIRED"
		value.title = "Can't go online yet"
		value.support_title = "Keep racing offline"
		value.support = "Choose a downloaded track in Free Race."
	elif message.contains("newer game version"):
		value.category = "UPDATE REQUIRED"
		value.title = "Update to race online"
		value.support_title = "Keep racing offline"
		value.support = "Choose a downloaded track in Free Race."
	elif message.contains("game and server versions") or message.contains("different game build") or message.contains("different verification contract"):
		value.category = "UPDATE REQUIRED"
		value.title = "Online racing unavailable"
	elif message.contains("storage") or message.contains("saved"):
		value.category = "STORAGE PROBLEM"
		value.title = "Couldn't save your changes"
	elif message.contains("changed while preparing"):
		value.category = "RACE CANCELLED"
		value.title = "Please start again"
	elif message.contains("timed out") or message.contains("connection") or message.contains("connect"):
		value.category = "CONNECTION PROBLEM"
		value.title = "Couldn't start the race" if message.to_lower().contains("race") else "Connection unavailable"
	elif message.to_lower().contains("track") or message.to_lower().contains("race"):
		value.category = "RACE UNAVAILABLE"
		value.title = "Couldn't start the race" if message.to_lower().contains("race") else "Track unavailable"
	return value

func _ready() -> void:
	var value: Dictionary = presentation(dialog_text)
	name = "FaultDialog"
	title = ""
	borderless = true
	transparent_bg = true
	transparent = true
	unresizable = true
	exclusive = true
	wrap_controls = false
	min_size = Vector2i(280,260)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	get_label().hide()
	get_ok_button().hide()
	surface = Control.new()
	surface.name = "FaultSurface"
	surface.theme = MenuStyle.theme()
	add_child(surface)
	MenuStyle.fill(surface)
	art = TextureRect.new()
	art.name = "FaultScenery"
	art.texture = ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = ART_SHADER
	art.material = material
	surface.add_child(art)
	MenuStyle.fill(art)
	warning = TextureRect.new()
	warning.name = "FaultWarning"
	warning.texture = MenuIcon.texture(str(value.symbol),true)
	warning.modulate = MenuStyle.ACCENT
	warning.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	warning.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(warning)
	copy_scroll = ScrollContainer.new()
	copy_scroll.name = "FaultCopyScroll"
	copy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	copy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	surface.add_child(copy_scroll)
	details = VBoxContainer.new()
	details.name = "FaultDetails"
	details.add_theme_constant_override("separation",14)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_scroll.add_child(details)
	eyebrow = MenuStyle.label(str(value.category),19)
	eyebrow.name = "FaultCategory"
	eyebrow.add_theme_font_override("font",MenuStyle.DISPLAY)
	eyebrow.add_theme_color_override("font_color",MenuStyle.ACCENT)
	eyebrow.visible = not str(value.category).is_empty()
	details.add_child(eyebrow)
	heading = MenuStyle.label(str(value.title),44)
	heading.name = "FaultHeading"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(heading)
	message_label = MenuStyle.label(str(value.message),19,true)
	message_label.visible = not str(value.message).is_empty()
	message_label.name = "FaultMessage"
	message_label.add_theme_color_override("font_color",Color("c6d1d6"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(message_label)
	support = HBoxContainer.new()
	support.name = "FaultSupport"
	support.add_theme_constant_override("separation",14)
	support.visible = not str(value.support).is_empty()
	details.add_child(support)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(48,48)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override("panel",MenuStyle.box(Color("172b35"),11))
	support.add_child(badge)
	var icon := TextureRect.new()
	icon.texture = MenuIcon.texture("flag")
	icon.custom_minimum_size = Vector2(26,26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",4)
	support.add_child(copy)
	support_title = MenuStyle.label(str(value.support_title),18)
	copy.add_child(support_title)
	support_body = MenuStyle.label(str(value.support),16,true)
	support_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(support_body)
	close_button = MenuStyle.button("",_cancel)
	close_button.name = "FaultClose"
	close_button.icon = MenuIcon.texture("close")
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "Close"
	close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	surface.add_child(close_button)
	confirm_button = MenuStyle.button("OK",_confirm,true)
	confirm_button.name = "FaultConfirm"
	confirm_button.add_theme_font_size_override("font_size",26)
	confirm_button.add_theme_color_override("font_focus_color",MenuStyle.INK)
	confirm_button.add_theme_color_override("font_pressed_color",MenuStyle.INK)
	surface.add_child(confirm_button)
	surface.resized.connect(_layout)
	about_to_popup.connect(_opening)
	visibility_changed.connect(_visibility_changed)
	_layout()

func popup_message() -> void:
	var bounds: Vector2 = get_parent().get_viewport().get_visible_rect().size
	popup_centered(Vector2i(minf(880,bounds.x-48),minf(440 if message_label.visible else 320,bounds.y-48)))

func _opening() -> void:
	var focused: Control = get_parent().get_viewport().gui_get_focus_owner()
	if focused != null: previous_focus = weakref(focused)
	if not is_instance_valid(backdrop):
		backdrop = ColorRect.new()
		backdrop.name = "FaultMessageScrim"
		backdrop.color = MenuStyle.POPUP_DIM
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop.z_index = 4095
		get_parent().add_child(backdrop)
		MenuStyle.fill(backdrop)
	backdrop.show()
	_focus_confirm.call_deferred()

func _focus_confirm() -> void:
	if is_inside_tree() and visible and is_instance_valid(confirm_button) and confirm_button.is_inside_tree(): confirm_button.grab_focus()

func _visibility_changed() -> void:
	if visible: return
	if is_instance_valid(backdrop): backdrop.hide()
	if previous_focus != null:
		var focused: Control = previous_focus.get_ref() as Control
		if is_instance_valid(focused) and focused.is_visible_in_tree(): focused.grab_focus()

func _exit_tree() -> void:
	if is_instance_valid(backdrop): backdrop.queue_free()

func _confirm() -> void:
	confirmed.emit()
	hide()

func _cancel() -> void:
	canceled.emit()
	hide()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_confirm()
		get_viewport().set_input_as_handled()

func _layout() -> void:
	var compact: bool = surface.size.x < 620
	var left: float = 24.0 if compact else surface.size.x*0.43
	var top: float = 56.0 if compact else 44.0
	var width: float = maxf(180,surface.size.x-left-36)
	(art.material as ShaderMaterial).set_shader_parameter("panel_size",surface.size)
	(art.material as ShaderMaterial).set_shader_parameter("compact",compact)
	warning.visible = not compact
	warning.size = Vector2(150,150)
	warning.position = Vector2(surface.size.x*0.205-75,surface.size.y*0.46-75)
	copy_scroll.position = Vector2(left,top)
	copy_scroll.size = Vector2(width,maxf(80,surface.size.y-top-100))
	heading.add_theme_font_size_override("font_size",32 if compact else 44)
	message_label.add_theme_font_size_override("font_size",17 if compact else 19)
	close_button.position = Vector2(surface.size.x-60,8)
	close_button.size = Vector2(52,52)
	confirm_button.size = Vector2(minf(260,surface.size.x-48),56)
	confirm_button.position = Vector2((surface.size.x-confirm_button.size.x)*0.5,surface.size.y-80)
