extends CanvasLayer
signal selected(index: int)
signal confirmed
signal cancelled
var slider: HSlider
var heading: Label
var details: Label
var credits: Label
var status: Label
var confirm: Button
var cancel: Button
var ad: Button
var buy: Button

func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = RaceHUDStyle.theme()
	add_child(root)
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 28
	card.offset_right = -28
	card.offset_top = -252
	card.offset_bottom = -20
	var style := RaceHUDStyle.panel(true)
	style.bg_color = Color("102330f5")
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel",style)
	root.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	card.add_child(box)
	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	heading = _label(title_row,"REWIND",28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details = _label(title_row,"",22)
	slider = HSlider.new()
	slider.name = "RewindTimeline"
	slider.step = 1
	slider.custom_minimum_size.y = 42
	slider.value_changed.connect(func(value: float) -> void: selected.emit(int(value)))
	box.add_child(slider)
	credits = _label(box,"Checking resumes…",17)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status = _label(box,"Drag to choose where to resume. Cancelling costs nothing.",16)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	box.add_child(actions)
	cancel = _button(actions,"Cancel",func() -> void: cancelled.emit())
	ad = _button(actions,"Watch ad · +1",func() -> void: pass)
	ad.disabled = true
	ad.tooltip_text = "Rewarded ads are not configured yet."
	buy = _button(actions,"Buy resumes",func() -> void: pass)
	buy.disabled = true
	buy.tooltip_text = "Resume packs are not configured yet."
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	confirm = _button(actions,"Resume here",func() -> void: confirmed.emit())
	var accent := RaceHUDStyle.panel(true)
	accent.bg_color = RaceHUDStyle.GOLD
	confirm.add_theme_stylebox_override("normal",accent)
	confirm.add_theme_color_override("font_color",RaceHUDStyle.INK)
	confirm.disabled = true

func _label(parent: Node, text: String, font_size: int) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_color_override("font_color",RaceHUDStyle.TEXT)
	value.add_theme_font_size_override("font_size",font_size)
	parent.add_child(value)
	return value

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(126,48)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func show_balance(wallet: Dictionary, used: int) -> void:
	credits.text = "%d / 3 resumes used this race   ·   Free today: %d   ·   Saved: %d   ·   Daily reset 00:00 UTC" % [used,int(wallet.get("free",0)),int(wallet.get("balance",0))]
	confirm.disabled = used >= 3 or int(wallet.get("free",0))+int(wallet.get("balance",0)) <= 0
	if confirm.disabled: status.text = "No resumes available. Ads and resume packs are not configured yet."

func set_busy(value: bool) -> void:
	confirm.disabled = value
	cancel.disabled = value
	slider.editable = not value
