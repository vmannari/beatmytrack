extends Control
var controller: DynamicMusicController
var sliders: Array[HSlider] = []
var risk_slider: HSlider
var status: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101c2b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	controller = DynamicMusicController.new()
	add_child(controller)
	controller.start(null)
	controller.debug_enabled = true
	controller.overlay.visible = true
	var panel := VBoxContainer.new()
	panel.position = Vector2(435,32)
	panel.custom_minimum_size = Vector2(500,0)
	panel.add_theme_constant_override("separation",12)
	add_child(panel)
	var title := Label.new()
	title.text = "BEAT MY TRACK / MUSIC LAB"
	title.add_theme_font_size_override("font_size",24)
	panel.add_child(title)
	var biome := OptionButton.new()
	biome.add_item("Grass / first listening milestone")
	panel.add_child(biome)
	for name_value: String in ["Energy","Tension","Hook presence","Driving risk"]:
		var label := Label.new()
		label.text = name_value
		panel.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0; slider.max_value = 1; slider.step = 0.01; slider.value = 0.5
		slider.custom_minimum_size.y = 26
		panel.add_child(slider)
		if sliders.size()<3: sliders.append(slider)
		else: risk_slider = slider; slider.value = 0
	var tempo := HBoxContainer.new()
	panel.add_child(tempo)
	var tempo_label := Label.new()
	tempo_label.text = "BPM (restart phrase)"
	tempo.add_child(tempo_label)
	var bpm := SpinBox.new()
	bpm.min_value = 128; bpm.max_value = 135; bpm.value = 132
	tempo.add_child(bpm)
	bpm.value_changed.connect(func(value: float) -> void:
		controller.profile = controller.profile.duplicate()
		controller.profile.bpm = roundi(value)
		controller.start(null))
	var grid := GridContainer.new()
	grid.columns = 3
	panel.add_child(grid)
	var scenarios: Dictionary = {"Straight":Vector3(.9,.1,1),"Gentle curve":Vector3(.8,.3,.7),"S-curve":Vector3(.9,.55,.5),"Hairpin":Vector3(.6,.9,.1),"Corner exit":Vector3(1,.15,1),"Bridge":Vector3(.6,.2,.6)}
	for label: String in scenarios:
		var button := Button.new()
		button.text = label; button.custom_minimum_size = Vector2(160,42)
		grid.add_child(button)
		button.pressed.connect(func() -> void:
			var value: Vector3 = scenarios[label]
			for i: int in range(3): sliders[i].value = value[i])
	for label: String in ["Off-track risk","Final lap","Finish","Restart","Mute"]:
		var button := Button.new()
		button.text = label; button.custom_minimum_size.y = 42
		grid.add_child(button)
		button.pressed.connect(func() -> void:
			match label:
				"Off-track risk": risk_slider.value = 1.0
				"Final lap": controller.context |= 1
				"Finish": controller.context |= 2
				"Restart": controller.start(null)
				"Mute": controller.player.volume_db = -80.0 if controller.player.volume_db > -70.0 else controller.profile.volume_db
		)
	status = Label.new()
	status.text = "F8 debug / harmonic cycle 8 bars / arrangement cycle 16 bars"
	panel.add_child(status)
	if "--music-capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png("res://../docs/evidence/music/music-lab.png")
		get_tree().quit()

func _process(delta: float) -> void:
	if controller == null or sliders.size()!=3: return
	controller.target = Vector3(sliders[0].value,minf(1.0,sliders[1].value+risk_slider.value*controller.profile.trajectory_influence),sliders[2].value)
	controller.trajectory.driving_risk = risk_slider.value
	controller.update_audio(delta)
