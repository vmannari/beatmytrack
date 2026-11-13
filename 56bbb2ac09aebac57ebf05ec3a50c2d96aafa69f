class_name TouchControls
extends Control

const SteeringHaptics = preload("res://platform/steering_haptics.gd")

const ACTIONS: Array[StringName] = [&"steer_left", &"steer_right", &"brake", &"accelerate", &"handbrake"]
const LABELS: Array[String] = ["LEFT", "RIGHT", "BRAKE", "THROTTLE", "HANDBRAKE"]
const TOUCH_PADDING := Vector2(168,192)
const TOUCH_PADDING_BELOW: float = 216.0
var vehicle_id: String = "compact":
	set(value):
		vehicle_id = value
		_cached_hash = 0
		_cached_groups.clear()
		_cached_hit_rects.clear()
		release_all()
		queue_redraw()
var driver: DriverInput
var haptic_strength: float = SteeringHaptics.AMPLITUDE
var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled: release_all()
var layout: Dictionary = {}:
	set(value):
		layout = value.duplicate(true) if not value.is_empty() else {}
		release_all()
		queue_redraw()
var owners: Dictionary = {}
var touch_origins: Dictionary = {}
# Include fingers that began outside a button, so drags can enter its hit area.
var fingers_down: Dictionary = {}
var safe_override := Rect2()
var analog_value: float = 0.0
var thumb: Control
var pedal_thumb: Control
var pedal_value: float = 0.0
var steering_finger: int = -1
var pedal_finger: int = -1
var steering_rect := Rect2()
var stick_offset := Vector2.ZERO
var _cached_groups: Dictionary = {}
var _cached_hash: int = 0
var _cached_area := Rect2()
var _cached_hit_bases: Array[Rect2] = []
var _cached_hit_rects: Array[Rect2] = []
var _cached_hit_hash: int = 0
var _cached_hit_area := Rect2()

func release_all() -> void:
	if driver != null:
		for finger: Variant in owners: driver.release_touch(int(finger))
	owners.clear()
	touch_origins.clear()
	fingers_down.clear()
	analog_value = 0.0
	pedal_value = 0.0
	steering_finger = -1
	pedal_finger = -1
	stick_offset = Vector2.ZERO

func analog_controls() -> bool:
	return not layout.is_empty() and layout.steering_type != "buttons"

func one_pedal() -> bool:
	return driver != null and driver.single_pedal

func has_handbrake() -> bool:
	return not one_pedal() and (driver.handbrake_enabled if driver != null else vehicle_id != "electric")

func _active_keys() -> Array[String]:
	var keys: Array[String] = ControlLayout.active_keys(layout)
	if one_pedal():
		keys.erase("handbrake")
		if "brake" not in keys: keys.insert(keys.size()-1,"brake") # Reserve its saved position for D/R.
	if not has_handbrake(): keys.erase("handbrake")
	return keys

func direction_rect() -> Rect2:
	if not layout.is_empty(): return _pedal_art(group_rects().brake,false)
	var rect := Rect2(size.x-248,size.y-156,100,92)
	var factor: float = control_scale*(1.15 if mobile_layout else 1.0)
	var anchor := Vector2(size.x-24,size.y-64)
	rect.position = anchor+(rect.position-anchor)*factor
	rect.size *= factor
	if left_handed: rect.position.x = size.x-rect.end.x
	return rect

func _release_finger(finger: int) -> void:
	owners.erase(finger)
	touch_origins.erase(finger)
	driver.release_touch(finger)
	if finger == steering_finger:
		steering_finger = -1
		analog_value = 0.0
		stick_offset = Vector2.ZERO
	if finger == pedal_finger:
		pedal_finger = -1
		pedal_value = 0.0

func usable_area() -> Rect2:
	var safe := Rect2(Vector2.ZERO,size)
	if safe_override.has_area():
		safe = safe.intersection(safe_override)
	elif OS.has_feature("android") or OS.has_feature("ios"):
		var physical := Rect2(DisplayServer.get_display_safe_area())
		var transform: Transform2D = (get_viewport().get_screen_transform()*get_global_transform_with_canvas()).affine_inverse()
		if physical.has_area(): safe = safe.intersection(transform * physical)
	# Reserve the real race status/pause region and keep all hit areas inside insets.
	var top: float = maxf(safe.position.y+12,180)
	return Rect2(Vector2(safe.position.x+16,top),Vector2(maxf(1,safe.size.x-32),maxf(1,safe.end.y-top-20)))

func group_rects() -> Dictionary:
	if layout.is_empty(): return {}
	var area: Rect2 = usable_area()
	var fingerprint: int = hash([layout,vehicle_id])
	if fingerprint != _cached_hash or area != _cached_area or _cached_groups.is_empty():
		_cached_hash = fingerprint
		_cached_area = area
		_cached_groups = _resolve_groups(area)
	return _cached_groups

func _resolve_groups(area: Rect2) -> Dictionary:
	var result: Dictionary = {}
	for key: String in _active_keys():
		var rect: Rect2 = ControlLayout.rect(layout,key,area)
		# Resolve overlap after aspect-ratio/safe-area changes using nearest free position.
		if _overlaps(rect,result):
			var best: float = INF
			var chosen: Rect2 = rect
			for y: int in range(21):
				for x: int in range(41):
					var candidate := Rect2(area.position+(area.size-rect.size)*Vector2(x/40.0,y/20.0),rect.size)
					var distance: float = candidate.position.distance_squared_to(rect.position)
					if distance < best and not _overlaps(candidate,result):
						best = distance
						chosen = candidate
			if best == INF: return _packed_rects(area)
			rect = chosen
		result[key] = rect
	return result

func _packed_rects(area: Rect2) -> Dictionary:
	var keys: Array[String] = _active_keys()
	keys.sort_custom(func(a: String,b: String) -> bool: return float(layout[a].x) < float(layout[b].x))
	var total: float = 0.0
	for key: String in keys: total += ControlLayout.extent(key,layout[key].scale).x
	var factor: float = minf(1.0,(area.size.x-12*(keys.size()-1))/maxf(total,1))
	var gap: float = maxf(12,(area.size.x-total*factor)/maxi(1,keys.size()-1))
	var x: float = area.position.x
	var result: Dictionary = {}
	for key: String in keys:
		var rect: Rect2 = ControlLayout.rect(layout,key,area)
		rect.size *= factor
		rect.position.x = x
		rect.position.y = clampf(rect.position.y,area.position.y,area.end.y-rect.size.y)
		result[key] = rect
		x += rect.size.x+gap
	return result

func _overlaps(rect: Rect2, others: Dictionary) -> bool:
	for other: Rect2 in others.values():
		if rect.grow(6).intersects(other): return true
	return false

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_EXIT_TREE]: release_all()

var control_scale: float = 1.0:
	set(value):
		control_scale = value
		queue_redraw()
var left_handed: bool = false:
	set(value):
		left_handed = value
		queue_redraw()
var mobile_layout: bool = OS.has_feature("android") or OS.has_feature("ios")
var draw_count: int = 0
var last_pressed_mask: int = -1
var artwork: Array[TouchControlArt] = []
var show_labels: bool = true:
	set(value):
		show_labels = value
		for art: TouchControlArt in artwork: art.show_labels = value
		queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in range(ACTIONS.size()):
		# Draw both variants once under the normal variant during loading.
		# Subsequent presses switch opacity; hide/show invalidates Godot's draw list.
		for pressed: bool in [true,false]:
			var art := TouchControlArt.new()
			art.button_index = index
			art.pressed = pressed
			art.show_labels = show_labels
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			artwork.append(art)
			add_child(art)
	thumb = _make_thumb()
	pedal_thumb = _make_thumb()
	resized.connect(func() -> void:
		release_all()
		queue_redraw())
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): release_all())

func _make_thumb() -> Control:
	var indicator := Control.new()
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.draw.connect(func() -> void:
		indicator.draw_circle(Vector2.ZERO,16,Color("142021"))
		indicator.draw_arc(Vector2.ZERO,16,0,TAU,40,RaceHUDStyle.GOLD,3,true))
	add_child(indicator)
	return indicator


func zones() -> Array[Rect2]:
	if not layout.is_empty():
		var groups: Dictionary = group_rects()
		var left: Rect2
		var right: Rect2
		if layout.steering_type == "buttons":
			left = _steering_art(groups.steer_left)
			right = _steering_art(groups.steer_right)
		else:
			var steering: Rect2 = groups[layout.steering_type]
			var half := Vector2(steering.size.x*0.46,steering.size.y)
			left = Rect2(steering.position,half)
			right = Rect2(Vector2(steering.end.x-half.x,steering.position.y),half)
		var gas: Rect2 = groups.accelerator
		if one_pedal(): return [left,right,Rect2(),_pedal_art(gas,true),Rect2()]
		var brake: Rect2 = groups.brake if not analog_controls() else Rect2(gas.position+Vector2(0,gas.size.y*0.5),Vector2(gas.size.x,gas.size.y*0.5))
		if analog_controls(): gas.size.y *= 0.5
		return [left, right, _pedal_art(brake,false), _pedal_art(gas,true), groups.handbrake.grow(-10) if has_handbrake() else Rect2()]
	var result: Array[Rect2] = [Rect2(24, size.y - 156, 100, 92), Rect2(136, size.y - 156, 100, 92),
		Rect2(size.x - 248, size.y - 156, 100, 92), Rect2(size.x - 136, size.y - 184, 112, 120), Rect2(size.x - 360, size.y - 156, 92, 92)]
	var scale_value: float = control_scale * (1.15 if mobile_layout else 1.0)
	for i: int in range(result.size()):
		var rect: Rect2 = result[i]
		var anchor: Vector2 = Vector2(24 if i < 2 else size.x - 24, size.y - 64)
		rect.position = anchor + (rect.position - anchor) * scale_value
		rect.size *= scale_value
		if left_handed: rect.position.x = size.x - rect.end.x
		result[i] = rect
	if one_pedal():
		result[2] = Rect2()
	if not has_handbrake(): result[4] = Rect2()
	return result


func _steering_art(rect: Rect2) -> Rect2:
	return Rect2(rect.position + rect.size * Vector2(17.0/146.0,32.0/192.0), rect.size * Vector2(112.0/146.0,112.0/192.0))

func _pedal_art(rect: Rect2, gas: bool) -> Rect2:
	var base: Vector2 = Vector2(168,208) if gas else Vector2(156,176)
	return Rect2(rect.position+rect.size*Vector2(20,24)/base,rect.size*(base-Vector2(40,70))/base)

func touch_zones() -> Array[Rect2]:
	if not layout.is_empty():
		var groups: Dictionary = group_rects()
		if _cached_hit_hash == _cached_hash and _cached_hit_area == _cached_area and not _cached_hit_rects.is_empty(): return _cached_hit_rects
		var rectangles: Array[Rect2] = zones()
		var pedal: Rect2 = groups.accelerator
		rectangles[2] = Rect2() if one_pedal() else groups.brake if not analog_controls() else Rect2(pedal.position+Vector2(0,pedal.size.y*0.5),Vector2(pedal.size.x,pedal.size.y*0.5))
		rectangles[4] = groups.handbrake if has_handbrake() else Rect2()
		rectangles[3] = pedal if one_pedal() or not analog_controls() else Rect2(pedal.position,Vector2(pedal.size.x,pedal.size.y*0.5))
		if layout.steering_type == "buttons":
			rectangles[0] = groups.steer_left
			rectangles[1] = groups.steer_right
		else:
			var steering: Rect2 = groups[layout.steering_type]
			rectangles[0] = Rect2(steering.position,Vector2(steering.size.x*0.5,steering.size.y))
			rectangles[1] = Rect2(steering.position+Vector2(steering.size.x*0.5,0),rectangles[0].size)
		_cached_hit_hash = _cached_hash
		_cached_hit_area = _cached_area
		_cached_hit_bases = rectangles
		_cached_hit_rects = _expanded_targets(rectangles,_cached_area)
		return _cached_hit_rects
	var artwork: Array[Rect2] = zones()
	var result: Array[Rect2] = []
	for i: int in range(artwork.size()):
		if not artwork[i].has_area():
			result.append(Rect2())
			continue
		var rect: Rect2 = artwork[i].grow_individual(42, 48, 42, 72)
		for j: int in range(artwork.size()):
			if i == j: continue
			if not artwork[j].has_area(): continue
			var neighbor: Rect2 = artwork[j]
			var split: float = (artwork[i].get_center().x + neighbor.get_center().x) * 0.5
			if artwork[i].get_center().x < split:
				rect.size.x = minf(rect.end.x, split) - rect.position.x
			else:
				var right: float = rect.end.x
				rect.position.x = maxf(rect.position.x, split)
				rect.size.x = right - rect.position.x
		result.append(rect.intersection(Rect2(Vector2.ZERO, size)))
	return result

func _expanded_targets(bases: Array[Rect2], bounds: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for base: Rect2 in bases:
		result.append(base.grow_individual(TOUCH_PADDING.x,TOUCH_PADDING.y,TOUCH_PADDING.x,TOUCH_PADDING_BELOW).intersection(bounds) if base.has_area() else Rect2())
	return result


func action_at(point: Vector2) -> StringName:
	if one_pedal() and direction_rect().grow(8).has_point(point): return &""
	var rectangles: Array[Rect2] = touch_zones()
	if not layout.is_empty():
		# Button faces always win. Shared padding belongs to the nearest face,
		# so diagonal/stacked layouts retain their usable empty space as well.
		for i: int in range(_cached_hit_bases.size()):
			if _cached_hit_bases[i].has_point(point): return ACTIONS[i]
		var closest: float = INF
		var chosen: StringName = &""
		for i: int in range(rectangles.size()):
			if not rectangles[i].has_point(point): continue
			var base: Rect2 = _cached_hit_bases[i]
			var distance: float = point.distance_squared_to(point.clamp(base.position,base.end))
			if distance < closest:
				closest = distance
				chosen = ACTIONS[i]
		return chosen
	for i: int in range(rectangles.size()):
		if rectangles[i].has_point(point):
			return ACTIONS[i]
	return &""


func _input(event: InputEvent) -> void:
	if driver == null: return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			_release_finger(event.index)
			fingers_down.erase(event.index)
		elif enabled and is_visible_in_tree():
			fingers_down[event.index] = true
			var local: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			var action: StringName = action_at(local)
			if not analog_controls() or action == &"handbrake":
				_update_button(event.index,local)
				return
			if action != &"":
				if analog_controls() and action != &"handbrake":
					var steering: bool = action in [&"steer_left",&"steer_right"]
					# Each analog axis has one owner; old releases cannot cancel a handoff.
					for finger: Variant in owners.keys():
						if (steering and owners[finger] in [&"steer_left",&"steer_right"]) or (not steering and owners[finger] in [&"accelerate",&"brake"]):
							_release_finger(int(finger))
					if steering: steering_finger = event.index
					else: pedal_finger = event.index
				owners[event.index] = action
				touch_origins[event.index] = local
				_update_finger(event.index,local)
				if action in [&"steer_left", &"steer_right"]:
					SteeringHaptics.press(haptic_strength)
	elif event is InputEventScreenDrag and enabled and is_visible_in_tree():
		if not fingers_down.has(event.index) and not driver.touches.has(event.index): return
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		var action: StringName = owners.get(event.index,driver.touches.get(event.index,&""))
		if not analog_controls() or action not in [&"steer_left",&"steer_right",&"accelerate",&"brake"]:
			_update_button(event.index,local)
			return
		# Diagnostic/platform adapters may seed a touch directly through DriverInput.
		if not owners.has(event.index): owners[event.index] = driver.touches[event.index]
		if not touch_origins.has(event.index): touch_origins[event.index] = local
		_update_finger(event.index,local)

func _update_button(finger: int, point: Vector2) -> void:
	var action: StringName = action_at(point)
	var previous: StringName = owners.get(finger,&"")
	# Relative axes keep their first-contact origin and capture until release.
	if analog_controls() and action != &"" and action != &"handbrake":
		_release_finger(finger)
		return
	if action == &"":
		# Keep the existing small edge tolerance, but a different button wins
		# immediately whenever the finger enters its actual or padded hit area.
		if previous != &"":
			var index: int = ACTIONS.find(previous)
			var target: Rect2 = touch_zones()[index]
			if target.grow(28).has_point(point):
				var strength: float = 1.0
				if not layout.is_empty() and index in [2,3]:
					strength = clampf((target.end.y+28-point.y)/28.0,0.0,1.0)
				driver.set_touch(finger,previous,strength)
				return
		_release_finger(finger)
		return
	owners[finger] = action
	touch_origins[finger] = point
	driver.set_touch(finger,action)
	if action != previous and action in [&"steer_left",&"steer_right"]:
		SteeringHaptics.press(haptic_strength)

func _update_finger(finger: int, point: Vector2) -> void:
	var action: StringName = owners[finger]
	if analog_controls() and action in [&"steer_left",&"steer_right"]:
		var rect: Rect2 = group_rects()[layout.steering_type]
		analog_value = TouchSteering.sample(point,touch_origins[finger],rect)
		stick_offset = Vector2(analog_value,0)
		driver.set_touch(finger,&"steer_left" if analog_value < 0 else &"steer_right",absf(analog_value))
		return
	if analog_controls() and action in [&"accelerate",&"brake"]:
		var rect: Rect2 = group_rects().accelerator
		var origin: Vector2 = touch_origins[finger]
		pedal_value = TouchSteering.axis(origin.y-point.y,rect.size.y*TouchSteering.FULL_TRAVEL_RATIO)
		if one_pedal(): pedal_value = maxf(0.0,pedal_value)
		driver.set_touch(finger,&"accelerate" if pedal_value >= 0 else &"brake",absf(pedal_value))
		return
	_update_button(finger,point)


func _touch_pressed(action: StringName) -> bool:
	if driver == null: return false
	for finger: Variant in driver.touches:
		if driver.touches[finger] == action and float(driver.touch_strengths.get(finger,1.0)) > 0.0: return true
	return false

func pressed_mask() -> int:
	var result: int = 0
	if enabled:
		for i: int in range(ACTIONS.size()):
			if (one_pedal() and i == 2) or (not has_handbrake() and i == 4): continue
			if Input.is_action_pressed(ACTIONS[i]) or _touch_pressed(ACTIONS[i]): result |= 1 << i
	return result


func _process(_delta: float) -> void:
	# Input state stays immediate. Retain the drawing commands while fingers
	# move within a held button; also observe keyboard and external clear().
	if thumb != null:
		thumb.visible = analog_controls()
		pedal_thumb.visible = thumb.visible
		if thumb.visible:
			if driver != null and driver.touches.is_empty() and not owners.is_empty():
				release_all()
			var steering: Rect2 = group_rects()[layout.steering_type]
			var pedal: Rect2 = group_rects().accelerator
			thumb.position = touch_origins.get(steering_finger,steering.get_center())+Vector2(analog_value*steering.size.x*TouchSteering.FULL_TRAVEL_RATIO,0)
			pedal_thumb.position = touch_origins.get(pedal_finger,pedal.get_center())-Vector2(0,pedal_value*pedal.size.y*TouchSteering.FULL_TRAVEL_RATIO)
			thumb.modulate.a = float(layout[layout.steering_type].opacity)
			pedal_thumb.modulate.a = float(layout.accelerator.opacity)
	var mask: int = pressed_mask()
	last_pressed_mask = mask
	for art: TouchControlArt in artwork:
		# Waiting for both first draws keeps the visible normal art unchanged.
		if artwork[art.button_index*2].draw_count == 0 or artwork[art.button_index*2+1].draw_count == 0: continue
		art.modulate.a = _opacity(art.button_index) if art.pressed == ((mask & (1 << art.button_index)) != 0) else 0.0


func _opacity(index: int) -> float:
	if layout.is_empty(): return 1.0
	var key: String = ("steer_left" if index == 0 else "steer_right") if index < 2 and layout.steering_type == "buttons" else str(layout.steering_type) if index < 2 else "brake" if index == 2 else "handbrake" if index == 4 else "accelerator"
	return float(layout[key].opacity)

# All artwork is drawn in local 100 x 100 units; touch geometry stays independent.
func _draw() -> void:
	draw_count += 1
	last_pressed_mask = pressed_mask()
	var rectangles: Array[Rect2] = zones()
	if analog_controls():
		var steer: Rect2 = group_rects()[layout.steering_type]
		steering_rect = steer
		var tint := Color(RaceHUDStyle.GOLD,float(layout[layout.steering_type].opacity))
		if layout.steering_type == "horizontal":
			draw_line(steer.position+Vector2(20,steer.size.y*0.5),steer.end-Vector2(20,steer.size.y*0.5),tint,3,true)
		else:
			draw_arc(steer.get_center(),steer.size.x*0.48,0,TAU,64,tint,3,true)
		draw_circle(steer.get_center(),8,tint)
		var pedal: Rect2 = group_rects().accelerator
		var pedal_tint := Color(RaceHUDStyle.GOLD,float(layout.accelerator.opacity))
		var center: Vector2 = pedal.get_center()
		draw_line(Vector2(center.x,pedal.position.y+24),Vector2(center.x,pedal.end.y-24),pedal_tint,3,true)
		draw_line(center-Vector2(12,0),center+Vector2(12,0),pedal_tint,3,true)
		for direction: float in ([-1.0] if one_pedal() else [-1.0,1.0]):
			var tip := Vector2(center.x,center.y+direction*(pedal.size.y*0.5-24))
			draw_line(tip,tip+Vector2(-7,-direction*7),pedal_tint,3,true)
			draw_line(tip,tip+Vector2(7,-direction*7),pedal_tint,3,true)
		if show_labels:
			var font: Font = ThemeDB.fallback_font
			draw_string(font,Vector2(center.x+20,pedal.position.y+42),"GAS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,pedal_tint)
			if not one_pedal(): draw_string(font,Vector2(center.x+20,pedal.end.y-28),"BRAKE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,pedal_tint)
	for art: TouchControlArt in artwork:
		art.visible = not analog_controls() or art.button_index == 4
		if (one_pedal() and art.button_index == 2) or (not has_handbrake() and art.button_index == 4): art.visible = false
		var rect: Rect2 = rectangles[art.button_index]
		if art.artwork_rect != rect:
			art.artwork_rect = rect
			art.queue_redraw()
		if art.vehicle_id != vehicle_id:
			art.vehicle_id = vehicle_id
			art.queue_redraw()
