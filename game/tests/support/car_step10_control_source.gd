extends CarVisual
## Offline observer; production assembly remains unchanged.
const OriginalBatch=preload("res://tests/support/car_step10_original_batch.gd")
static var observer: Callable

func _finish_render_model() -> void:
	_builder("compact_seam_strip").finish(self)
	if simple_model: _builder("racing_car_models").prepare(self)
	# Reduce each authored piece before assembly. Fixed cars and modular kits
	# must not receive different geometry merely because they batch differently.
	if vehicle_id!="hovercraft": _builder("car_static_reduction").apply(self)
	_builder("car_coarse_reduction").apply(self)
	_builder("car_detail_reduction").apply(self)
	if observer.is_valid(): observer.call(self,null)
	if batch_parts:
		_model_stage = "sibling batches"
		await OriginalBatch.batch_static_parts(self,_model_checkpoint if cooperative_build else Callable())
		if not await _model_checkpoint(): return
		_model_stage = "frame batches"
		await OriginalBatch.batch_car_parts(self,_model_checkpoint if cooperative_build else Callable())
		if not await _model_checkpoint(): return
	if vehicle_id=="hovercraft": _builder("car_static_reduction").apply(self)
	var fitted_source: bool=not _pending_source_parts.is_empty()
	if fitted_source:
		var selected_parts: Dictionary=_pending_source_parts
		_pending_source_parts={}
		change_kit_parts(selected_parts)
		editable_kits=_source_requested_editable
		_update_rear_lights()
	_model_stage = "snapshot"
	if livery.is_empty(): livery = VehicleLivery.defaults(vehicle_id)
	if cache_rest_pose: preload("res://vehicle/prepared_car_cache.gd").remember(self)
	if not fitted_source: graphics.configure(self)
	if not await _model_checkpoint(): return

func _reduce_changed_kit(category: String) -> void:
	super._reduce_changed_kit(category)
	if observer.is_valid(): observer.call(self,kit_frames.get(category,[]))
