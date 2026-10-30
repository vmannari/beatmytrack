extends ColorRect
## Static medal-lit stage, confined to the podium above its separate player footer.
const STAGE: Shader = preload("res://ui/rivalry_podium_backdrop.gdshader")
const WALL: Array[Color] = [Color("29200c"),Color("142b3b"),Color("361d15")]
const FLOOR: Array[Color] = [Color("51401a"),Color("203e51"),Color("56311f")]
const LIGHT: Array[Color] = [Color("ffc452"),Color("a0c5df"),Color("f29459")]
const STRENGTH: Array[float] = [0.32,0.16,0.22]

static func add_to(panel: Control, footer: Control, place: int) -> Control:
	var stage := new()
	stage.name = "RivalryPodiumBackdrop"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = STAGE
	paint.set_shader_parameter("wall_color",WALL[place])
	paint.set_shader_parameter("floor_color",FLOOR[place])
	paint.set_shader_parameter("light_color",LIGHT[place])
	paint.set_shader_parameter("light_strength",STRENGTH[place])
	stage.material = paint
	# Let PanelContainer fit a plain holder; only its child owns the stage inset.
	var holder := Control.new()
	holder.name = "RivalryPodiumStage"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(holder,false,Node.INTERNAL_MODE_FRONT)
	holder.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.offset_left = 1
	stage.offset_top = 2
	stage.offset_right = -1
	holder.resized.connect(stage._layout_stage.bind(footer))
	footer.item_rect_changed.connect(stage._layout_stage.bind(footer))
	stage.resized.connect(stage._resize_stage)
	stage._layout_stage(footer)
	return stage

func _layout_stage(footer: Control) -> void:
	if not is_instance_valid(footer): return
	var holder := get_parent() as Control
	var footer_start: Vector2 = holder.get_global_transform().affine_inverse()*footer.global_position
	offset_bottom = footer_start.y-holder.size.y
	_resize_stage()

func _resize_stage() -> void:
	(material as ShaderMaterial).set_shader_parameter("stage_size",size.max(Vector2.ONE))
