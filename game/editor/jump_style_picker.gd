extends RefCounted
## Editor controls remain outside the data-only verification project.

static func make(profile: String, changed: Callable, include_legacy: bool = false) -> OptionButton:
	var button := OptionButton.new()
	button.name = "JumpStyle"
	button.custom_minimum_size = Vector2(175,44)
	button.tooltip_text = "Jump or bump style"
	EditorStyle.apply(button)
	var choices: Array[String] = JumpProfiles.IDS.duplicate()
	if include_legacy: choices.push_front("legacy")
	for choice: String in choices: button.add_item(JumpProfiles.label(choice))
	button.select(maxi(0,choices.find(profile)))
	button.item_selected.connect(func(index: int) -> void: changed.call(choices[index]))
	return button
