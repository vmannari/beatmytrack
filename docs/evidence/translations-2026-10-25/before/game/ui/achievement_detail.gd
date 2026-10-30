extends RefCounted
## Player-facing presentation only; progress and feature ownership stay in the service.
const TIER_NAMES: Array[String] = ["Locked","Bronze","Silver","Gold","Platinum"]
const Stage = preload("res://ui/achievement_medal_stage.gd")

static func number(value: int) -> String:
	var digits: String = str(value)
	var result: String = ""
	for i: int in range(digits.length()):
		if i > 0 and (digits.length()-i)%3 == 0: result += ","
		result += digits[i]
	return result

static func amount(f: Dictionary, value: int) -> String:
	if f.metric == "distance_m": return number(value/1000)+" km"
	return number(value)

static func requirement(f: Dictionary, target: int) -> String:
	if f.metric == "distance_m": return GameText.message("Drive %s km in completed races.") % number(target/1000)
	var result: String = f.description.replace("{n}",number(target))
	if target == 1:
		for plural: String in ["races","tracks","cars","biomes","times","challenges","weeks","friends"]:
			result = result.replace("1 different "+plural,"1 "+plural.trim_suffix("s"))
			result = result.replace("1 "+plural,"1 "+plural.trim_suffix("s"))
		result = result.replace("1 Weekly Rivalry weeks","1 Weekly Rivalry week")
	return result

static func copy(parent: Node, text: String, size: int, muted: bool = false) -> Label:
	var label: Label = MenuStyle.label(text,size,muted)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

static func build(detail: VBoxContainer, footer: VBoxContainer, f: Dictionary, source: Dictionary, level: int, service: Node) -> void:
	var complete: bool = level == f.tiers.size()
	var next: int = mini(level,f.tiers.size()-1)
	var target: int = int(f.tiers[next])
	var value: int = clampi(int(source.get("metrics",{}).get(f.metric,0)),0,target)
	var metal: Color = AchievementBadge.METALS[3 if f.prestige else maxi(level,1)]
	var target_metal: Color = AchievementBadge.METALS[3 if f.prestige else next+1]
	var hero := HBoxContainer.new()
	hero.name = "AchievementMedalPreview"
	hero.add_theme_constant_override("separation",20)
	detail.add_child(hero)
	var mount := VBoxContainer.new()
	mount.add_theme_constant_override("separation",0)
	hero.add_child(mount)
	var stage := Stage.new()
	stage.custom_minimum_size = Vector2(132,116)
	stage.metal = metal
	mount.add_child(stage)
	var badge := AchievementBadge.new()
	badge.family_id = f.id
	badge.tier = level
	stage.add_child(badge)
	MenuStyle.fill(badge)
	badge.offset_left = 12
	badge.offset_right = -12
	var status: Label = copy(mount,("HONOR EARNED" if f.prestige else TIER_NAMES[level].to_upper()+" EARNED") if level > 0 else "NOT YET EARNED",13)
	status.name = "AchievementEarnedState"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color",metal if level > 0 else MenuStyle.MUTED)
	var objective := VBoxContainer.new()
	objective.alignment = BoxContainer.ALIGNMENT_CENTER
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.add_theme_constant_override("separation",6)
	hero.add_child(objective)
	var next_label: Label = copy(objective,"PRESTIGE HONOR" if complete and f.prestige else "COLLECTION COMPLETE" if complete else "PRESTIGE CHALLENGE" if f.prestige else "NEXT MEDAL / "+TIER_NAMES[next+1].to_upper(),14)
	next_label.name = "AchievementNextTier"
	next_label.add_theme_color_override("font_color",target_metal)
	var description: Label = copy(objective,requirement(f,target),20)
	description.name = "AchievementRequirement"
	# Binary honors have no meaningful partial progress to display.
	if not f.prestige or target > 1:
		var progress_row := HBoxContainer.new()
		objective.add_child(progress_row)
		var progress_copy: Label = copy(progress_row,"Progress" if not complete else "Completed",15,true)
		progress_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count: Label = copy(progress_row,amount(f,target if complete else value)+" / "+amount(f,target),16)
		count.name = "AchievementDetailCount"
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.size_flags_horizontal = Control.SIZE_FILL
		var progress := ProgressBar.new()
		progress.name = "AchievementDetailProgress"
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.custom_minimum_size.y = 5
		progress.max_value = target
		progress.value = target if complete else value
		progress.show_percentage = false
		progress.add_theme_stylebox_override("background",MenuStyle.box(Color("293b46"),0))
		progress.add_theme_stylebox_override("fill",MenuStyle.box(target_metal,0))
		objective.add_child(progress)
	if not f.prestige:
		var tiers := HBoxContainer.new()
		tiers.name = "AchievementMilestones"
		tiers.add_theme_constant_override("separation",6)
		detail.add_child(tiers)
		for i: int in range(f.tiers.size()):
			var tile := PanelContainer.new()
			tile.name = "AchievementTier_"+TIER_NAMES[i+1]
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var style: StyleBoxFlat = MenuStyle.box(Color("192c37") if i < level else Color("111f29"),7)
			style.border_color = AchievementBadge.METALS[i+1].darkened(0.38) if i < level or i == next else Color("2b3d49")
			style.border_width_top = 2 if i < level or i == next else 1
			tile.add_theme_stylebox_override("panel",style)
			tiers.add_child(tile)
			var stack := VBoxContainer.new()
			stack.add_theme_constant_override("separation",0)
			tile.add_child(stack)
			var name_label: Label = copy(stack,TIER_NAMES[i+1]+("  ✓" if i < level else ""),15)
			name_label.add_theme_color_override("font_color",AchievementBadge.METALS[i+1] if i <= level else MenuStyle.MUTED)
			copy(stack,amount(f,int(f.tiers[i])),13,true)
	var rarity: Dictionary = service.snapshot.get("rarity",{})
	var population: int = int(rarity.get("eligible",0))
	if f.scope != "local" and service.authenticated() and population >= 100:
		var key: String = f.id+"/"+str(maxi(level,1))
		var rarity_label: Label = copy(detail,GameText.message("Earned by %.1f%% of drivers") % (100.0*float(rarity.get("unlocks",{}).get(key,0))/population),14,true)
		rarity_label.name = "AchievementRarity"
	var divider := HSeparator.new()
	footer.add_child(divider)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",16)
	footer.add_child(actions)
	var featured: bool = f.id in service.featured()
	var full: bool = service.featured().size() >= 5 and not featured
	var hint: String = GameText.message("Trophy Room / %d of 5 on display") % service.featured().size()
	if level == 0: hint = "Earn this honor to display it." if f.prestige else "Earn Bronze to display this medal."
	elif full: hint = "Remove a medal to make room."
	var hint_label: Label = copy(actions,hint,15,true)
	hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pin: Button = MenuStyle.button("Remove from display" if featured else "Display medal",service.toggle_feature.bind(f.id),not featured)
	pin.name = "AchievementFeature"
	pin.custom_minimum_size.x = 196
	pin.add_theme_font_size_override("font_size",21)
	pin.disabled = level == 0 or service.busy or full
	actions.add_child(pin)
