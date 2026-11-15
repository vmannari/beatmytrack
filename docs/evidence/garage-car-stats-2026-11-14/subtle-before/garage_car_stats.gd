extends PanelContainer
## Browsing information only; measurements use a clean, straight, unboosted launch.
const SUMMARIES: Dictionary = {
	"compact":"Agile and forgiving. A versatile choice for mixed circuits.",
	"kart":"Quick off the line. Tight turns and strong grip; low speed on long straights.",
	"forklift":"Rear-wheel steering swings the tail wide. Strong traction, low top speed.",
	"electric":"Instant rear-wheel power. Responsive steering and controlled power slides.",
	"hovercraft":"Fan-powered air cushion with long, flowing slides. Steer early to hold your line.",
	"super_rally":"Rally's agile, forgiving handling with stronger acceleration and a higher top speed."
}
static var _measurements: Dictionary = {}
var vehicle_id: String = ""
var _stack: VBoxContainer
var _speed: Label
var _acceleration: Label
var _description: Label
var _weight_row: HBoxContainer
var _weight: Label
var _unit_margins: Array[MarginContainer] = []
var _compact: bool = false
var _built: bool = false

static func performance(id: String) -> Dictionary:
	id = VehicleCatalog.valid_id(id)
	if _measurements.has(id): return _measurements[id]
	var config: HandlingConfig = VehicleCatalog.config(id,HandlingSelection.ORIGINAL_PLUS_INDEX)
	# Offline canonical measurements keep simulation construction out of browsing.
	# A changed tune must be measured again rather than showing an old figure.
	var launch: Array = preload("res://ui/garage_performance_data.gd").LAUNCHES.get(id,[])
	var seconds: float = float(launch[1]) if launch.size() == 2 and launch[0] == JSON.stringify(config.snapshot()).sha256_text() else -1.0
	var result: Dictionary = {"top_speed":roundi(config.maximum_speed*3.6),"acceleration":seconds,"mass":roundi(config.mass)}
	_measurements[id] = result
	return result

func _ready() -> void:
	name = "GarageCarStats"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation",12)
	add_child(_stack)
	var metrics := HBoxContainer.new()
	metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics.add_theme_constant_override("separation",18)
	_stack.add_child(metrics)
	_speed = _metric(metrics,"Top speed","km/h","GarageStatTopSpeed")
	var rule := VSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics.add_child(rule)
	_acceleration = _metric(metrics,"0–60 km/h","s","GarageStatAcceleration")
	_weight_row = HBoxContainer.new()
	_weight_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(_weight_row)
	var weight_caption: Label = MenuStyle.label("Weight",14,true)
	weight_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weight_row.add_child(weight_caption)
	_weight = MenuStyle.label("",16)
	_weight.name = "GarageStatWeight"
	GameText.user_text(_weight)
	_weight_row.add_child(_weight)
	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(divider)
	_description = MenuStyle.label("",14)
	_description.name = "GarageCarDescription"
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack.add_child(_description)
	_built = true
	_apply_density()
	set_vehicle(vehicle_id if not vehicle_id.is_empty() else VehicleCatalog.selected)

func _metric(parent: HBoxContainer, caption: String, unit: String, node_name: String) -> Label:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",0)
	parent.add_child(column)
	var title: Label = MenuStyle.label(caption,13,true)
	column.add_child(title)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",5)
	column.add_child(row)
	var number: Label = MenuStyle.label("",38)
	number.name = node_name
	number.add_theme_color_override("font_color",MenuStyle.ACCENT)
	GameText.user_text(number)
	row.add_child(number)
	var suffix: Label = MenuStyle.label(unit,13,true)
	var unit_margin := MarginContainer.new()
	unit_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_margin.size_flags_vertical = Control.SIZE_SHRINK_END
	_unit_margins.append(unit_margin)
	row.add_child(unit_margin)
	unit_margin.add_child(suffix)
	return number

func set_vehicle(id: String) -> void:
	vehicle_id = VehicleCatalog.valid_id(id)
	if not _built: return
	var data: Dictionary = performance(vehicle_id)
	_speed.text = str(data.top_speed)
	_acceleration.text = "%.1f" % data.acceleration if data.acceleration >= 0.0 else "—"
	GameText.bind(_weight,"{weight} kg",{"weight":str(data.mass)})
	GameText.bind(_description,SUMMARIES[vehicle_id])
	reset_size()

func fit_in_preview(dimensions: Vector2) -> void:
	var compact: bool = dimensions.y < 260.0
	if compact != _compact:
		_compact = compact
		_apply_density()
	var inset: float = 12.0 if compact else 24.0
	position = Vector2(inset,inset)
	size.x = clampf(dimensions.x*(0.30 if compact else 0.245),248.0 if compact else 220.0,300.0)
	size.y = get_combined_minimum_size().y

func _apply_density() -> void:
	var style: StyleBoxFlat = MenuStyle.card(12 if _compact else 18)
	style.bg_color = Color(MenuStyle.PANEL,0.94)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel",style)
	if not _built: return
	_stack.add_theme_constant_override("separation",6 if _compact else 12)
	_weight_row.visible = not _compact
	for number: Label in [_speed,_acceleration]: number.add_theme_font_size_override("font_size",28 if _compact else 38)
	for margin: MarginContainer in _unit_margins: margin.add_theme_constant_override("margin_bottom",4 if _compact else 8)
	_description.add_theme_font_size_override("font_size",12 if _compact else 14)
	_description.add_theme_constant_override("line_spacing",0 if _compact else 3)
