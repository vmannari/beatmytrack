extends "res://ui/fault_dialog.gd"
## Keep the finished lap available while offering an explicit way back.
signal return_requested
var return_caption: String = "Return to editor"
var retry_caption: String = "Retry saving"
var return_button: Button

func _ready() -> void:
	_publication_value = {"category":"","title":"Couldn't finish saving","message":dialog_text,"support_title":"","support":"","symbol":"warning"}
	super()
	name = "PracticeSaveRecovery"
	confirm_button.text = GameText.message(retry_caption)
	return_button = MenuStyle.button(return_caption,_return)
	return_button.name = "PracticeSaveReturn"
	surface.add_child(return_button)
	_layout()

func _return() -> void:
	return_requested.emit()
	hide()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_ENTER,KEY_KP_ENTER] and is_instance_valid(return_button) and return_button.has_focus():
		_return()
		get_viewport().set_input_as_handled()
	else: super(event)

func _layout() -> void:
	super()
	if not is_instance_valid(return_button): return
	if surface.size.x < 620:
		for button: Button in [confirm_button,return_button]: button.size = Vector2(surface.size.x-48,52)
		confirm_button.position = Vector2(24,surface.size.y-140)
		return_button.position = Vector2(24,surface.size.y-80)
		copy_scroll.size.y = maxf(60,confirm_button.position.y-copy_scroll.position.y-16)
	else:
		var width: float = minf(260,(surface.size.x-60)*.5)
		var left: float = (surface.size.x-width*2-12)*.5
		confirm_button.size = Vector2(width,56)
		return_button.size = Vector2(width,56)
		confirm_button.position = Vector2(left,surface.size.y-80)
		return_button.position = Vector2(left+width+12,surface.size.y-80)
