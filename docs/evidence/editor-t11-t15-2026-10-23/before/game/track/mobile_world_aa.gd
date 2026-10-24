extends CanvasLayer
## Screen-space AA after the world and before native Canvas HUD/weather.
var material: ShaderMaterial
var last_scale: float = -1.0

static func required(mobile: bool, renderer: String, adapter: String) -> bool:
	return mobile and renderer=="gl_compatibility" and adapter.to_lower().contains("adreno")

func _ready() -> void:
	layer = -10
	var surface := ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://track/world_fxaa.gdshader")
	surface.material = material
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_process(0.0)

func _process(_delta: float) -> void:
	var scale: float = get_viewport().scaling_3d_scale
	if is_equal_approx(last_scale,scale): return
	last_scale = scale
	material.set_shader_parameter("source_pixel_scale",1.0/maxf(scale,0.05))
