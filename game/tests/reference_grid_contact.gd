extends NativeTrack
const ORIGINAL_TYRES = preload("res://tests/legacy_tyres_reference.gd")

func step_props(state: VehicleState, from: Vector2, config: HandlingConfig, step_seconds: float) -> void:
	ORIGINAL_TYRES.step(state,tyre_origins,_contact,from,config,step_seconds)
	LightProps.step(state,hazard_objects,_contact,from,step_seconds,config.mass,config.collision_radius)

func _contact(point: Vector2, radius: float, elevated: bool) -> Vector3:
	# XY is the outward normal; Z is summed squared cell penetration. The latter
	# stays positive even where opposing cell normals cancel (inside a solid).
	var cx: int = floori((point.x + half_extent.x) / cell_size)
	var cy: int = floori((half_extent.y - point.y) / cell_size)
	var reach: int = ceili(radius / cell_size) + 1
	var total := Vector2.ZERO
	var overlap: float = 0.0
	var fallback := Vector2.RIGHT
	for y: int in range(cy - reach, cy + reach + 1):
		for x: int in range(cx - reach, cx + reach + 1):
			var center := Vector2((x + 0.5) * cell_size - half_extent.x, half_extent.y - (y + 0.5) * cell_size)
			if cell_at(center, elevated) not in [4]:
				continue
			var nearest: Vector2 = point.clamp(center - Vector2.ONE * cell_size * 0.5, center + Vector2.ONE * cell_size * 0.5)
			var offset: Vector2 = point - nearest
			if offset.length_squared() < radius * radius:
				var depth: float = radius - offset.length()
				overlap += depth * depth
				var outward: Vector2 = offset.normalized() if offset.length_squared() > 0.000001 else (point - center).normalized()
				total += outward * depth
				if outward != Vector2.ZERO: fallback = outward
	var normal: Vector2 = total.normalized() if total.length_squared() > 0.00000001 else (fallback if overlap > 0.0 else Vector2.ZERO)
	return Vector3(normal.x, normal.y, overlap)
