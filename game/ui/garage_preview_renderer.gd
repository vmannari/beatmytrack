extends "res://ui/car_showroom.gd"
## Only the owning preview service schedules draws, after its input/idle gate.
func invalidate_render() -> void:
	_render_dirty=true

func refresh_thumbnail() -> void:
	super.refresh_thumbnail()
	if is_instance_valid(showroom_viewport):
		# Persisted pictures have a fixed format, independent of window/DPI scale.
		showroom_viewport.size=Vector2i(2048,512)
		showroom_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if reflections!=null:
		for view: SubViewport in reflections.views: view.render_target_update_mode=SubViewport.UPDATE_DISABLED
