extends "res://tests/profile_loading_half.gd"
## Preserve readiness assertions for both live and adopted preloaded studios.
func content_ready(page: String) -> bool:
	if page != "garage": return super.content_ready(page)
	if is_instance_valid(app._feature_loading) or not is_instance_valid(app._retained_garage): return false
	var studio: Node = app._retained_garage.showroom
	if not is_instance_valid(studio) or not studio.showroom_ready: return false
	if studio.get_script().resource_path == "res://ui/garage_preloaded_studio.gd":
		return studio.prepared and not studio.warming
	return super.content_ready(page)
