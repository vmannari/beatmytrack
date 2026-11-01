extends PanelContainer
const Progress = preload("res://persistence/daily_progress.gd")
const Medal = preload("res://ui/daily_medal.gd")
var entries: Dictionary = {}
var day: int = 0
var vehicle: String = "compact"

func _ready() -> void: refresh()

func refresh() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var style: StyleBoxFlat = MenuStyle.box(Color("0b1a26e8"),12)
	style.border_color = Color("3b5362")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel",style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	add_child(row)
	var awards: Array[int] = Progress.week(entries,day,vehicle)
	var today: int = posmod(day+3,7)
	for index: int in range(7):
		var column := VBoxContainer.new()
		column.name = "DailyWeekDay%d" % index
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",3)
		row.add_child(column)
		var label: Label = MenuStyle.label(["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][index],14,true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		var icon := Medal.new()
		icon.tier = maxi(0,awards[index])
		icon.custom_minimum_size = Vector2(28,32)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		if awards[index] < 0:
			icon.hide()
			var dash: Label = MenuStyle.label("—",26,true)
			dash.custom_minimum_size.y = 32
			dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(dash)
		var underline := ColorRect.new()
		underline.color = MenuStyle.ACCENT if today == index else Color.TRANSPARENT
		underline.custom_minimum_size.y = 3
		column.add_child(underline)
