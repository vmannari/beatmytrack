extends Control
## One input-transparent, bounded award presentation shared by races and menus.
const Detail = preload("res://ui/achievement_detail.gd")
const ENTER: float = 0.34
const HOLD: float = 4.2
const EXIT: float = 0.28
const GAP: float = 0.18
const CAPACITY: int = 130
var app: Node
var service: Node
var pending: Array[Dictionary] = []
var current: Dictionary = {}
var elapsed: float = 0.0
var _scope: String = ""
var _seen: Dictionary = {}
var _gap: float = 0.0
var _card: Control
var _badge: TextureRect
var _eyebrow: Label
var _title: Label
var _description: Label
var _tier: Label
var _metal: Color = AchievementBadge.METALS[1]
var _style: StyleBoxFlat
var _rest: Vector2
var _racing: bool = false
var _results: bool = false

func _ready() -> void:
	name = "AchievementNotification"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuStyle.theme()
	_card = Control.new()
	_card.name = "AchievementBanner"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)
	_style = MenuStyle.box(Color("0c1922"),0)
	_style.set_corner_radius_all(8)
	_style.set_border_width_all(1)
	_style.border_color = Color("435260")
	_style.shadow_color = Color(0,0,0,0.30)
	_style.shadow_size = 14
	_style.shadow_offset = Vector2(0,5)
	_badge = TextureRect.new()
	_badge.name = "AchievementEarnedMedal"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card.add_child(_badge)
	_eyebrow = _label("ACHIEVEMENT UNLOCKED",13)
	_eyebrow.name = "AchievementUnlockedCaption"
	_title = _label("",28)
	_title.name = "AchievementUnlockedTitle"
	_title.add_theme_font_override("font",MenuStyle.DISPLAY)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_description = _label("",16)
	_description.name = "AchievementUnlockedRequirement"
	_description.add_theme_color_override("font_color",Color("c0cbd1"))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tier = _label("",13)
	_tier.name = "AchievementUnlockedTier"
	_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	get_viewport().size_changed.connect(_layout)
	if service != null:
		_scope = service.scope
		service.unlocked.connect(enqueue)
		service.changed.connect(_sync_scope)
	_layout()
	_card.hide()
	set_process(false)

func _label(copy: String, pixels: int) -> Label:
	var label: Label = MenuStyle.label(copy,pixels)
	label.clip_text = true
	_card.add_child(label)
	return label

func _sync_scope() -> void:
	if service != null and service.scope != _scope:
		clear()
		_scope = service.scope

func clear() -> void:
	pending.clear()
	current.clear()
	_seen.clear()
	elapsed = 0.0
	_gap = 0.0
	if is_instance_valid(_card): _card.hide()
	set_process(false)

func enqueue(item: Dictionary) -> void:
	_sync_scope()
	if item.get("scope") != _scope or not item.get("tier") is int: return
	var family: Dictionary = {}
	for candidate: Dictionary in AchievementProgress.catalog().families:
		if candidate.id == item.get("family"): family = candidate; break
	if family.is_empty() or int(item.tier) < 1 or int(item.tier) > family.tiers.size(): return
	var key: String = str(item.family)+"/"+str(item.tier)
	if _seen.has(key) or _seen.size() >= CAPACITY: return
	_seen[key] = true
	# A batch that crosses several milestones presents its highest earned medal.
	for i: int in range(pending.size()):
		if pending[i].family == item.family:
			if int(item.tier) > int(pending[i].tier): pending[i] = item.duplicate(true)
			return
	if pending.size() < CAPACITY: pending.append(item.duplicate(true))
	set_process(true)

func _allowed() -> bool:
	if app == null: return true
	if not app.startup_complete or not app._publishing_slots_foreground: return false
	if app.root_ui.is_visible_in_tree() and app.screen in ["account","restoring"]: return false
	if is_instance_valid(app.race_loading) or app._publication_request_active: return false
	if is_instance_valid(app.publication_notification) and app.publication_notification.is_visible_in_tree(): return false
	if is_instance_valid(app.game) and not app.root_ui.is_visible_in_tree():
		if app.game.paused or app.game.countdown_ticks > 0: return false
	for child: Node in app.root_ui.get_children():
		if child is Window and child.visible: return false
	return true

func _process(delta: float) -> void:
	_sync_scope()
	var racing: bool = app != null and is_instance_valid(app.game) and not app.root_ui.is_visible_in_tree()
	var results: bool = app != null and is_instance_valid(app.game) and app.root_ui.is_visible_in_tree() and app.root_ui.find_child("RaceResults",true,false) != null
	if racing != _racing or results != _results: _layout()
	if not _allowed():
		_card.hide()
		return # Retain the full readable lifetime across covers and suspension.
	if current.is_empty():
		_gap = maxf(0.0,_gap-delta)
		if _gap > 0.0: return
		if pending.is_empty(): set_process(false); return
		_begin(pending.pop_front())
	elapsed += delta
	if elapsed >= ENTER+HOLD+EXIT:
		current.clear()
		_card.hide()
		_gap = GAP
		return
	_card.show()
	var arrival: float = clampf(elapsed/ENTER,0.0,1.0)
	var departure: float = clampf((elapsed-ENTER-HOLD)/EXIT,0.0,1.0)
	var ease: float = 1.0-pow(1.0-arrival,3.0)
	_card.modulate.a = minf(arrival*2.0,1.0)*(1.0-departure)
	_card.position = _rest+Vector2(0,-18.0*(1.0-ease)-10.0*departure*departure)
	_badge.scale = Vector2.ONE*(0.94+0.06*ease)
	_card.queue_redraw()

func _begin(item: Dictionary) -> void:
	current = item
	elapsed = 0.0
	var family: Dictionary = {}
	var motif: int = 0
	for i: int in range(AchievementProgress.catalog().families.size()):
		if AchievementProgress.catalog().families[i].id == item.family:
			family = AchievementProgress.catalog().families[i]
			motif = i
			break
	var tier: int = int(item.tier)
	_metal = AchievementBadge.METALS[3 if family.prestige else tier]
	_badge.texture = AchievementBadge.texture(motif,tier)
	_title.text = str(family.title)
	_description.text = Detail.requirement(family,int(family.tiers[tier-1]))
	_tier.text = "PRESTIGE" if family.prestige else Detail.TIER_NAMES[tier].to_upper()
	_eyebrow.add_theme_color_override("font_color",_metal.lightened(0.25))
	_tier.add_theme_color_override("font_color",_metal)
	_layout()
	GameSoundtrack.instance().play_ui("confirm")

func _layout() -> void:
	if not is_instance_valid(_card): return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var safe := Rect2(Vector2(16,16),viewport_size-Vector2(32,32))
	if OS.has_feature("mobile"):
		var physical: Rect2i = DisplayServer.get_display_safe_area()
		var window: Vector2i = DisplayServer.window_get_size()
		var ratio: Vector2 = viewport_size/Vector2(maxi(1,window.x),maxi(1,window.y))
		safe = safe.intersection(Rect2(Vector2(physical.position)*ratio,Vector2(physical.size)*ratio).grow(-12))
	var racing: bool = app != null and is_instance_valid(app.game) and not app.root_ui.is_visible_in_tree()
	_racing = racing
	_results = app != null and is_instance_valid(app.game) and app.root_ui.is_visible_in_tree() and app.root_ui.find_child("RaceResults",true,false) != null
	var width: float = minf(548,safe.size.x)
	# Keep the road ahead and the player's car clear on short landscape screens.
	if racing and viewport_size.x >= 900: width = minf(width,viewport_size.x-560)
	if _results: width = minf(width,safe.size.x*0.45)
	var compact: bool = width < 460
	var height: float = 124.0
	_card.size = Vector2(width,height)
	_rest = Vector2(safe.get_center().x-width*0.5,safe.position.y+(96 if racing else 80))
	if racing: _rest.x = safe.position.x
	if _results: _rest = Vector2(safe.end.x-width,safe.position.y+132)
	if racing and is_instance_valid(app.game.hud):
		for label: String in ["TimingCard","RaceCard"]:
			var instrument: Control = app.game.hud.find_child(label,true,false)
			if instrument != null and instrument.is_visible_in_tree(): _rest.y = maxf(_rest.y,instrument.get_global_rect().end.y+12)
	_rest.y = minf(_rest.y,safe.end.y-height)
	_card.position = _rest
	var badge_width: float = 76.0 if compact else 92.0
	_badge.position = Vector2(8,(height-badge_width)*0.5-2)
	_badge.size = Vector2.ONE*badge_width
	_badge.pivot_offset = _badge.size*0.5
	var left: float = badge_width+14
	var copy_width: float = width-left-20
	_eyebrow.position = Vector2(left,14)
	_eyebrow.size = Vector2(copy_width,18)
	_eyebrow.add_theme_font_size_override("font_size",11 if compact else 13)
	_tier.position = Vector2(left,14)
	_tier.size = Vector2(copy_width,18)
	_tier.add_theme_font_size_override("font_size",11 if compact else 13)
	# Reserve a real column for the metal name even with a prestige honor.
	_eyebrow.size.x = maxf(0,copy_width-(62 if compact else 82))
	_title.position = Vector2(left,33)
	_title.size = Vector2(copy_width,34)
	_title.add_theme_font_size_override("font_size",24 if compact else 28)
	var title_font: Font = _title.get_theme_font("font")
	var title_size: int = 24 if compact else 28
	while title_size > 20 and title_font.get_string_size(_title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x > copy_width:
		title_size -= 1
	_title.add_theme_font_size_override("font_size",title_size)
	_description.position = Vector2(left,69)
	_description.size = Vector2(copy_width,height-79)
	_description.add_theme_font_size_override("font_size",15 if compact else 16)
	# Rare honors have longer objectives; retain every line rather than clipping it.
	var copy_height: float = _description.get_line_count()*_description.get_line_height()
	if copy_height > _description.size.y:
		_card.size.y += copy_height-_description.size.y
		_description.size.y = copy_height
		_rest.y = minf(_rest.y,safe.end.y-_card.size.y)
		_card.position = _rest
	_card.queue_redraw()

func _draw_card() -> void:
	var rect := Rect2(Vector2.ZERO,_card.size)
	_card.draw_style_box(_style,rect)
	_card.draw_line(Vector2(14,1),Vector2(rect.end.x-14,1),Color(_metal,0.65),1,true)
	_card.draw_line(Vector2(1,20),Vector2(1,rect.end.y-20),_metal,2,true)
	var center: Vector2 = _badge.position+_badge.size*0.5
	_card.draw_circle(center,_badge.size.x*0.46,Color(_metal,0.06))
	_card.draw_arc(center,_badge.size.x*0.46,0,TAU,64,Color(_metal,0.22),1,true)
	# One short minted-edge glint, no particles, shaders or render targets.
	var glint: float = clampf((elapsed-0.15)/0.85,0,1)
	if glint > 0 and glint < 1:
		var angle: float = -PI+glint*PI*1.4
		_card.draw_arc(center,_badge.size.x*0.46,angle,angle+0.55,18,Color(_metal,sin(glint*PI)*0.7),2,true)
	var remaining: float = 1.0-clampf((elapsed-ENTER)/HOLD,0,1)
	_card.draw_line(Vector2(14,rect.end.y-1),Vector2(14+(rect.end.x-28)*remaining,rect.end.y-1),Color(_metal,0.32),1,true)
