extends RefCounted

## Embedded dialogs use viewport units; Android reports keyboard height in pixels.
static func attach(dialog: Window, field: LineEdit) -> void:
	var host: Viewport = dialog.get_parent().get_viewport()
	var timer := Timer.new()
	timer.wait_time = 0.05
	dialog.add_child(timer)
	var update: Callable = func() -> void:
		if not dialog.visible: return
		var height: float = 0.0
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			height = DisplayServer.virtual_keyboard_get_height()
		layout(dialog, host, height)
	timer.timeout.connect(update)
	timer.start()
	update.call_deferred()
	dialog.tree_exiting.connect(func() -> void:
		if is_instance_valid(field) and field.is_inside_tree(): field.release_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide())

static func available_rect(view: Rect2, screen_transform: Transform2D, screen_height: float, keyboard_pixels: float) -> Rect2:
	var result: Rect2 = view.grow(-8.0)
	if keyboard_pixels > 0.0:
		var top: float = (screen_transform.affine_inverse() * Vector2(0, screen_height-keyboard_pixels)).y
		result.size.y = maxf(1.0, minf(result.end.y, top-8.0)-result.position.y)
	return result

static func layout(dialog: Window, host: Viewport, keyboard_pixels: float) -> void:
	var usable: Rect2 = available_rect(host.get_visible_rect(), host.get_screen_transform(), DisplayServer.window_get_size().y, keyboard_pixels)
	var minimum: Vector2i = dialog.get_contents_minimum_size()
	dialog.size = Vector2i(maxi(minimum.x, mini(dialog.size.x, int(usable.size.x))), minimum.y)
	dialog.position = Vector2i(usable.position + (usable.size-Vector2(dialog.size))*0.5)
