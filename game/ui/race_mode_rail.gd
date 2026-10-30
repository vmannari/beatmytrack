class_name RaceModeRail
extends VBoxContainer
## One shared race-mode vocabulary and visual language across Race views.
signal mode_requested(mode: String)
var selected: String = "free"

func _ready() -> void:
	name = "RaceModes"
	add_theme_constant_override("separation",12)
	for item: Array in [["trophy","Weekly Rivalry","rivalry"],["sun","Track of the day","daily"],["flag","Free race","free"],["target","Challenges","challenges"]]:
		var active: bool = item[2] == selected
		var available: bool = item[2] in ["rivalry","free","daily","challenges"]
		var button := MenuStyle.button("",func() -> void: mode_requested.emit(item[2]),active)
		# Navigation commits on DOWN: a refresh or the end of the page slide may
		# replace this rail before UP. The rail is outside content swipe gestures.
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.icon = preload("res://ui/race_mode_icons.gd").texture(item[0])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",38)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.add_theme_color_override("icon_normal_color",MenuStyle.INK if active else MenuStyle.TEXT)
		button.add_theme_color_override("icon_disabled_color",Color("9cbbc8"))
		var style := MenuStyle.box(MenuStyle.ACCENT if active else Color("10212c"),10)
		style.border_color = Color("ffe792") if active else Color("2a4655")
		style.set_border_width_all(1)
		if active:
			style.border_width_top = 2
			style.shadow_color = Color("ffc83d33")
			style.shadow_size = 4
			style.shadow_offset = Vector2(0,2)
		button.add_theme_stylebox_override("normal",style)
		button.add_theme_stylebox_override("disabled",style)
		button.name = "Mode_"+str(item[0])
		button.custom_minimum_size = Vector2(60,60)
		button.tooltip_text = str(item[1])+("" if available else " · Coming soon")
		button.disabled = not available
		add_child(button)
