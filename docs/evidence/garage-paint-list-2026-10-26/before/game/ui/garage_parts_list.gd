extends VBoxContainer
## Compact, numbered configurator. It never creates photos or another world.
var heading: Label
var counter: Label
var balance: Label
var category_slot: VBoxContainer
var scroll: ScrollContainer
var cards: GridContainer
var equip: Button
var selected_title: String = ""

func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	var top := HBoxContainer.new()
	add_child(top)
	var caption: Label = MenuStyle.label("CUSTOMISE / EXTERIOR",16,true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_override("font",MenuStyle.DISPLAY)
	top.add_child(caption)
	balance = MenuStyle.label("",19)
	balance.name = "CustomisationBalance"
	balance.add_theme_font_override("font",MenuStyle.DISPLAY)
	balance.add_theme_color_override("font_color",MenuStyle.ACCENT)
	top.add_child(balance)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	add_child(row)
	heading = MenuStyle.label("",46)
	heading.name = "KitCategoryHeading"
	heading.add_theme_font_override("font",MenuStyle.DISPLAY)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	counter = MenuStyle.label("",28,true)
	counter.name = "KitSelectionCounter"
	counter.add_theme_font_override("font",MenuStyle.DISPLAY)
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(counter)
	category_slot = VBoxContainer.new()
	add_child(category_slot)
	scroll = preload("res://ui/vertical_swipe_scroll.gd").new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	add_child(scroll)
	cards = GridContainer.new()
	cards.columns = 1
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("v_separation",8)
	scroll.add_child(cards)
	equip = MenuStyle.button("Buy & Equip",func() -> void: pass,true)
	equip.name = "CosmeticEquip"
	equip.custom_minimum_size.y = 60
	equip.add_theme_font_size_override("font_size",25)
	add_child(equip)
	resized.connect(_layout_cards)

func show_choice(label: String, equipped: bool, owned: bool, cost: int, index: int, total: int, category: String) -> void:
	selected_title = GameText.message(label)
	GameText.bind_upper(heading,str(VehicleCustomisation.LABELS[category]))
	counter.text = "%02d / %02d" % [index+1,total]
	equip.visible = not equipped
	equip.disabled = equipped
	GameText.bind(equip,"Equip" if owned else "Buy & Equip · {cost}",{"cost":GameText.message("%d coins") % cost})
	_layout_cards.call_deferred()

func _layout_cards() -> void:
	if not is_inside_tree(): return
	var compact: bool = get_viewport_rect().size.y<650
	add_theme_constant_override("separation",6 if compact else 12)
	heading.add_theme_font_size_override("font_size",34 if compact else 46)
	counter.add_theme_font_size_override("font_size",24 if compact else 30)
	equip.custom_minimum_size.y = 50 if compact else 60
	for row: Control in cards.get_children(): row._layout()
