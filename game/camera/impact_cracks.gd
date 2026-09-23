class_name ImpactCracks
extends TextureRect
## Persistent race damage using an original transparent shattered-glass texture.

const MIN_IMPACT: float = 7.0
const FULL_IMPACT: float = 20.0
const MIN_VISIBLE_ALPHA: float = 0.28
const MAX_VISIBLE_ALPHA: float = 0.82
const GLASS_TEXTURE: Texture2D = preload("res://assets/textures/impact_glass_v1.png")
const GLASS_SHADER: Shader = preload("res://camera/impact_glass.gdshader")

var strength: float = 0.0
var side_damage: Vector4 = Vector4.ZERO # left, right, top, bottom


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	texture = GLASS_TEXTURE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var glass_material := ShaderMaterial.new()
	glass_material.shader = GLASS_SHADER
	material = glass_material
	visible = false


func show_impact(resolved_velocity_change: Vector2) -> void:
	if texture == null:
		texture = GLASS_TEXTURE
	var added: float = smoothstep(MIN_IMPACT, FULL_IMPACT, resolved_velocity_change.length())
	if added <= 0.0:
		return
	var damage_to_add: float = lerpf(0.16, 0.42, added)
	var side: int = affected_side(resolved_velocity_change)
	damage_to_add = _fill_side(side, damage_to_add)
	# Only overflow from a completed struck side spreads to the currently least
	# damaged remaining edge. This keeps early damage physically localized.
	# At most the three remaining edges can accept overflow. Once all four
	# are full, excess damage must be discarded rather than circulated forever.
	for _edge: int in range(3):
		if damage_to_add <= 0.0001: break
		var next_side: int = _least_damaged_side(side)
		if side_damage[next_side] >= 1.0: break
		damage_to_add = _fill_side(next_side, damage_to_add)
		side = next_side
	strength = maxf(maxf(side_damage.x, side_damage.y), maxf(side_damage.z, side_damage.w))
	_update_material()
	visible = true


func affected_side(resolved_velocity_change: Vector2) -> int:
	# The resolved change points away from the obstacle, so the struck edge is opposite.
	if absf(resolved_velocity_change.x) >= absf(resolved_velocity_change.y):
		return 0 if resolved_velocity_change.x > 0.0 else 1
	return 3 if resolved_velocity_change.y > 0.0 else 2


func _fill_side(side: int, amount: float) -> float:
	var available: float = 1.0 - side_damage[side]
	var applied: float = minf(available, amount)
	side_damage[side] += applied
	return amount - applied


func _least_damaged_side(excluded: int) -> int:
	var result: int = -1
	var lowest: float = INF
	for side: int in range(4):
		if side != excluded and side_damage[side] < lowest:
			result = side
			lowest = side_damage[side]
	return result


func _update_material() -> void:
	if material == null:
		var glass_material := ShaderMaterial.new()
		glass_material.shader = GLASS_SHADER
		material = glass_material
	(material as ShaderMaterial).set_shader_parameter("side_damage", side_damage)


func clear_effect() -> void:
	visible = false
	strength = 0.0
	side_damage = Vector4.ZERO
	modulate = Color.WHITE
	_update_material()
