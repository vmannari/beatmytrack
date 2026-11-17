extends PanelContainer
## Selection profile. Bars describe stock cars; tooltips retain measured figures.
const SUMMARIES: Dictionary = {
	"compact":"Agile and forgiving. Built for mixed circuits.",
	"kart":"Light on its feet. Precise through the tightest corners.",
	"forklift":"Heavy traction. Rear-wheel steering with a tail that swings wide.",
	"electric":"Instant power. Feed in the throttle and control the slide.",
	"hovercraft":"Long, flowing slides. Steer early and find your rhythm.",
	"super_rally":"Explosive off the line. Confident in every corner."
}
const SUBTITLES: Dictionary = {
	"compact":"Mixed-surface all-rounder", "kart":"Lightweight precision",
	"forklift":"Heavy-duty character", "electric":"Instant electric power",
	"hovercraft":"Air-cushion drift", "super_rally":"All-terrain power"
}
# Authored ease-of-control comparisons; hover steering is not wheel traction.
const HANDLING: Dictionary = {"compact":4,"kart":5,"forklift":4,"electric":3,"hovercraft":2,"super_rally":4}
const CAPTIONS: Dictionary = {"acceleration":"Acceleration","handling":"Handling","top_speed":"Top speed"}
static var _measurements: Dictionary = {}
var vehicle_id: String = ""
var stat_rows: Dictionary = {}
var ratings: Dictionary = {}
var _stack: VBoxContainer
var _title: Label
var _subtitle: Label
var _description: Label
var _rows: VBoxContainer
var _compact: bool = false
var _density: float = 1.0
var _built: bool = false
var _text_layout_key: Array = []

class RatingBar extends Control:
	var rating: int = 0:
		set(value):
			rating = clampi(value,0,5)
			queue_redraw()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		custom_minimum_size = Vector2(98,12)
	func _draw() -> void:
		var gap: float = 3.0
		var width: float = (size.x-gap*4.0)/5.0
		for index: int in range(5):
			var style: StyleBoxFlat = MenuStyle.box(MenuStyle.ACCENT if index < rating else Color("4b5d67"),0)
			style.set_corner_radius_all(2)
			style.draw(get_canvas_item(),Rect2(Vector2(index*(width+gap),0),Vector2(width,size.y)))

static func performance(id: String) -> Dictionary:
	id = VehicleCatalog.valid_id(id)
	if _measurements.has(id): return _measurements[id]
	var config: HandlingConfig = VehicleCatalog.config(id,HandlingSelection.ORIGINAL_PLUS_INDEX)
	var launch: Array = preload("res://ui/garage_performance_data.gd").LAUNCHES.get(id,[])
	var seconds: float = float(launch[1]) if launch.size() == 2 and launch[0] == JSON.stringify(config.snapshot()).sha256_text() else -1.0
	var result: Dictionary = {"top_speed":roundi(config.maximum_speed*3.6),"acceleration":seconds,"mass":roundi(config.mass)}
	_measurements[id] = result
	return result

static func comparison(id: String) -> Dictionary:
	var data: Dictionary = performance(id)
	return {"acceleration":clampi(roundi(4.0/float(data.acceleration)),1,5) if data.acceleration > 0.0 else 0,
		"handling":int(HANDLING[VehicleCatalog.valid_id(id)]),"top_speed":clampi(roundi(float(data.top_speed)/60.0),1,5)}

func _ready() -> void:
	name = "GarageCarStats"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	_title = MenuStyle.label("",42)
	_title.name = "GarageCarProfileTitle"
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_override("font",MenuStyle.DISPLAY)
	GameText.user_text(_title)
	_stack.add_child(_title)
	_subtitle = MenuStyle.label("",18,true)
	_subtitle.name = "GarageCarCharacter"
	_subtitle.add_theme_font_override("font",MenuStyle.DISPLAY)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack.add_child(_subtitle)
	_divider()
	var rows := VBoxContainer.new()
	_rows = rows
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation",6)
	_stack.add_child(rows)
	for key: String in ["acceleration","handling","top_speed"]:
		var row := HBoxContainer.new()
		row.name = "GarageRating_"+key
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(row)
		var caption: Label = MenuStyle.label("",18,true)
		caption.add_theme_font_override("font",MenuStyle.DISPLAY)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		GameText.bind_upper(caption,CAPTIONS[key])
		row.add_child(caption)
		var bar := RatingBar.new()
		row.add_child(bar)
		stat_rows[key] = {"row":row,"caption":caption,"bar":bar}
	_divider()
	_description = MenuStyle.label("",14)
	_description.name = "GarageCarDescription"
	_description.add_theme_font_override("font",MenuStyle.BODY)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack.add_child(_description)
	_built = true
	_apply_density()
	set_vehicle(vehicle_id if not vehicle_id.is_empty() else VehicleCatalog.selected)

func _divider() -> void:
	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(divider)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _built:
		set_vehicle(vehicle_id)

func set_vehicle(id: String) -> void:
	vehicle_id = VehicleCatalog.valid_id(id)
	if not _built: return
	var data: Dictionary = performance(vehicle_id)
	ratings = comparison(vehicle_id)
	_title.text = VehicleCatalog.title(vehicle_id)
	GameText.bind_upper(_subtitle,SUBTITLES[vehicle_id])
	GameText.bind(_description,SUMMARIES[vehicle_id])
	for key: String in stat_rows:
		var parts: Dictionary = stat_rows[key]
		parts.bar.rating = ratings[key]
		parts.bar.accessibility_name = GameText.message("{stat}: {rating} of 5",{"stat":GameText.message(CAPTIONS[key]),"rating":ratings[key]})
		parts.row.tooltip_text = GameText.message("{speed} km/h",{"speed":data.top_speed}) if key == "top_speed" else GameText.message("0–60 km/h: {time} s",{"time":"%.1f" % data.acceleration}) if key == "acceleration" and data.acceleration >= 0.0 else GameText.message(SUMMARIES[vehicle_id])

func fit_in_preview(dimensions: Vector2) -> void:
	var compact: bool = dimensions.y < 300.0
	var density: float = 0.8 if compact else clampf(dimensions.y/380.0,0.95,1.25)
	if compact != _compact or not is_equal_approx(density,_density):
		_compact = compact
		_density = density
		_apply_density()
	position = Vector2(8,8)
	size.x = clampf(dimensions.x*0.275,248.0 if compact else 288.0,280.0 if compact else 410.0)
	var layout_key: Array = [size.x,_density,TranslationServer.get_locale()]
	if layout_key != _text_layout_key:
		_text_layout_key = layout_key
		var style: StyleBox = get_theme_stylebox("panel")
		var text_width: float = size.x-style.get_minimum_size().x
		_reserve_text_height(_subtitle,SUBTITLES,text_width)
		_reserve_text_height(_description,SUMMARIES,text_width)
	size.y = get_combined_minimum_size().y

func _reserve_text_height(label: Label, texts: Dictionary, width: float) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var height: float = 0.0
	for text: String in texts.values():
		var translated: String = GameText.message(text)
		if label == _subtitle: translated = translated.to_upper()
		height = maxf(height,font.get_multiline_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,width,font_size).y)
	label.custom_minimum_size.y = ceilf(height)

func _apply_density() -> void:
	var style: StyleBoxFlat = MenuStyle.box(Color(0.025,0.05,0.065,0.91),10 if _compact else roundi(18*_density))
	style.border_color = Color(MenuStyle.MUTED,0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel",style)
	if not _built: return
	_stack.add_theme_constant_override("separation",2 if _compact else roundi(8*_density))
	_rows.add_theme_constant_override("separation",2 if _compact else 6)
	_title.add_theme_font_size_override("font_size",28 if _compact else roundi(46*_density))
	_subtitle.add_theme_font_size_override("font_size",14 if _compact else roundi(20*_density))
	_description.add_theme_font_size_override("font_size",12 if _compact else roundi(16*_density))
	_description.add_theme_constant_override("line_spacing",0)
	for parts: Dictionary in stat_rows.values():
		parts.caption.add_theme_font_size_override("font_size",14 if _compact else roundi(20*_density))
		parts.bar.custom_minimum_size = Vector2(82,10) if _compact else Vector2(98,12)*_density
