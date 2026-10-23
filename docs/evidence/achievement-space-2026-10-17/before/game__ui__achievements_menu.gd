extends VBoxContainer
## A bounded, cached collection opened explicitly from the Trophy Room.
var service: Node
var category: String = "All"
var filter: int = 0
var selected: String = "races"
var grid: GridContainer
var detail: VBoxContainer
var summary: Label
var status: Label
const TIER_NAMES: Array[String] = ["Locked","Bronze","Silver","Gold","Platinum"]

func _ready() -> void:
	name = "AchievementsMenu"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	var title_row := HBoxContainer.new()
	add_child(title_row)
	var title: Label = MenuStyle.label("ACHIEVEMENTS",34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	summary = MenuStyle.label("0 / 130",28)
	summary.name = "AchievementSummary"
	title_row.add_child(summary)
	add_child(MenuStyle.label("Career milestones and special honors",18,true))
	var controls := HBoxContainer.new()
	add_child(controls)
	var categories := OptionButton.new()
	categories.name = "AchievementCategories"
	categories.custom_minimum_size = Vector2(220,52)
	categories.add_item("All categories")
	var values: Array[String] = ["All"]
	for f: Dictionary in AchievementProgress.catalog().families:
		if f.category not in values:
			values.append(f.category)
			categories.add_item(f.category)
	categories.item_selected.connect(func(index: int) -> void:
		category = values[index]
		_rebuild())
	controls.add_child(categories)
	var filters := OptionButton.new()
	filters.name = "AchievementFilter"
	filters.custom_minimum_size = Vector2(185,52)
	for text: String in ["All achievements","Unlocked","In progress","Prestige"]: filters.add_item(text)
	filters.item_selected.connect(func(index: int) -> void:
		filter = index
		_rebuild())
	controls.add_child(filters)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	var refresh: Button = MenuStyle.button("Refresh",func() -> void: service.refresh())
	refresh.name = "AchievementRefresh"
	refresh.custom_minimum_size = Vector2(100,52)
	controls.add_child(refresh)
	status = MenuStyle.label("",16,true)
	status.name = "AchievementStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var scroll: ScrollContainer = preload("res://ui/vertical_swipe_scroll.gd").new()
	scroll.name = "AchievementScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid = GridContainer.new()
	grid.name = "AchievementGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	var panel := PanelContainer.new()
	panel.name = "AchievementDetail"
	panel.add_theme_stylebox_override("panel",MenuStyle.box(MenuStyle.INK,12))
	add_child(panel)
	detail = VBoxContainer.new()
	panel.add_child(detail)
	service.changed.connect(_rebuild)
	resized.connect(_columns)
	_rebuild()
	if is_visible_in_tree(): service.refresh()

func _columns() -> void:
	if is_instance_valid(grid): grid.columns = 2 if size.x >= 850 else 1

func _rebuild() -> void:
	if not is_instance_valid(grid): return
	for node: Node in grid.get_children():
		grid.remove_child(node)
		node.queue_free()
	var earned: int = 0
	var visible_families: Array[Dictionary] = []
	for family: Dictionary in AchievementProgress.catalog().families:
		var source: Dictionary = service.source(family)
		var level: int = AchievementProgress.tier(family,source)
		earned += level
		if category != "All" and family.category != category: continue
		if filter == 1 and level == 0: continue
		if filter == 2 and level >= family.tiers.size(): continue
		if filter == 3 and not family.prestige: continue
		visible_families.append(family)
	var visible_ids: Array[String] = []
	for family: Dictionary in visible_families: visible_ids.append(family.id)
	if selected not in visible_ids: selected = visible_ids[0] if not visible_ids.is_empty() else ""
	for family: Dictionary in visible_families:
		var source: Dictionary = service.source(family)
		_card(family,source,AchievementProgress.tier(family,source))
	if visible_families.is_empty(): grid.add_child(MenuStyle.label("No achievements in this view yet",20,true))
	summary.text = "%d / 130" % earned
	status.text = service.status if not service.status.is_empty() else "Verified milestones sync after race verification. Tracking began with this update; garage care is saved on this profile." if service.authenticated() else "Guest collection · saved on this profile. Sign in for verified competitive and creator milestones."
	_detail()
	_columns()

func _card(f: Dictionary, source: Dictionary, level: int) -> void:
	var button := Button.new()
	button.name = "Achievement_"+f.id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(350,146)
	button.add_theme_stylebox_override("normal",MenuStyle.box(Color("233a46") if selected == f.id else MenuStyle.PANEL,12))
	button.pressed.connect(func() -> void:
		selected = f.id
		_rebuild())
	grid.add_child(button)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	MenuStyle.fill(row)
	row.offset_left = 12
	row.offset_top = 10
	row.offset_right = -12
	row.offset_bottom = -10
	var badge := AchievementBadge.new()
	badge.tier = level
	badge.prestige = f.prestige
	badge.motif = AchievementProgress.catalog().families.find(f)
	badge.mark = _mark(f.id) if f.prestige else ""
	row.add_child(badge)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title: Label = MenuStyle.label(f.title,23)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var next: int = mini(level,f.tiers.size()-1)
	var target: int = int(f.tiers[next])
	var value: int = mini(int(source.get("metrics",{}).get(f.metric,0)),target)
	var distance: bool = f.metric == "distance_m"
	copy.add_child(MenuStyle.label(("Prestige" if f.prestige else TIER_NAMES[level])+"  ·  "+("Profile" if f.scope == "local" else "Verified" if service.authenticated() else "Local"),15,true))
	var progress := ProgressBar.new()
	progress.name = "AchievementProgress_"+f.id
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.custom_minimum_size.y = 9
	progress.max_value = target
	progress.value = target if level == f.tiers.size() else value
	progress.show_percentage = false
	copy.add_child(progress)
	var progress_text: String = "%.1f / %d km" % [value/1000.0,target/1000] if distance else "%d / %d" % [value,target]
	copy.add_child(MenuStyle.label("Complete" if level == f.tiers.size() else progress_text+" · "+("Prestige" if f.prestige else TIER_NAMES[next+1])+" next",17,true))

func _detail() -> void:
	for node: Node in detail.get_children():
		detail.remove_child(node)
		node.queue_free()
	for f: Dictionary in AchievementProgress.catalog().families:
		if f.id != selected: continue
		var source: Dictionary = service.source(f)
		var level: int = AchievementProgress.tier(f,source)
		var description: Label = MenuStyle.label(f.description.replace("{n}",str(int(f.tiers[mini(level,f.tiers.size()-1)]))),18)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(description)
		var row := HBoxContainer.new()
		detail.add_child(row)
		var rarity: Dictionary = service.snapshot.get("rarity",{})
		var population: int = int(rarity.get("eligible",0))
		var key: String = f.id+"/"+str(maxi(level,1))
		var text: String = "Rarity available after 100 eligible players"
		if f.scope == "local" or not service.authenticated(): text = "Local collection · no global rarity"
		elif population >= 100:
			text = "Unlocked by %.1f%% of %d eligible players" % [100.0*float(rarity.get("unlocks",{}).get(key,0))/population,population]
		var rarity_label: Label = MenuStyle.label(text,16,true)
		rarity_label.name = "AchievementRarity"
		rarity_label.tooltip_text = str(rarity.get("definition",""))
		rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rarity_label)
		var pin: Button = MenuStyle.button("Unfeature" if f.id in service.featured() else "Feature (%d/5)" % service.featured().size(),service.toggle_feature.bind(f.id))
		pin.name = "AchievementFeature"
		pin.custom_minimum_size = Vector2(150,52)
		pin.disabled = level == 0 or service.busy
		row.add_child(pin)

func _mark(id: String) -> String:
	return {"untouchable":"UT","perfectionist":"PF","king":"KT","odds":"AO","seasons":"MS","comeback":"CK","legend":"TL","unbeaten":"UB","full_grid":"FG","scholar":"RS"}.get(id,"")
