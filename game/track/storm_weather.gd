class_name StormWeather
extends Control
## Presentation only: no access to simulation state, inputs or race clocks.
const DROP_COUNT: int = 6
const FLASH_DURATION: float = 2.2 # Upper bound; each strike ends at its last knot.
const MIN_INTERVAL: float = 9.0
const MAX_INTERVAL: float = 16.0
var elapsed: float = 0.0
var until_lightning: float = 6.0
var until_thunder: float = -1.0
var flash_age: float = FLASH_DURATION
var flash_profile := PackedVector2Array()
var strikes: int = 0
var thunder_count: int = 0
var light: DirectionalLight3D
var base_light_energy: float = 0.5
var rng := RandomNumberGenerator.new()
var rain_audio: AudioStreamPlayer
var thunder_audio: AudioStreamPlayer
var lens_drops: Array[ColorRect] = []
var wet_glass_material: ShaderMaterial
const TRAIL_STEP: float = 0.02
const TRAIL_SLOTS: int = 72
var trail_samples: Array[PackedVector4Array] = []
var trail_tick: int = -1

func _ready() -> void:
	RenderingServer.global_shader_parameter_set("storm_ripple_time",0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen_copy := BackBufferCopy.new()
	screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(screen_copy)
	var wet_glass := ColorRect.new()
	wet_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wet_glass_material = ShaderMaterial.new()
	wet_glass_material.shader = preload("res://track/storm_wet_glass.gdshader")
	wet_glass_material.set_shader_parameter("glass_data",preload("res://assets/textures/storm_glass_data.png"))
	wet_glass.material = wet_glass_material
	add_child(wet_glass)
	wet_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i: int in range(DROP_COUNT):
		var history := PackedVector4Array()
		history.resize(TRAIL_SLOTS)
		trail_samples.append(history)
		var drop := ColorRect.new()
		drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lens_material := ShaderMaterial.new()
		lens_material.shader = preload("res://track/storm_lens.gdshader")
		drop.material = lens_material
		add_child(drop)
		lens_drops.append(drop)
	resized.connect(_update_lens)
	_update_lens()
	rng.randomize()
	rain_audio = AudioStreamPlayer.new()
	rain_audio.stream = preload("res://assets/audio/storm_rain.wav")
	rain_audio.volume_db = -24.0
	add_child(rain_audio)
	rain_audio.finished.connect(rain_audio.play)
	rain_audio.play()
	thunder_audio = AudioStreamPlayer.new()
	thunder_audio.stream = preload("res://assets/audio/storm_thunder.wav")
	thunder_audio.volume_db = -12.0
	add_child(thunder_audio)
	if light != null: base_light_energy = light.light_energy

func advance(delta: float, paused: bool) -> void:
	rain_audio.stream_paused = paused
	thunder_audio.stream_paused = paused
	if paused: return
	elapsed = fmod(elapsed+delta,3600.0)
	RenderingServer.global_shader_parameter_set("storm_ripple_time",elapsed)
	flash_age += delta
	if until_thunder >= 0.0:
		until_thunder -= delta
		if until_thunder < 0.0:
			thunder_audio.pitch_scale = rng.randf_range(0.90,1.04)
			thunder_audio.play()
			thunder_count += 1
	until_lightning -= delta
	if until_lightning <= 0.0:
		flash_age = 0.0
		_build_flash_profile()
		strikes += 1
		until_lightning = rng.randf_range(MIN_INTERVAL,MAX_INTERVAL)
		until_thunder = rng.randf_range(1.2,2.8)
	if light != null: light.light_energy = base_light_energy+flash_strength()*8.5
	_update_lens()
	queue_redraw()

func flash_strength() -> float:
	if flash_profile.is_empty() or flash_age >= flash_profile[-1].x: return 0.0
	for index: int in range(1,flash_profile.size()):
		var next: Vector2 = flash_profile[index]
		if flash_age <= next.x:
			var previous: Vector2 = flash_profile[index-1]
			return lerpf(previous.y,next.y,smoothstep(previous.x,next.x,flash_age))
	return 0.0

func _build_flash_profile() -> void:
	# Sample once per strike. Broad, shallow swells share one thunder event
	# and the paused presentation clock, without rapid bright/dark flicker.
	flash_profile = PackedVector2Array([Vector2.ZERO])
	var cursor: float = rng.randf_range(0.16,0.24)
	var pulses: int = rng.randi_range(2,3)
	var peak: float = rng.randf_range(0.24,0.32)
	for pulse: int in range(pulses):
		if pulse > 0: peak = clampf(peak*rng.randf_range(0.88,1.10),0.18,0.32)
		flash_profile.append(Vector2(cursor,peak))
		cursor += rng.randf_range(0.18,0.28)
		flash_profile.append(Vector2(cursor,peak*rng.randf_range(0.65,0.82)))
		if pulse < pulses-1: cursor += rng.randf_range(0.16,0.26)
	flash_profile.append(Vector2(cursor+rng.randf_range(0.30,0.45),0.0))

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	# Bounded rain streaks, independent of track size. Leave HUD to its own layer.
	for i: int in range(190):
		var seed: float = float(i)
		var x: float = fposmod(sin(seed*127.1+9.4)*43758.5453-elapsed*0.12,1.0)*size.x
		var y: float = fposmod(sin(seed*311.7+2.6)*19341.917+elapsed*(0.65+fmod(seed,4.0)*0.07),1.0)*size.y
		var length: float = (13.0+fmod(seed,12.0))*size.y/720.0
		draw_line(Vector2(x,y),Vector2(x-length*0.35,y+length),Color(0.72,0.83,0.90,0.27),1.0,true)
	_draw_lens_trails()
	var flash: float = flash_strength()
	if flash > 0.0: draw_rect(Rect2(Vector2.ZERO,size),Color(0.78,0.87,1.0,flash*0.40))

# Analytic presentation paths keep stops, growth and trails independent of frame rate.
func _lens_hash(value: float) -> float:
	return fposmod(sin(value*12.9898+4.7)*43758.5453,1.0)

func lens_sample(index: int, time: float) -> Vector4:
	var clock: float = maxf(0.0,time+float(index)*1.71)
	var cycle: int = int(floor(clock/12.0))
	var age: float = fposmod(clock,12.0)
	var seed: float = float(index)*19.7+float(cycle)*73.1
	var placement: float = _lens_hash(seed)
	var spread: float = _lens_hash(seed+1.0)
	var x: float = lerpf(0.32,0.68,spread) if placement < 0.30 else (lerpf(0.05,0.25,spread) if placement < 0.65 else lerpf(0.75,0.95,spread))
	var y: float = lerpf(0.04,0.20,_lens_hash(seed+2.0))
	var radius: float = 17.0+float(index%3)*4.0
	var stretch: float = 1.0
	var remaining: float = age
	for stage: int in range(4):
		var key: float = seed+float(stage)*7.0
		var hold: float = lerpf(1.05,2.0,_lens_hash(key+3.0))
		var slip: float = lerpf(0.28,0.65,_lens_hash(key+4.0))
		var growth: float = clampf(remaining/hold,0.0,1.0)
		radius = (17.0+float(index%3)*4.0)*(0.82+growth*0.40)
		if remaining <= hold: break
		var progress: float = clampf((remaining-hold)/slip,0.0,1.0)
		radius = (17.0+float(index%3)*4.0)*lerpf(1.22,0.82,progress)
		# Uneven release/catch spurts, each with its own sideways deflection.
		# Piecewise paths preserve continuity without smoothing away the kinks.
		var travel: float = 0.0
		var sideways: float = 0.0
		for hop: int in range(4):
			var hop_key: float = key+float(hop)*11.31
			var local: float = clampf(progress*4.0-float(hop),0.0,1.0)
			var catch_time: float = lerpf(0.12,0.48,_lens_hash(hop_key+8.0))
			var release: float = clampf((local-catch_time)/(1.0-catch_time),0.0,1.0)
			var spurt: float = pow(release,lerpf(0.55,1.65,_lens_hash(hop_key+9.0)))
			travel += spurt*0.25
			sideways += lerpf(-0.024,0.024,_lens_hash(hop_key+10.0))*spurt
			if local > 0.0 and local < 1.0:
				stretch = 1.0+sin(release*PI)*0.48
		x += sideways
		y += lerpf(0.20,0.29,_lens_hash(key+7.0))*travel
		if progress < 1.0: break
		remaining -= hold+slip
	# Fade in new beads by growing them; departed beads remain offscreen until reset.
	radius *= smoothstep(0.0,0.35,age)*(1.0-smoothstep(10.8,12.0,age))
	return Vector4(x,y,radius,stretch)

func _update_lens() -> void:
	if lens_drops.size() != DROP_COUNT: return
	_update_trail_history()
	wet_glass_material.set_shader_parameter("lightning",flash_strength())
	for i: int in range(DROP_COUNT):
		var sample: Vector4 = lens_sample(i,elapsed)
		var radius: float = maxf(0.01,sample.z*size.y/720.0)
		var drop: ColorRect = lens_drops[i]
		drop.size = Vector2(radius*2.4,radius*3.2)
		drop.position = Vector2(sample.x,sample.y)*size-drop.size*0.5
		var lens_material: ShaderMaterial = drop.material as ShaderMaterial
		lens_material.set_shader_parameter("fade",1.0)
		lens_material.set_shader_parameter("stretch",sample.w)
		lens_material.set_shader_parameter("radius_px",radius)
		lens_material.set_shader_parameter("shape_seed",float(i)*1.73+floor((elapsed+float(i)*1.71)/12.0)*2.91)

func _update_trail_history() -> void:
	var current_tick: int = int(floor(elapsed/TRAIL_STEP))
	if current_tick < trail_tick: trail_tick = -1
	# Evaluate each historical position once, not 420 full paths every frame.
	for tick: int in range(maxi(trail_tick+1,current_tick-TRAIL_SLOTS+1),current_tick+1):
		for i: int in range(DROP_COUNT):
			trail_samples[i][tick%TRAIL_SLOTS] = lens_sample(i,float(tick)*TRAIL_STEP)
	trail_tick = current_tick

func _draw_lens_trails() -> void:
	# Keep the same history/duration, joining fewer subpixel segments on phones.
	var stride: int = 3 if OS.has_feature("mobile") else 1
	for i: int in range(DROP_COUNT):
		var newer: Vector4 = lens_sample(i,elapsed)
		for step: int in range(0,71,stride):
			var tick: int = trail_tick-step
			if tick < 0: break
			var age: float = elapsed-float(tick)*TRAIL_STEP
			if age > 1.4: break
			var older: Vector4 = trail_samples[i][tick%TRAIL_SLOTS]
			var from := Vector2(older.x,older.y)*size
			var to := Vector2(newer.x,newer.y)*size
			# Never join the old path to a newly spawned drop.
			if older.y > newer.y+0.001: break
			if from.distance_squared_to(to) > 0.04:
				var freshness: float = 1.0-age/1.45
				var radius: float = (older.z+newer.z)*0.5*size.y/720.0
				var shape_seed: float = float(i)*1.73+floor((elapsed-age+float(i)*1.71)/12.0)*2.91
				var shoulder: float = 0.76+0.18*sin(shape_seed*3.1)
				# Broad translucent deposit scales with the bead, then narrows as it dries.
				var width: float = maxf(1.0,radius*shoulder*1.5*lerpf(0.35,1.0,freshness))
				draw_line(from,to,Color(0.72,0.86,0.94,0.055*freshness),width,true)
				draw_line(from,to,Color(0.72,0.86,0.94,0.035*freshness),width*0.60,true)
			newer = older

func _exit_tree() -> void:
	if is_instance_valid(rain_audio): rain_audio.stop()
	if is_instance_valid(thunder_audio): thunder_audio.stop()
	if is_instance_valid(light): light.light_energy = base_light_energy
