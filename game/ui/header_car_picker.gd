extends MenuButton
## The car half of the header; the adjacent player name opens Profile.
signal vehicle_selected(index: int)
var records: LocalRecords
const Icons = preload("res://ui/header_car_icons.gd")

func _ready() -> void:
	name = "MenuCarPicker"
	tooltip_text = "Choose car"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta("audio_cue","select")
	add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	add_theme_stylebox_override("hover",MenuStyle.box(Color(1,1,1,0.07),0))
	add_theme_stylebox_override("pressed",MenuStyle.box(Color(MenuStyle.ACCENT,0.12),0))
	var popup: PopupMenu = get_popup()
	popup.name = "HeaderCarDropdown"
	preload("res://ui/popup_style.gd").watch(popup)
	popup.add_theme_constant_override("v_separation",12)
	popup.about_to_popup.connect(_populate)
	popup.id_pressed.connect(_choose)
	var motion := preload("res://ui/header_car_motion.gd").new()
	motion.popup = popup
	add_child(motion)
	_populate()

func _populate() -> void:
	var popup: PopupMenu = get_popup()
	popup.clear()
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		if id == VehicleCatalog.selected: continue
		popup.add_icon_item(Icons.texture(id,records),VehicleCatalog.CLASSES[index],index)
		var row: int = popup.item_count-1
		popup.set_item_icon_max_width(row,88)
	popup.set_focused_item(0)

func refresh_picture(vehicle: String) -> void:
	var popup: PopupMenu = get_popup()
	for row: int in range(popup.item_count):
		if VehicleCatalog.IDS[popup.get_item_id(row)] == vehicle:
			popup.set_item_icon(row,Icons.texture(vehicle,records))

func _choose(index: int) -> void:
	if not is_inside_tree() or not is_visible_in_tree(): return
	if index < 0 or index >= VehicleCatalog.IDS.size(): return
	vehicle_selected.emit(index)
