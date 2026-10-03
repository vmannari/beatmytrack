class_name TouchControls
extends Control

const SteeringHaptics = preload("res://platform/steering_haptics.gd")

const ACTIONS: Array[StringName] = [&"steer_left", &"steer_right", &"brake", &"accelerate", &"handbrake"]
const LABELS: Array[String] = ["LEFT", "RIGHT", "BRAKE", "THROTTLE", "HANDBRAKE"]
var vehicle_id: String = "compact":
	set(value):
		vehicle_id = value
		queue_redraw()
var driver: DriverInput
var haptic_strength: float = SteeringHaptics.AMPLITUDE
var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled: release_all()
var layout: Dictionary = {}:
	set(value):
		layout = ControlLayout.upgrade(value) if not value.is_empty() else {}
		release_all()
		queue_redraw()
var owners: Dictionary = {}
var safe_override := Rect2()
var analog_value: float = 0.0
var thumb: Control
var steering_rect := Rect2()
var stick_offset := Vector2.ZERO
var _cached_groups: Dictionary = {}
var _cached_hash: int = 0
var _cached_area := Rect2()

func release_all() -> void:
	if driver != null:
		for finger: Variant in owners: driver.release_touch(int(finger))
	owners.clear()
	analog_value = 0.0
	stick_offset = Vector2.ZERO

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
	var fingerprint: int = hash(layout)
	if fingerprint != _cached_hash or area != _cached_area or _cached_groups.is_empty():
		_cached_hash = fingerprint
		_cached_area = area
		_cached_groups = _resolve_groups(area)
	return _cached_groups

func _resolve_groups(area: Rect2) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ControlLayout.active_keys(layout):
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
	var keys: Array[String] = ControlLayout.active_keys(layout)
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
	thumb = Control.new()
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.draw.connect(func() -> void:
		thumb.draw_circle(Vector2.ZERO,16,Color("142021"))
		thumb.draw_arc(Vector2.ZERO,16,0,TAU,40,RaceHUDStyle.GOLD,3,true))
	add_child(thumb)
	resized.connect(queue_redraw)


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
		return [left, right, _pedal_art(groups.brake,false), _pedal_art(groups.accelerator,true), groups.handbrake.grow(-10)]
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
	return result


func _steering_art(rect: Rect2) -> Rect2:
	return Rect2(rect.position + rect.size * Vector2(17.0/146.0,32.0/192.0), rect.size * Vector2(112.0/146.0,112.0/192.0))

func _pedal_art(rect: Rect2, gas: bool) -> Rect2:
	var base: Vector2 = Vector2(168,208) if gas else Vector2(156,176)
	return Rect2(rect.position+rect.size*Vector2(20,24)/base,rect.size*(base-Vector2(40,70))/base)

func touch_zones() -> Array[Rect2]:
	if not layout.is_empty():
		var rectangles: Array[Rect2] = zones()
		var groups: Dictionary = group_rects()
		rectangles[2] = groups.brake
		rectangles[4] = groups.handbrake
		rectangles[3] = groups.accelerator
		if layout.steering_type == "buttons":
			rectangles[0] = groups.steer_left
			rectangles[1] = groups.steer_right
		else:
			var steering: Rect2 = groups[layout.steering_type]
			rectangles[0] = Rect2(steering.position,Vector2(steering.size.x*0.5,steering.size.y))
			rectangles[1] = Rect2(steering.position+Vector2(steering.size.x*0.5,0),rectangles[0].size)
		return rectangles
	var artwork: Array[Rect2] = zones()
	var result: Array[Rect2] = []
	for i: int in range(artwork.size()):
		var rect: Rect2 = artwork[i].grow_individual(42, 48, 42, 72)
		for j: int in range(artwork.size()):
			if i == j: continue
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


func action_at(point: Vector2) -> StringName:
	var rectangles: Array[Rect2] = touch_zones()
	for i: int in range(rectangles.size()):
		if rectangles[i].has_point(point):
			return ACTIONS[i]
	return &""


func _input(event: InputEvent) -> void:
	if driver == null: return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			owners.erase(event.index)
			driver.release_touch(event.index)
			if not owners.values().has(&"steer_left") and not owners.values().has(&"steer_right"):
				analog_value = 0.0
				stick_offset = Vector2.ZERO
		elif enabled:
			var local: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			var action: StringName = action_at(local)
			if action != &"":
				if not layout.is_empty() and layout.steering_type != "buttons" and action in [&"steer_left",&"steer_right"]:
					# Most recent steering finger takes ownership; old releases cannot cancel it.
					for finger: Variant in owners.keys():
						if owners[finger] in [&"steer_left",&"steer_right"]:
							driver.release_touch(int(finger))
							owners.erase(finger)
				owners[event.index] = action
				_update_finger(event.index,local)
				if action in [&"steer_left", &"steer_right"]:
					SteeringHaptics.press(haptic_strength)
	elif event is InputEventScreenDrag and enabled and driver.touches.has(event.index):
		# Diagnostic/platform adapters may seed a touch directly through DriverInput.
		if not owners.has(event.index): owners[event.index] = driver.touches[event.index]
		_update_finger(event.index,get_global_transform_with_canvas().affine_inverse()*event.position)

func _update_finger(finger: int, point: Vector2) -> void:
	var action: StringName = owners[finger]
	if not layout.is_empty() and action in [&"steer_left",&"steer_right"] and layout.steering_type != "buttons":
		var rect: Rect2 = group_rects()[layout.steering_type]
		analog_value = TouchSteering.sample(layout.steering_type,point,rect)
		stick_offset = ((point-rect.get_center())/maxf(rect.size.x*0.4,1.0)).limit_length(1.0)
		driver.set_touch(finger,&"steer_left" if analog_value < 0 else &"steer_right",absf(analog_value))
		return
	var index: int = ACTIONS.find(action)
	var target: Rect2 = touch_zones()[index]
	# Small excursions retain ownership; crossing to a different pedal never transfers it.
	var held: bool = target.grow(28).has_point(point)
	if action in [&"steer_left",&"steer_right"]:
		var next: StringName = action_at(point)
		if next in [&"steer_left",&"steer_right"]:
			action = next
			owners[finger] = action
			held = true
	# Pedals press fully on touch. Sliding down beyond the face progressively releases them.
	var strength: float = 1.0
	if not layout.is_empty() and index >= 2:
		strength = clampf((target.end.y+28-point.y)/maxf(target.size.y*0.5,1.0),0.0,1.0)
	driver.set_touch(finger,action,strength if held else 0.0)


func _touch_pressed(action: StringName) -> bool:
	if driver == null: return false
	for finger: Variant in driver.touches:
		if driver.touches[finger] == action and float(driver.touch_strengths.get(finger,1.0)) > 0.0: return true
	return false

func pressed_mask() -> int:
	var result: int = 0
	if enabled:
		for i: int in range(ACTIONS.size()):
			if Input.is_action_pressed(ACTIONS[i]) or _touch_pressed(ACTIONS[i]): result |= 1 << i
	return result


func _process(_delta: float) -> void:
	# Input state stays immediate. Retain the drawing commands while fingers
	# move within a held button; also observe keyboard and external clear().
	if thumb != null:
		thumb.visible = not layout.is_empty() and layout.steering_type != "buttons"
		if thumb.visible:
			var steering: Rect2 = steering_rect
			if driver != null and driver.touches.is_empty():
				analog_value = 0.0
				stick_offset = Vector2.ZERO
			thumb.position = steering.get_center()+(stick_offset if layout.steering_type == "joystick" else Vector2(analog_value,0))*steering.size.x*0.4
			thumb.modulate.a = float(layout[layout.steering_type].opacity)
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
	if not layout.is_empty() and layout.steering_type != "buttons":
		var steer: Rect2 = group_rects()[layout.steering_type]
		steering_rect = steer
		var tint := Color(RaceHUDStyle.GOLD,float(layout[layout.steering_type].opacity))
		if layout.steering_type == "horizontal":
			draw_line(steer.position+Vector2(20,steer.size.y*0.5),steer.end-Vector2(20,steer.size.y*0.5),tint,3,true)
		else:
			draw_arc(steer.get_center(),steer.size.x*0.48,0,TAU,64,tint,3,true)
		draw_circle(steer.get_center(),8,tint)
	for art: TouchControlArt in artwork:
		var rect: Rect2 = rectangles[art.button_index]
		if art.artwork_rect != rect:
			art.artwork_rect = rect
			art.queue_redraw()
		if art.vehicle_id != vehicle_id:
			art.vehicle_id = vehicle_id
			art.queue_redraw()
