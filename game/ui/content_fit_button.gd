extends Button
## Deferred fitting belongs to the button, so destruction cancels pending work.
var _caption_path: NodePath
var _caption_floor: float = 0.0
var _caption_padding: float = 0.0

func watch_content(content: Control, minimum_height: float, padding: float = 0.0) -> void:
	_caption_path = get_path_to(content)
	_caption_floor = minimum_height
	_caption_padding = padding
	content.minimum_size_changed.connect(_fit_content)
	_fit_content.call_deferred()

func _fit_content() -> void:
	var content: Control = get_node_or_null(_caption_path)
	if content != null:
		custom_minimum_size.y = maxf(_caption_floor,content.get_combined_minimum_size().y+_caption_padding)
