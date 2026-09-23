class_name TrackRating
extends HBoxContainer
## Personal track identity, independent of car, physics version and race records.
signal rated
signal save_failed
var records: LocalRecords
var track_id: String
var stars: Array[Button] = []
var caption: Label
var locked: bool = false

func value() -> int:
	return int(records.settings.get("track_ratings",{}).get(track_id,0))

func _ready() -> void:
	name = "TrackRating"
	add_theme_constant_override("separation",6)
	caption = MenuStyle.label("YOUR TRACK RATING",15,true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(caption)
	for score: int in range(1,6):
		var button := MenuStyle.button("",choose.bind(score))
		button.name = "Rate%d" % score
		button.tooltip_text = "Rate track %d out of 5" % score
		button.custom_minimum_size = Vector2(44,44)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width",22)
		add_child(button)
		stars.append(button)
	refresh()

func refresh() -> void:
	for i: int in range(stars.size()):
		stars[i].icon = MenuIcon.texture("star_filled" if i < value() else "star")
		stars[i].add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if i < value() else MenuStyle.MUTED)
		stars[i].add_theme_color_override("icon_disabled_color",MenuStyle.ACCENT if i < value() else MenuStyle.MUTED)

func choose(score: int) -> void:
	if locked or score < 1 or score > 5: return
	var ratings: Dictionary = records.settings.get("track_ratings",{}).duplicate()
	ratings[track_id] = score
	records.settings["track_ratings"] = ratings
	if records.save_records() != OK:
		caption.text = "Couldn't save. Try again."
		refresh()
		save_failed.emit()
		return
	caption.text = "YOUR TRACK RATING"
	refresh()
	rated.emit()
