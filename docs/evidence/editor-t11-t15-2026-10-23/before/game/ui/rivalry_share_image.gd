extends RefCounted
## Render only the branded receipt, with no app background or dialog controls.
const Card = preload("res://ui/rivalry_share_dialog.gd")

static func render(host: Node, values: Dictionary) -> PackedByteArray:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(host) or not host.is_inside_tree(): return PackedByteArray()
	var viewport := SubViewport.new()
	viewport.name = "RivalryShareImage"
	viewport.size = Vector2i(1600,860)
	viewport.size_2d_override = Vector2i(1120,602)
	viewport.size_2d_override_stretch = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var card := Card.new()
	card.export_mode = true
	card.model = values.model
	card.player_name = str(values.player_name)
	card.livery = values.livery.duplicate(true)
	card.customisation = values.customisation.duplicate(true)
	card.condition = values.condition.duplicate(true)
	host.add_child(card)
	card.surface.reparent(viewport)
	MenuStyle.fill(card.surface)
	for frame: int in range(6):
		await RenderingServer.frame_post_draw
		var owner: Window = values.owner.get_ref() as Window if values.get("owner") is WeakRef else null
		var cancelled: bool = values.get("owner") is WeakRef and (not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.visible)
		if cancelled or not is_instance_valid(card) or card.is_queued_for_deletion() or not is_instance_valid(viewport) or viewport.is_queued_for_deletion():
			if is_instance_valid(card): card.queue_free()
			if is_instance_valid(viewport): viewport.queue_free()
			return PackedByteArray()
	var image: Image = viewport.get_texture().get_image()
	var png: PackedByteArray = image.save_png_to_buffer() if image != null else PackedByteArray()
	card.queue_free()
	viewport.queue_free()
	return png if png.size() <= 4*1024*1024 else PackedByteArray()
